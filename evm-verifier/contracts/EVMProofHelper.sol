// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {RLPReader} from "@eth-optimism/contracts-bedrock/src/libraries/rlp/RLPReader.sol";
import {Bytes} from "@eth-optimism/contracts-bedrock/src/libraries/Bytes.sol";
import {SecureMerkleTrie} from "./SecureMerkleTrie.sol";

import "@ganache/console.log/console.sol";


struct StateProof {
    bytes[] stateTrieWitness;         // Witness proving the `storageRoot` against a state root.
    bytes[][] storageProofs;          // An array of proofs of individual storage elements 
}


struct CommandData {
    bytes32 command;
    bytes1 tByte;
    uint8 tOpcode;
    uint8 tOperand;
    uint256 cLength;
}

uint8 constant OP_CONSTANT = 0x00;
uint8 constant OP_BACKREF = 0x20;
uint8 constant OP_SLICE = 0x40;
uint8 constant OP_IVALUE = 0x80;
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
    function getSingleStorageProof(bytes32 storageRoot, uint256 slot, bytes[] memory witness) private view returns (bytes memory) {
        
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

    function getFixedValue(bytes32 storageRoot, uint256 slot, bytes[] memory witness) private view returns(bytes32) {
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
     * @param internalValues an array of non-provable values used internally for slot generation e.g. slices of previous values
     * @return bytes the value/key to use in slot generation
     */
    function executeOperation(bytes1 operation, bytes[] memory constants, bytes[] memory values, bytes[] memory internalValues) private view returns(bytes memory) {
        uint8 opcode = uint8(operation) & 0xe0;
        uint8 operand = uint8(operation) & 0x1f;

        if(opcode == OP_CONSTANT) {

            return constants[operand];

            
        } else if(opcode == OP_BACKREF) {
            return values[operand];
        } else if(opcode == OP_IVALUE) {
            return internalValues[operand];
        } else if(opcode == OP_SLICE) {

            //The offset is the first byte of the operand constant, and the length the second byte
            uint8 offset = uint8(bytes1(constants[operand].slice(0, 1)));
            uint8 length = uint8(bytes1(constants[operand].slice(1, 1)));

            //TODO allow setting of value index to use
            bytes memory parsedValue = values[values.length - 1].slice(offset, length);

            console.log("Parsed values");
            console.logBytes(parsedValue);

            bytes32 ist;

            assembly {
                ist := mload(add(parsedValue, 32))
                //ist := shr(ist, 8)
            }

            bytes32 la = ist >> (256 - (8 * parsedValue.length));

            //"for strings and byte arrays, h(k) is just the unpadded data."
            //return abi.encodePacked(parsedValue);
            //otherwise
            return abi.encodePacked(la);
        } else {
            revert UnknownOpcode(opcode);
        }
    }

    struct ComputeData {
        bool isDynamic;
        uint256 slot;
        uint8 postProcessIndex;
    }

    function computeFirstSlot(bytes32 command, bytes[] memory constants, bytes[] memory values, bytes[] memory internalValues) private view returns(ComputeData memory data, uint8 postProcessIndex) {
        uint8 flags = uint8(command[1]);
        data.isDynamic = (flags & FLAG_DYNAMIC) != 0;

        bytes memory slotData = executeOperation(command[2], constants, values, internalValues);

        console.log("slotData");
        console.logBytes(slotData);

        console.log("command length");
        console.log(command.length);

        require(slotData.length == 32, "First path element must be 32 bytes");
        data.slot = uint256(bytes32(slotData));
        for(uint256 j = 3; j < 32; j++) {

            if (command[j] == 0xfe) {
                postProcessIndex = uint8(j);
                break;
            }

            if (command[j] == 0xff) {
                break;
            }

            console.log("hi");
            console.logBytes32(command);
            console.logBytes1(command[j]);
            bytes memory index = executeOperation(command[j], constants, values, internalValues);
            console.log("di");
            data.slot = uint256(keccak256(abi.encodePacked(index, data.slot)));
        }

        console.log("computeFirstSlot");
        console.log(data.slot);
    }

    function getDynamicValue(bytes32 storageRoot, uint256 slot, StateProof memory proof, uint256 proofIdx) private view returns(bytes memory value, uint256 newProofIdx) {
        
        console.log("B1", proof.storageProofs.length);
        console.log("B1", slot);
        console.log("B1", proofIdx);
        bytes32 fValue = getFixedValue(storageRoot, slot, proof.storageProofs[proofIdx++]);
                console.log("B2");

        uint256 firstValue = uint256(fValue);
        //0x01 is 00000001 in binary

        console.log("firstValue");
        console.logBytes32(fValue);
        console.log(firstValue);
        
        if(firstValue & 0x01 == 0x01) {
            // Long value: first slot is `length * 2 + 1`, following slots are data.
            uint256 length = (firstValue - 1) / 2;
            console.log("length", length);
            value = "";
            slot = uint256(keccak256(abi.encodePacked(slot)));
            // This is horribly inefficient - O(n^2). A better approach would be to build an array of words and concatenate them
            // all at once, but we're trying to avoid writing new library code.
            while(length > 0) {
                if(length < 32) {

                    console.log("PRUF", proofIdx);

                    value = bytes.concat(value, getSingleStorageProof(storageRoot, slot++, proof.storageProofs[proofIdx++]).slice(0, length));
                    length = 0;
                } else {
                    console.log("heyre", proofIdx);
                    console.logBytes(proof.storageProofs[0][1]);
                    value = bytes.concat(value, getSingleStorageProof(storageRoot, slot++, proof.storageProofs[proofIdx++]));
                    length -= 32;
                }
            }
            console.log("value");
            console.logBytes(value);
            return (value, proofIdx);
        } else {

            console.log("herre");
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
     * @return internalValues a bytes array of internal values
     * @return nextCIdx index of the command to proceed from for the next target
     */
    function getStorageValues(address target, bytes32[] memory commands, uint8 cIdx, bytes[] memory constants, bytes32 stateRoot, StateProof memory proof) internal view returns(bytes[] memory values, bytes[] memory internalValues, uint8 nextCIdx) {
       
        bytes32 storageRoot = getStorageRoot(stateRoot, target, proof.stateTrieWitness);
        uint256 proofIdx = 0;

        //TOMNOTE we have to reinit this otherwise somewhere along the lines it uses the same memory as the previous call?
        values = new bytes[](0);
        internalValues = new bytes[](0);

        bytes1 lastTarget = commands[cIdx][0];

        for (uint8 i = cIdx; i < commands.length; i++) {

            CommandData memory commandData;
            commandData.command = commands[i];
            commandData.tByte = commandData.command[0];
            commandData.tOpcode = uint8(commandData.tByte) & 0xe0;
            commandData.tOperand = uint8(commandData.tByte) & 0x1f;
            commandData.cLength = commands.length;
            
            nextCIdx = i;

            console.log("i");
            console.log(i);
            console.logBytes32(commands[i]);

            //When the target id changes..
            if (lastTarget != commandData.tByte) {

                console.log("break");
                break;
            }
            lastTarget = commandData.tByte;

            values = getValueFromPath(storageRoot, commands[i], constants, values, internalValues, proof, proofIdx);
                        console.log("post", values.length);
                        console.logBytes(values[0]);

            proofIdx++;

            console.log("pooost", values.length);
        }
    }


    function getValueFromPath(bytes32 storageRoot, bytes32 thisCommand, bytes[] memory constants, bytes[] memory values, bytes[] memory internalValues, StateProof memory proof, uint256 proofIdx) internal view returns(bytes[] memory) {

            uint256 newIndex = values.length;

            (ComputeData memory data, uint8 postProcessIndex) = computeFirstSlot(thisCommand, constants, values, internalValues);

            console.log("internalVals pre", internalValues.length);

            if(!data.isDynamic) {

                assembly {
                    //mstore(values, add(i, 1)) // Increment values array length
                    mstore(values, add(newIndex, 1)) // Increment values array length
                }

                //console.log("TWOOO", newIndex);


                //values[0] = abi.encodePacked(uint8(0),uint8(0),uint8(49));
                
                values[newIndex] = abi.encode(getFixedValue(storageRoot, data.slot, proof.storageProofs[proofIdx]));

            console.log("internalVals mid", internalValues.length);


                //console.log("value");
                //console.logBytes(values[newIndex]);
                //console.log("values length");
                //console.log(values.length);

                if(values[newIndex].length > 32) {
                    revert InvalidSlotSize(values[newIndex].length);
                }
            } else {
                console.log("DYNAMIC");

                assembly {
                    //TOM these break it
                    //mstore(values, add(i, 1)) // Increment values array length
                    //mstore(values, 5) // Increment values array length

                    //this works
                    mstore(values, add(newIndex, 1)) // Increment values array length

                }

                (values[newIndex], proofIdx) = getDynamicValue(storageRoot, data.slot, proof, proofIdx);
            }

            console.log("internalVals post", internalValues.length);

            console.log("postProcessIndex", postProcessIndex);


            postProcessValues(thisCommand, constants, values, postProcessIndex, internalValues);

            return values;
    }


    function postProcessValues(bytes32 command, bytes[] memory constants, bytes[] memory values, uint8 postProcessIndex, bytes[] memory internalValues) internal view {

        for (uint256 k = postProcessIndex + 1; k < 32; k++) {

            uint8 opcode = uint8(command[k]) & 0xe0;
            uint8 operand = uint8(command[k]) & 0x1f;

            if (opcode == OP_SLICE) {

                console.log("SLYCE");

                            console.log("slice");

            //const [offset, length] = getBytes(constants[operand])

            uint8 offset = uint8(bytes1(constants[operand].slice(0, 1)));
            uint8 length = uint8(bytes1(constants[operand].slice(1, 1)));

            //const value = await (await requests[requests.length - 1]).value();

console.log("slice 2");
console.log(offset);
console.log(length);
console.log(values.length);
console.logBytes(values[0]);

            //NOTE TOM: This was -2 previously and not working. Unsure why.
            bytes memory parsedValue = values[0].slice(offset, length);

console.log("slice 2b");
console.logBytes(values[0]);

            //pads to 32 bytes
            //return address(uint160(bytes20(parsedValue)));
            
            bytes32 ist;

            //bytes32 hmm = bytes12(parsedValue<<160);


            assembly {
                ist := mload(add(parsedValue, 32))
                //ist := shr(ist, 8)
            }

console.log("slice 3");
console.logBytes(values[0]);

            bytes32 la = ist >> (256 - (8 * parsedValue.length));



            //bytes memory ans = bytes(ist);

            //bytes memory alt = abi.encodePacked(la);

            //"for strings and byte arrays, h(k) is just the unpadded data."
            //return abi.encodePacked(parsedValue);
            //otherwise

uint256 index = k - (postProcessIndex + 1);

                assembly {
                   mstore(internalValues, add(index, 1)) // Increment values array length
                }


console.log("slice 4", index);
console.log("slice 4b", internalValues.length);
console.logBytes(values[0]);


            internalValues[index] = abi.encodePacked(la);

            console.log("BYTES");
            console.logBytes(values[0]);
            console.logBytes(internalValues[index]);
            }
        }    
    }
}