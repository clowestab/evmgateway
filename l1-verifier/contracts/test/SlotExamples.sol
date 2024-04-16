// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { EVMFetcher } from '@ensdomains/evm-verifier/contracts/EVMFetcher.sol';
import { EVMFetchTarget } from '@ensdomains/evm-verifier/contracts/EVMFetchTarget.sol';
import { IEVMVerifier } from '@ensdomains/evm-verifier/contracts/IEVMVerifier.sol';

import "../console.sol";


contract SlotExamples is EVMFetchTarget {
    using EVMFetcher for EVMFetcher.EVMFetchRequest;

    IEVMVerifier verifier;                  // Slot 0
    address target;

    constructor(IEVMVerifier _verifier, address _target) {
        verifier = _verifier;
        target = _target;
    }
    
    function getLatest() public view returns(uint256) {
        EVMFetcher.newFetchRequest(verifier, target)
            .getStatic(0)
            .fetch(this.getLatestCallback.selector, "");
    }

    function getLatestCallback(bytes[][] memory values, bytes memory) public pure returns(uint256) {
        return abi.decode(values[0][0], (uint256));
    }

    function getLatestFromTwo(address secondTarget) public view returns(bytes[][] memory) {
        EVMFetcher.newFetchRequest(verifier, target)
            .getStatic(0)
            .setTarget(secondTarget)
            .getStatic(0)
            .fetch(this.getLatestFromTwoCallback.selector, "");
    }

    function getLatestFromTwoCallback(bytes[][] memory values, bytes memory) public pure returns(bytes[][] memory) {
        
        //return (abi.decode(values[0][0], (uint256)), abi.decode(values[0][0], (uint256)));

        return values;
    }
    


    function getName() public view returns(string memory) {
        EVMFetcher.newFetchRequest(verifier, target)
            .getDynamic(1)
            .fetch(this.getNameCallback.selector, "");
    }

    function getNameCallback(bytes[][] memory values, bytes memory) public view returns(string memory) {

        console.log("name cALLBACK");
        console.log(string(values[0][0]));
        return string(values[0][0]);
    }


    function getNameTwice() public view returns(string[] memory) {
        EVMFetcher.newFetchRequest(verifier, target)
            .getDynamic(1)
            .getDynamic(9)
            .fetch(this.getNameTwiceCallback.selector, "");
    }

    function getNameTwiceCallback(bytes[][] memory values, bytes memory) public view returns(string[] memory) {

        console.log("name twice cALLBACK");
        console.log(string(values[0][0]));

        string[] memory strings = new string[](2);
        strings[0] = string(values[0][0]);
        strings[1] = string(values[0][1]);
        
        return strings;
    }
    


    function getStringAndStringFromMapping() public view returns(string memory) {
        EVMFetcher.newFetchRequest(verifier, target)
            .getDynamic(9)
            .getDynamic(10)
                .element(string("tom"))
            .fetch(this.getStringAndStringFromMappingCallback.selector, "");
    }

    function getStringAndStringFromMappingCallback(bytes[][] memory values, bytes memory) public pure returns(string memory) {
        return string(values[0][1]);
    }


    function getHighscorerFromRefSlice() public view returns(string memory) {
        EVMFetcher.newFetchRequest(verifier, target)
            .getStatic(6)
            .getDynamic(3)
                .refSlice(0, 2, 1)
            .fetch(this.getHighscorerFromRefSliceCallback.selector, "");
    }

    function getHighscorerFromRefSliceCallback(bytes[][] memory values, bytes memory) public view returns(string memory) {

        string memory answer = string(values[0][1]);
        console.log(answer);
        return string(values[0][1]);
    }


    function getAddressFromRefSlice() public view returns(string memory) {
        EVMFetcher.newFetchRequest(verifier, target)
            .getStatic(7)
            .getDynamic(8)
                .refSlice(0, 8, 20)
            .fetch(this.getAddressFromRefSliceCallback.selector, "");
    }

    function getAddressFromRefSliceCallback(bytes[][] memory values, bytes memory) public pure returns(string memory) {
        return string(values[0][1]);
    }


    function getValueFromAddressFromRef() public view returns(uint256) {
        EVMFetcher.newFetchRequest(verifier, target)
            .getStatic(7)
            .getStatic(11)
            .setTargetRef(1)
            .getStatic(0)
            .fetch(this.getValueFromAddressFromRefCallback.selector, "");
    }

    function getValueFromAddressFromRefCallback(bytes[][] memory values, bytes memory) public view returns(uint256) {

        console.log("heeeerr");
        console.logBytes(values[1][0]);
        return abi.decode(values[1][0], (uint256));
    }


    function getValueFromAddressFromRefSlice() public view returns(uint256) {
        EVMFetcher.newFetchRequest(verifier, target)
            .getStatic(7)
            .getDynamic(8)
                .refSlice(0, 8, 20)
            .setTargetRef(1)
            .getStatic(0)
            .fetch(this.getValueFromAddressFromRefSliceCallback.selector, "");
    }

    function getValueFromAddressFromRefSliceCallback(bytes[][] memory values, bytes memory) public pure returns(uint256) {
        return abi.decode(values[1][0], (uint256));
    }


    function getHighscorer(uint256 idx) public view returns(string memory) {
        EVMFetcher.newFetchRequest(verifier, target)
            .getDynamic(3)
                .element(idx)
            .fetch(this.getHighscorerCallback.selector, "");
    }

    function getHighscorerCallback(bytes[][] memory values, bytes memory) public pure returns(string memory) {
        return string(values[0][0]);
    }


    function getLatestHighscore() public view returns(uint256) {
        EVMFetcher.newFetchRequest(verifier, target)
            .getStatic(0)
            .getStatic(2)
                .ref(0)
            .fetch(this.getLatestHighscoreCallback.selector, "");
    }

    function getLatestHighscoreCallback(bytes[][] memory values, bytes memory) public pure returns(uint256) {
        return abi.decode(values[0][1], (uint256));
    }

    function getLatestHighscorer() public view returns(string memory) {
        EVMFetcher.newFetchRequest(verifier, target)
            .getStatic(0)
            .getDynamic(3)
                .ref(0)
            .fetch(this.getLatestHighscorerCallback.selector, "");
    }

    function getLatestHighscorerCallback(bytes[][] memory values, bytes memory) public pure returns(string memory) {
        return string(values[0][1]);
    }


    function getNickname(string memory _name) public view returns(string memory) {
        EVMFetcher.newFetchRequest(verifier, target)
            .getDynamic(4)
                .element(_name)
            .fetch(this.getNicknameCallback.selector, "");
    }

    function getNicknameCallback(bytes[][] memory values, bytes memory) public pure returns (string memory) {
        return string(values[0][0]);
    }


    function getPrimaryNickname() public view returns(string memory) {
        EVMFetcher.newFetchRequest(verifier, target)
            .getDynamic(1)
            .getDynamic(4)
                .ref(0)
            .fetch(this.getPrimaryNicknameCallback.selector, "");
    }

    function getPrimaryNicknameCallback(bytes[][] memory values, bytes memory) public pure returns (string memory) {
        return string(values[0][1]);
    }

    function getZero() public view returns(uint256) {
        EVMFetcher.newFetchRequest(verifier, target)
            .getStatic(5)
            .fetch(this.getZeroCallback.selector, "");
    }

    function getZeroCallback(bytes[][] memory values, bytes memory) public pure returns (uint256) {
        return abi.decode(values[0][0], (uint256));
    }


    function getZeroIndex() public view returns(uint256) {
        EVMFetcher.newFetchRequest(verifier, target)
            .getStatic(5)
            .getStatic(2)
                .ref(0)
            .fetch(this.getZeroIndexCallback.selector, "");
    }

    function getZeroIndexCallback(bytes[][] memory values, bytes memory) public pure returns(uint256) {
        return abi.decode(values[0][1], (uint256));
    }
}
