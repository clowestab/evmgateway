//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import { StateProof, CommandData, EVMProofHelper } from "@ensdomains/evm-verifier/contracts/EVMProofHelper.sol";
import {IEVMVerifier} from '@ensdomains/evm-verifier/contracts/IEVMVerifier.sol';
import {Node, IRollupCore} from '@arbitrum/nitro-contracts/src/rollup/IRollupCore.sol';
import {RLPReader} from '@eth-optimism/contracts-bedrock/src/libraries/rlp/RLPReader.sol';

struct ArbWitnessData {
    bytes32 version;
    bytes32 sendRoot;
    uint64 nodeIndex;
    bytes rlpEncodedBlock;
}

struct ProcessData {
    uint8 nextCIdxToUse;
    bytes[] internalValues;
    RLPReader.RLPItem[] headerFields;
    address target;
    bytes32 confirmData;
    bytes32 stateRoot;
}

uint8 constant TOP_CONSTANT = 0x00;
uint8 constant TOP_BACKREF = 0x20;
uint8 constant TOP_INTERNALREF = 0x40;

contract ArbVerifier is IEVMVerifier {
    IRollupCore public immutable rollup;
    string[] _gatewayURLs;

    constructor(string[] memory _urls, IRollupCore _rollupAddress) {
        rollup = _rollupAddress;
        _gatewayURLs = _urls;
    }

    /*
     * Retrieves an array of gateway URLs used by the contract.
     * @returns {string[]} An array containing the gateway URLs.
     *     */
    function gatewayURLs() external view returns (string[] memory) {
        return _gatewayURLs;
    }

    /*
     * Retrieves storage values from the specified target address
     *
     * @param {bytes32[]} commands - An array of storage keys (commands) to query.
     * @param {bytes[]} constants - An array of constant values corresponding to the storage keys.
     * @param {bytes} proof - The proof data containing Arbitrum witness data and state proof.
     */
    function getStorageValues(
        bytes32[] memory commands,
        bytes[] memory constants,
        bytes[] memory proofsData
    ) external view returns (bytes[][] memory storageResults) {

        //storageResults is a multidimensional array of values indexed on target
        //There is a proof for each target so we initalize the array with that length to avoid playing in assembly (which was blowing up)
        storageResults = new bytes[][](proofsData.length);

        ProcessData memory pData;
        pData.nextCIdxToUse = 0;

        for (uint256 i = 0; i < proofsData.length; i++) {

            (ArbWitnessData memory arbData, StateProof memory stateProof) = abi
                .decode(proofsData[i], (ArbWitnessData, StateProof));

            //Get the node from the rollup contract
            Node memory rblock = rollup.getNode(arbData.nodeIndex);

            //The confirm data is the keccak256 hash of the block hash and the send root. It is used to verify that the rblock is a subject of the layer 2 block that is being proven.
            pData.confirmData = keccak256(
                abi.encodePacked(
                    keccak256(arbData.rlpEncodedBlock),
                    arbData.sendRoot
                )
            );

            //Verify that the block hash is correct
            require(rblock.confirmData == pData.confirmData, 'confirmData mismatch');
            //Verifiy that the block that is being proven is the same as the block that was passed in

            //Now that we know that the block is valid, we can get the state root from the block.
            pData.stateRoot = getStateRootFromBlock(arbData.rlpEncodedBlock);

            CommandData memory firstCommand;
            firstCommand.command = commands[pData.nextCIdxToUse];
            firstCommand.tByte = firstCommand.command[0];
            firstCommand.tOpcode = uint8(firstCommand.tByte) & 0xe0;
            firstCommand.tOperand = uint8(firstCommand.tByte) & 0x1f;
            //pData.headerFields = RLPReader.readList(l1Data.blockHeader);
            //bytes32 stateRoot = bytes32(RLPReader.readBytes(pData.headerFields[3]));

            if (firstCommand.tOpcode == TOP_CONSTANT) {

                pData.target = address(uint160(bytes20(constants[firstCommand.tOperand])));

            } else if (firstCommand.tOpcode == TOP_BACKREF) {

                //TOM TODO make this a reference to the correct result
                pData.target = abi.decode(storageResults[0][0], (address));

            } else if (firstCommand.tOpcode == TOP_INTERNALREF) {

                //TOM TODO make this a reference to the correct result
                pData.target = abi.decode(pData.internalValues[firstCommand.tOperand], (address));
            }

            (bytes[] memory returnValues, bytes[] memory internalValues, uint8 nextCIdx) = EVMProofHelper.getStorageValues(
                pData.target,
                commands,
                pData.nextCIdxToUse,
                constants,
                pData.stateRoot,
                stateProof
            );

            pData.internalValues = internalValues;
            storageResults[i] = returnValues;
            pData.nextCIdxToUse = nextCIdx;
        }
    }

    /*
     * Decodes a block by extracting and converting the bytes32 value from the RLP-encoded block to get the stateRoot.
     *
     * @param {bytes} rlpEncodedBlock - The RLP-encoded block information.
     * @returns {bytes32} The stateRoot extracted from the RLP-encoded block information.
     */
    function getStateRootFromBlock(
        bytes memory rlpEncodedBlock
    ) internal pure returns (bytes32) {
        RLPReader.RLPItem[] memory i = RLPReader.readList(rlpEncodedBlock);
        //StateRoot is located at idx 3
        return bytes32(RLPReader.readBytes(i[3]));
    }
}
