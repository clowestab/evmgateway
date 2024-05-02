// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {RLPReader} from "@eth-optimism/contracts-bedrock/src/libraries/rlp/RLPReader.sol";
import {Bytes} from "@eth-optimism/contracts-bedrock/src/libraries/Bytes.sol";
import {SecureMerkleTrie} from "./SecureMerkleTrie.sol";

struct StateProof {
    bytes[] stateTrieWitness;         // Witness proving the `storageRoot` against a state root.
    bytes[][] storageProofs;          // An array of proofs of individual storage elements 
}

struct CommandData {
    bytes32 command;
    bytes1 tByte;
    uint8 tOpcode;
    uint8 tOperand;
}

struct SlotData {
    bool isDynamic;
    uint256 slot;
    uint8 postProcessIndex;
}

struct ProcessData {
    uint8 nextCIdxToUse;
    bytes[] internalValues;
    RLPReader.RLPItem[] headerFields;
    address target;
}

uint8 constant OP_CONSTANT = 0x00;
uint8 constant OP_BACKREF = 0x20;
uint8 constant OP_SLICE = 0x40;
uint8 constant OP_IVALUE = 0x80;
uint8 constant OP_POST_PROCESS_SEPARATOR = 0xfe;
uint8 constant OP_END = 0xff;
uint8 constant FLAG_DYNAMIC = 0x01;

library EVMProofHelper {
    using Bytes for bytes;

    error AccountNotFound(address);
    error UnknownOpcode(uint8);
    error InvalidSlotSize(uint256 size);

    /**
     * @notice Get the storage root for the provided merkle proof
     * @param stateRoot The state root the witness was generated against
     * @param target The address we are fetching a storage root for
     * @param witness A witness proving the value of the storage root for `target`.
     * @return The storage root retrieved from the provided state root
     */
    function getStorageRoot(bytes32 stateRoot, address target, bytes[] memory witness) private pure returns (bytes32) {
        (bool exists, bytes memory encodedResolverAccount) = SecureMerkleTrie.get(
            abi.encodePacked(target),
            witness,
            stateRoot
        );
        if(!exists) {
            revert AccountNotFound(target);
        }
        RLPReader.RLPItem[] memory accountState = RLPReader.readList(encodedResolverAccount);
        return bytes32(RLPReader.readBytes(accountState[2]));
    }

    /**
     * @notice Prove whether the provided storage slot is part of the storageRoot
     * @param storageRoot the storage root for the account that contains the storage slot
     * @param slot The storage key we are fetching the value of
     * @param witness the StorageProof struct containing the necessary proof data
     * @return The retrieved storage proof value or 0x if the storage slot is empty
     */
    function getSingleStorageProof(bytes32 storageRoot, uint256 slot, bytes[] memory witness) private pure returns (bytes memory) {
        
        (bool exists, bytes memory retrievedValue) = SecureMerkleTrie.get(
            abi.encodePacked(slot),
            witness,
            storageRoot
        );
        if(!exists) {

            // Nonexistent values are treated as zero.
            return "";
        }
        
        return RLPReader.readBytes(retrievedValue);
    }

    function getFixedValue(bytes32 storageRoot, uint256 slot, bytes[] memory witness) private pure returns(bytes32) {
        bytes memory value = getSingleStorageProof(storageRoot, slot, witness);
        // RLP encoded storage slots are stored without leading 0 bytes.
        // Casting to bytes32 appends trailing 0 bytes, so we have to bit shift to get the 
        // original fixed-length representation back.
        return bytes32(value) >> (256 - 8 * value.length);
    }

    /**
     * Executes an operation from a particular command in the context of generating the appropriate slot ID for the value being requested
     * @param operation a singular operation byte (3 bit opcode, 5 bit operand)
     * @param values an array of values pulled by previous commands
     * @param iValues an array of non-provable values used internally for slot generation e.g. slices of previous values
     * @return bytes the value/key to use in slot generation
     */
    function executeOperation(bytes1 operation, bytes[] memory constants, bytes[] memory values, bytes[] memory iValues) private pure returns(bytes memory) {
        uint8 opcode = uint8(operation) & 0xe0;
        uint8 operand = uint8(operation) & 0x1f;

        if(opcode == OP_CONSTANT) {
            return constants[operand];
        } else if(opcode == OP_BACKREF) {
            return values[operand];
        } else if(opcode == OP_IVALUE) {
            return iValues[operand];
        } else {
            revert UnknownOpcode(opcode);
        }
    }

    function computeFirstSlot(bytes32 command, bytes[] memory constants, bytes[] memory values, bytes[] memory iValues) private pure returns(SlotData memory sData, uint8 postProcessIndex) {
        uint8 flags = uint8(command[1]);
        sData.isDynamic = (flags & FLAG_DYNAMIC) != 0;

        bytes memory slotData = executeOperation(command[2], constants, values, iValues);

        require(slotData.length == 32, "First path element must be 32 bytes");
        sData.slot = uint256(bytes32(slotData));
        for(uint256 j = 3; j < 32; j++) {

            if (uint8(command[j]) == OP_POST_PROCESS_SEPARATOR) {
                postProcessIndex = uint8(j);
                break;
            }

            if (uint8(command[j]) == OP_END) {
                break;
            }

            bytes memory index = executeOperation(command[j], constants, values, iValues);
            sData.slot = uint256(keccak256(abi.encodePacked(index, sData.slot)));
        }
    }

    function getDynamicValue(bytes32 storageRoot, uint256 slot, StateProof memory proof, uint256 proofIdx) private pure returns(bytes memory value, uint256 newProofIdx) {
        
        bytes32 fValue = getFixedValue(storageRoot, slot, proof.storageProofs[proofIdx++]);

        uint256 firstValue = uint256(fValue);

        if(firstValue & 0x01 == 0x01) {
            // Long value: first slot is `length * 2 + 1`, following slots are data.
            uint256 length = (firstValue - 1) / 2;
            value = "";
            slot = uint256(keccak256(abi.encodePacked(slot)));
            // This is horribly inefficient - O(n^2). A better approach would be to build an array of words and concatenate them
            // all at once, but we're trying to avoid writing new library code.
            while(length > 0) {
                if(length < 32) {
                    value = bytes.concat(value, getSingleStorageProof(storageRoot, slot++, proof.storageProofs[proofIdx++]).slice(0, length));
                    length = 0;
                } else {
                    value = bytes.concat(value, getSingleStorageProof(storageRoot, slot++, proof.storageProofs[proofIdx++]));
                    length -= 32;
                }
            }
            return (value, proofIdx);
        } else {
            // Short value: least significant byte is `length * 2`, other bytes are data.
            uint256 length = (firstValue & 0xFF) / 2;
            return (abi.encode(firstValue).slice(0, length), proofIdx);
        }
    }

    /**
     * @notice Discerns slots from commands and gets values from contract storage
     * @param commands an array of commands
     * @param cIdx index of the command to proceed from
     * @param constants an array of constant values
     * @param stateRoot the root hash from which all storage proofs start
     * @param proof proof
     * @return values a bytes array of returned values
     * @return iValues a bytes array of internal values
     * @return nextCIdx index of the command to proceed from for the next target
     */
    function getStorageValues(address target, bytes32[] memory commands, uint8 cIdx, bytes[] memory constants, bytes32 stateRoot, StateProof memory proof) internal pure returns(bytes[] memory values, bytes[] memory iValues, uint8 nextCIdx) {
       
        bytes32 storageRoot = getStorageRoot(stateRoot, target, proof.stateTrieWitness);
        uint256 proofIdx = 0;

        values = new bytes[](0);
        iValues = new bytes[](0);

        bytes1 lastTarget = commands[cIdx][0];

        for (uint8 i = cIdx; i < commands.length; i++) {

            CommandData memory commandData;
            commandData.command = commands[i];
            commandData.tByte = commandData.command[0];
            commandData.tOpcode = uint8(commandData.tByte) & 0xe0;
            commandData.tOperand = uint8(commandData.tByte) & 0x1f;
            
            nextCIdx = i;

            //When the target id changes..
            if (lastTarget != commandData.tByte) {
                break;
            }
            lastTarget = commandData.tByte;

            values = getValueFromPath(storageRoot, commands[i], constants, values, iValues, proof, proofIdx);

            proofIdx++;
        }
    }


    /**
     * @dev gets a value by following a slot path defined in a specific command
     * @param storageRoot the storage root
     * @param thisCommand the command we are processing
     * @param constants the constants available from which to build command paths
     * @param values values discerned from previous commands
     * @param iValues values discerned from slicing and manipulating previously discerned values
     * @param proof proof data
     * @param proofIdx proof index
     * @return bytes[]
     */
    function getValueFromPath(bytes32 storageRoot, bytes32 thisCommand, bytes[] memory constants, bytes[] memory values, bytes[] memory iValues, StateProof memory proof, uint256 proofIdx) internal pure returns(bytes[] memory) {

        uint256 vIndex = values.length;

        (SlotData memory data, uint8 postProcessIndex) = computeFirstSlot(thisCommand, constants, values, iValues);

        if(!data.isDynamic) {

            assembly {
                mstore(values, add(vIndex, 1)) // Increment values array length
            }
            
            values[vIndex] = abi.encode(getFixedValue(storageRoot, data.slot, proof.storageProofs[proofIdx]));

            if(values[vIndex].length > 32) {
                revert InvalidSlotSize(values[vIndex].length);
            }

        } else {

            assembly {
                mstore(values, add(vIndex, 1)) // Increment values array length
            }

            (values[vIndex], proofIdx) = getDynamicValue(storageRoot, data.slot, proof, proofIdx);
        }

        postProcessValue(thisCommand, constants, values[vIndex], iValues, postProcessIndex);

        return values;
    }


    /**
     * @dev executes post processing operations on a value e.g for slicing data
     * @param command the command we are post processing
     * @param constants the constants available from which to build command paths
     * @param value value discerned from previous command
     * @param iValues values discerned from slicing and manipulating previously discerned values
     * @param postProcessIndex the index of the postProcessing separator (0xfe)
     */
    function postProcessValue(bytes32 command, bytes[] memory constants, bytes memory value, bytes[] memory iValues, uint8 postProcessIndex) internal pure {

        for (uint256 k = postProcessIndex + 1; k < 32; k++) {

            uint8 opcode = uint8(command[k]) & 0xe0;
            uint8 operand = uint8(command[k]) & 0x1f;

            if (opcode == OP_SLICE) {

                uint8 offset = uint8(bytes1(constants[operand].slice(0, 1)));
                uint8 length = uint8(bytes1(constants[operand].slice(1, 1)));

                bytes memory parsedValue = value.slice(offset, length);

                //pads to 32 bytes
                //return address(uint160(bytes20(parsedValue)));
                
                bytes32 paddedIv;

                assembly {
                    paddedIv := mload(add(parsedValue, 32))
                }

                bytes32 iv = paddedIv >> (256 - (8 * parsedValue.length));

                uint256 ivIndex = k - (postProcessIndex + 1);

                assembly {
                   mstore(iValues, add(ivIndex, 1)) // Increment internal values array length
                }

                iValues[ivIndex] = abi.encodePacked(iv);
            }
        }    
    }
}