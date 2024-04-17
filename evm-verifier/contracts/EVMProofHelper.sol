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

uint8 constant OP_CONSTANT = 0x00;
uint8 constant OP_BACKREF = 0x20;
uint8 constant OP_SLICE = 0x40;
uint8 constant FLAG_DYNAMIC = 0x01;

library EVMProofHelper {
    using Bytes for bytes;

    error Problem(bytes);
    error Oops(uint8);
    error Oops2(uint256);

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
        
        //revert Oops2(slot);
        //revert Problem(witness);

        console.log("slut");
        console.log(slot);

        (bool exists, bytes memory retrievedValue) = SecureMerkleTrie.get(
            abi.encodePacked(slot),
            witness,
            storageRoot
        );
        if(!exists) {

            //revert Oops(uint8(1));
            // Nonexistent values are treated as zero.
            return "";
        }

        bytes memory asBytes = abi.encodePacked(hex"000000000000000000000000c9f7e9e42b17744b72c5b07b6c38128c8fd6447a");

        //revert Problem(asBytes);
        
        return RLPReader.readBytes(retrievedValue);
    }

    function getFixedValue(bytes32 storageRoot, uint256 slot, bytes[] memory witness) private view returns(bytes32) {
        bytes memory value = getSingleStorageProof(storageRoot, slot, witness);
        // RLP encoded storage slots are stored without leading 0 bytes.
        // Casting to bytes32 appends trailing 0 bytes, so we have to bit shift to get the 
        // original fixed-length representation back.
        return bytes32(value) >> (256 - 8 * value.length);
    }

    function executeOperation(bytes1 operation, bytes[] memory constants, bytes[] memory values) private view returns(bytes memory) {
        uint8 opcode = uint8(operation) & 0xe0;
        uint8 operand = uint8(operation) & 0x1f;

        console.log("opcode");
        console.log(opcode);

        if(opcode == OP_CONSTANT) {

            console.log("CONSTANT");

            //revert Problem(constants[operand]);

            bytes memory thisConstant = constants[operand];

                        bytes32 ist;

            assembly {
                ist := mload(add(thisConstant, 32))
                //ist := shr(ist, 8)
            }

            bytes32 la = ist >> (256 - (8 * thisConstant.length));

            return abi.encodePacked(la);


            return constants[operand];

            
        } else if(opcode == OP_BACKREF) {
            return values[operand];
        } else if(opcode == OP_SLICE) {

            console.log("slice");

            //const [offset, length] = getBytes(constants[operand])

            uint8 offset = uint8(bytes1(constants[operand].slice(0, 1)));
            uint8 length = uint8(bytes1(constants[operand].slice(1, 1)));

            //const value = await (await requests[requests.length - 1]).value();

console.log("slice 2");
console.log(offset);
console.log(length);
console.log(values.length);

            //NOTE TOM: This was -2 previously and not working. Unsure why.
            bytes memory parsedValue = values[values.length - 1].slice(offset, length);

console.log("slice 2b");

            //pads to 32 bytes
            //return address(uint160(bytes20(parsedValue)));
            
            bytes32 ist;

            //bytes32 hmm = bytes12(parsedValue<<160);

console.log("slice 3");

            assembly {
                ist := mload(add(parsedValue, 32))
                //ist := shr(ist, 8)
            }

            bytes32 la = ist >> (256 - (8 * parsedValue.length));

            //bytes memory ans = bytes(ist);

            //bytes memory alt = abi.encodePacked(la);

            //revert Problem(abi.encodePacked(la));


            //"for strings and byte arrays, h(k) is just the unpadded data."
            //return abi.encodePacked(parsedValue);
            //otherwise
            return abi.encodePacked(la);




        } else {
            revert UnknownOpcode(opcode);
        }
    }

    function computeFirstSlot(bytes32 command, bytes[] memory constants, bytes[] memory values) private view returns(bool isDynamic, uint256 slot) {
        uint8 flags = uint8(command[1]);
        //revert Oops(flags);
        isDynamic = (flags & FLAG_DYNAMIC) != 0;

            //revert Problem(constants[operand]);

        bytes memory slotData = executeOperation(command[2], constants, values);

        console.log("slotData");
        console.logBytes(slotData);

        console.log("command length");
        console.log(command.length);

        require(slotData.length == 32, "First path element must be 32 bytes");
        slot = uint256(bytes32(slotData));
        for(uint256 j = 3; j < 32 && command[j] != 0xff; j++) {
            console.log("hi");
            console.logBytes1(command[j]);
            bytes memory index = executeOperation(command[j], constants, values);
            console.log("di");
            slot = uint256(keccak256(abi.encodePacked(index, slot)));
        }

        console.log("computeFirstSlot");
        console.log(slot);
    }

    function getDynamicValue(bytes32 storageRoot, uint256 slot, StateProof memory proof, uint256 proofIdx) private view returns(bytes memory value, uint256 newProofIdx) {
        bytes32 fValue = getFixedValue(storageRoot, slot, proof.storageProofs[proofIdx++]);
        uint256 firstValue = uint256(fValue);
        //0x01 is 00000001 in binary

        console.log("firstValue");
        console.logBytes32(fValue);
        console.log(firstValue);
        
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

            console.log("herre");
            // Short value: least significant byte is `length * 2`, other bytes are data.
            uint256 length = (firstValue & 0xFF) / 2;
            return (abi.encode(firstValue).slice(0, length), proofIdx);
        }
    }

    struct Command {
        bytes32 com;
        bytes1 tByte;
        uint8 opcode;
        uint8 operand;
    }

    function getStorageValues(bytes32[] memory commands, uint8 cIdx, bytes[] memory constants, bytes32 stateRoot, StateProof memory proof) internal view returns(bytes[] memory values, uint8 nextCIdx) {
       
       //console.log("GET STORAGE VALUES");
       //console.log(cIdx);

        console.log("commands length");
        console.log(commands.length);

        //console.logBytes32(commands[0]);
        //console.logBytes32(commands[1]);
        //console.logBytes32(commands[2]);

        Command memory thisCommand;
        thisCommand.com = commands[cIdx];
        thisCommand.tByte = thisCommand.com[0];
        thisCommand.opcode = uint8(thisCommand.com[0]) & 0xe0;
        thisCommand.operand = uint8(thisCommand.com[0]) & 0x1f;

        console.log("tOperand", thisCommand.operand);

        address target = address(uint160(bytes20(constants[thisCommand.operand])));

        bytes32 storageRoot = getStorageRoot(stateRoot, target, proof.stateTrieWitness);
        uint256 proofIdx = 0;
        values = new bytes[](0);

        uint8 valueIndex = 0;

        for(uint8 i = cIdx; i < commands.length; i++) {

{
            nextCIdx = i;

            console.log("i");
            console.log(i);

            //bytes32 command = commands[i];

            //When the target id changes..
            if (commands[i][0] != thisCommand.tByte) {

                console.log("break");
                break;
            }


            //console.log("thisCommand");
            //console.logBytes32(command);

            (bool isDynamic, uint256 slot) = computeFirstSlot(commands[i], constants, values);
            if(!isDynamic) {

                console.log("storageRoot");
                console.logBytes32(storageRoot);

                console.log("slot");
                console.log(slot);


                console.log("prooooof", proofIdx);
                console.log(proof.storageProofs.length);

                //console.log(proof.storageProofs[proofIdx].length);
                //console.logBytes(proof.storageProofs[proofIdx][0]);
                //console.logBytes(proof.storageProofs[proofIdx][1]);
                //console.logBytes(proof.storageProofs[proofIdx][2]);

                console.log("values length1");
                console.log(values.length);

                assembly {
                    //mstore(values, add(i, 1)) // Increment values array length
                    mstore(values, add(valueIndex, 1)) // Increment values array length
                }

                console.log("TWOOO");


                values[valueIndex] = abi.encode(getFixedValue(storageRoot, slot, proof.storageProofs[proofIdx]));

                proofIdx++;

                console.log("value");
                console.logBytes(values[valueIndex]);
                console.log("values length");
                console.log(values.length);

                //revert Problem(values[i]);
                if(values[valueIndex].length > 32) {
                    revert InvalidSlotSize(values[valueIndex].length);
                }
            } else {
                console.log("DYNAMIC");

                assembly {
                    //TOM these break it
                    //mstore(values, add(i, 1)) // Increment values array length
                    //mstore(values, 5) // Increment values array length

                    //this works
                    mstore(values, add(valueIndex, 1)) // Increment values array length

                }

                (values[valueIndex], proofIdx) = getDynamicValue(storageRoot, slot, proof, proofIdx);
            }

            valueIndex++;

            console.log("helper val len");
            console.log(values.length);
}
        }
    }
}