// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { IEVMVerifier } from "@ensdomains/evm-verifier/contracts/IEVMVerifier.sol";
import { RLPReader } from "@eth-optimism/contracts-bedrock/src/libraries/rlp/RLPReader.sol";
import { StateProof, CommandData, EVMProofHelper } from "@ensdomains/evm-verifier/contracts/EVMProofHelper.sol";
import "./console.sol";

struct L1WitnessData {
    uint256 blockNo;
    bytes blockHeader;
}

struct ProofData {
    uint256 blockNo;
    bytes blockHeader;
}

struct ProcessData {
    uint8 nextCIdxToUse;
    bytes[] internalValues;
    RLPReader.RLPItem[] headerFields;
    address target;
}

uint8 constant TOP_CONSTANT = 0x00;
uint8 constant TOP_BACKREF = 0x20;
uint8 constant TOP_INTERNALREF = 0x40;

contract L1Verifier is IEVMVerifier {
    error BlockHeaderHashMismatch(uint256 current, uint256 number, bytes32 expected, bytes32 actual);
    
    string[] _gatewayURLs;

    constructor(string[] memory urls) {
        _gatewayURLs = urls;
    }

    function gatewayURLs() external view returns(string[] memory) {
        return _gatewayURLs;
    }

    /**
     * The 3668 callback calls through to this method on the verifier to get proven values
     */
    function getStorageValues(bytes32[] memory commands, bytes[] memory constants, bytes[] memory proofsData) external view returns(bytes[][] memory storageResults) {
       
        //storageResults is a multidimensional array of values indexed on target
        //There is a proof for each target so we initalize the array with that length to avoid playing in assembly (which was blowing up)
        storageResults = new bytes[][](proofsData.length);
        
        ProcessData memory pData;
        pData.nextCIdxToUse = 0;
        
        for (uint256 i = 0; i < proofsData.length; i++) {

            //so we have an array of proofs which are of the form
            //[
            //'tuple(uint256 blockNo, bytes blockHeader)',
            //'tuple(bytes[] stateTrieWitness, bytes[][] storageProofs)',
            //]

            (L1WitnessData memory l1Data, StateProof memory stateProof) = abi.decode(proofsData[i], (L1WitnessData, StateProof));

            if(keccak256(l1Data.blockHeader) != blockhash(l1Data.blockNo)) {
                revert BlockHeaderHashMismatch(block.number, l1Data.blockNo, blockhash(l1Data.blockNo), keccak256(l1Data.blockHeader));
            }

            CommandData memory firstCommand;
            firstCommand.command = commands[pData.nextCIdxToUse];
            firstCommand.tByte = firstCommand.command[0];
            firstCommand.tOpcode = uint8(firstCommand.tByte) & 0xe0;
            firstCommand.tOperand = uint8(firstCommand.tByte) & 0x1f;
            pData.headerFields = RLPReader.readList(l1Data.blockHeader);
            bytes32 stateRoot = bytes32(RLPReader.readBytes(pData.headerFields[3]));
            
            if (firstCommand.tOpcode == TOP_CONSTANT) {

                pData.target = address(uint160(bytes20(constants[firstCommand.tOperand])));

            } else if (firstCommand.tOpcode == TOP_BACKREF) {

                //TOM TODO make this a reference to the correct result
                pData.target = abi.decode(storageResults[0][0], (address));

            } else if (firstCommand.tOpcode == TOP_INTERNALREF) {

                //TOM TODO make this a reference to the correct result
                pData.target = abi.decode(pData.internalValues[firstCommand.tOperand], (address));
            }

            (bytes[] memory values, bytes[] memory internalValues, uint8 nextCIdx) = EVMProofHelper.getStorageValues(pData.target, commands, pData.nextCIdxToUse, constants, stateRoot, stateProof);
            
            pData.internalValues = internalValues;
            
            storageResults[i] = values;

            pData.nextCIdxToUse = nextCIdx;
        }
    }
}
