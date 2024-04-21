// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { IEVMVerifier } from "@ensdomains/evm-verifier/contracts/IEVMVerifier.sol";
import { RLPReader } from "@eth-optimism/contracts-bedrock/src/libraries/rlp/RLPReader.sol";
import { StateProof, EVMProofHelper } from "@ensdomains/evm-verifier/contracts/EVMProofHelper.sol";
import "./console.sol";

struct L1WitnessData {
    uint256 blockNo;
    bytes blockHeader;
}

struct ProofData {
    uint256 blockNo;
    bytes blockHeader;
}

uint8 constant TOP_CONSTANT = 0x00;
uint8 constant TOP_BACKREF = 0x20;

contract L1Verifier is IEVMVerifier {
    error BlockHeaderHashMismatch(uint256 current, uint256 number, bytes32 expected, bytes32 actual);
    
    error Problem(bytes);
    error Oops(uint8);


    string[] _gatewayURLs;

    constructor(string[] memory urls) {
        _gatewayURLs = urls;
    }

    function gatewayURLs() external view returns(string[] memory) {
        return _gatewayURLs;
    }


    struct Command {
        bytes32 command;
        bytes1 targetByte;
        uint8 opcode;
        uint8 operand;
        uint256 cLength;
        address target;
    }


    /**
     * The 3668 callback calls through to this method on the verifier to get proven values
     */
    function getStorageValues(bytes32[] memory commands, bytes[] memory constants, bytes[] memory proofsData) external view returns(bytes[][] memory storageResults) {
       
        //storageResults is a multidimensional array of values indexed on target
        //There is a proof for each target so we initalize the array with that length to avoid playing in assembly (which was blowing up)
        storageResults = new bytes[][](proofsData.length);

        console.log("prii", proofsData.length);
       //(uint256 count, (L1WitnessData memory l1Data, StateProof memory stateProof)[] proofs) = abi.decode(proof, (uint256, (L1WitnessData, StateProof)[]));
       //(bytes[] memory proofDatas) = abi.decode(proofsData, (bytes[]));

                                //revert Oops(uint8(3));

        //console.log("proof length");
        //console.log(proofsData.length);
        
        uint8 nextCIdxToUse = 0;

        for(uint256 i = 0; i < proofsData.length; i++) {

            //console.log("III");
            //console.log(i);

            //revert Problem(proofsData[0]);

//so we have an array of proofs which are of the form
        //[
        //'tuple(uint256 blockNo, bytes blockHeader)',
        //'tuple(bytes[] stateTrieWitness, bytes[][] storageProofs)',
        //]

            (L1WitnessData memory l1Data, StateProof memory stateProof) = abi.decode(proofsData[i], (L1WitnessData, StateProof));

            //(uint256 count, (L1WitnessData memory l1Data, StateProof memory stateProof)[] proofs) = abi.decode(proofDatas[i], (uint256, (L1WitnessData, StateProof)[]));

//revert Oops(uint8(l1Data.blockNo));

            if(keccak256(l1Data.blockHeader) != blockhash(l1Data.blockNo)) {
                revert BlockHeaderHashMismatch(block.number, l1Data.blockNo, blockhash(l1Data.blockNo), keccak256(l1Data.blockHeader));
            }
            RLPReader.RLPItem[] memory headerFields = RLPReader.readList(l1Data.blockHeader);
            bytes32 stateRoot = bytes32(RLPReader.readBytes(headerFields[3]));
            
            //console.log("Target");
            //console.log(targets[i]);

            //address targetToUse = targets[i];

            //if (uint160(targets[i]) <= 256) {
                //console.log("hhhh");
                //console.logBytes(storageResults[0][1]);
            //    targetToUse = abi.decode(storageResults[0][1], (address));
            //}

        Command memory firstCommand;
        firstCommand.command = commands[nextCIdxToUse];
        firstCommand.targetByte = firstCommand.command[0];
        firstCommand.opcode = uint8(firstCommand.command[0]) & 0xe0;
        firstCommand.operand = uint8(firstCommand.command[0]) & 0x1f;
        firstCommand.cLength = commands.length;
        firstCommand.target = address(uint160(bytes20(constants[firstCommand.operand])));

        if (firstCommand.opcode == TOP_BACKREF) {

//console.logBytes(storageResults[0][0]);
                    //TOM TODO make this a reference to the correct result
                    firstCommand.target = abi.decode(storageResults[0][0], (address));

                    console.log("use this1", firstCommand.target);


        }

            (bytes[] memory values, uint8 nextCIdx) = EVMProofHelper.getStorageValues(firstCommand.target, commands, nextCIdxToUse, constants, stateRoot, stateProof);
            

            //console.log("poost2", values.length);
            //console.log("State root");
            //console.logBytes(abi.encodePacked(stateRoot));

            //console.log("Block Number");
            //console.log(l1Data.blockNo);

            //console.log("Target");
            //console.log(targets[i]);

            //console.log("Commands");
            //console.logBytes32(commands[0]);

            //console.log("constants");
            //console.logBytes(constants[0]);

            //console.log("stateProof");
            //console.logBytes(stateProof.stateTrieWitness[0]);

            //console.log("poost3", values.length);

            
            assembly {
                //This was blowing up
                //mstore(storageResults, add(i, 1)) // Increment command array length
            }


            storageResults[i] = values;

            //console.log("resulti");
            //console.log(storageResults.length);
            //console.log(storageResults[i].length);


            if (i == 1) {
                //console.logBytes(values[0]);
            }
            nextCIdxToUse = nextCIdx;

            //console.log("nextCIdxToUse");
            //console.log(nextCIdxToUse);

        }

            console.log("resultEND");

            console.logBytes(storageResults[0][0]);
            //console.logBytes(storageResults[1][0]);

    bytes memory rw = storageResults[0][0];
        //console.log("qq1");
                    //console.logBytes(rw);

                                    //revert Oops(uint8(6));
        //return storageResults;
    }
}
