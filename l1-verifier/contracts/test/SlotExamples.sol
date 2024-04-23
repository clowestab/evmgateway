// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { EVMFetcher } from '@ensdomains/evm-verifier/contracts/EVMFetcher.sol';
import { EVMFetchTarget } from '@ensdomains/evm-verifier/contracts/EVMFetchTarget.sol';
import { IEVMVerifier } from '@ensdomains/evm-verifier/contracts/IEVMVerifier.sol';

import "../console.sol";


contract SlotExamples is EVMFetchTarget {
    using EVMFetcher for EVMFetcher.EVMFetchRequest;

    IEVMVerifier verifier;
    address target;

    constructor(IEVMVerifier _verifier, address _target) {
        verifier = _verifier;
        target = _target;
    }
    
    //Test a static uint256 in a storage slot
    function getLatest() public view returns(uint256) {
        EVMFetcher.newFetchRequest(verifier, target)
            .getStatic(0)
            .fetch(this.getLatestCallback.selector, "");
    }

    function getLatestCallback(bytes[][] memory values, bytes memory) public pure returns(uint256) {
        return abi.decode(values[0][0], (uint256));
    }

    //Get a uint256 from a static storage slot on two separate target contracts
    function getLatestFromTwo(address secondTarget) public view returns(bytes[][] memory) {
        EVMFetcher.newFetchRequest(verifier, target)
            .getStatic(0)
            .setTarget(secondTarget)
            .getStatic(0)
            .fetch(this.getLatestFromTwoCallback.selector, "");
    }

    function getLatestFromTwoCallback(bytes[][] memory values, bytes memory) public pure returns(bytes[][] memory) {
        return values;
    }
    
    //Get a dynamic string from a storage slot
    function getName() public view returns(string memory) {
        EVMFetcher.newFetchRequest(verifier, target)
            .getDynamic(1)
            .fetch(this.getNameCallback.selector, "");
    }

    function getNameCallback(bytes[][] memory values, bytes memory) public view returns(string memory) {
        return string(values[0][0]);
    }

    //Get dynamic strings from two different storage slots on the same target contract
    function getNameTwice() public view returns(string[] memory) {
        EVMFetcher.newFetchRequest(verifier, target)
            .getDynamic(1)
            .getDynamic(9)
            .fetch(this.getNameTwiceCallback.selector, "");
    }

    function getNameTwiceCallback(bytes[][] memory values, bytes memory) public view returns(string[] memory) {

        string[] memory strings = new string[](2);
        strings[0] = string(values[0][0]);
        strings[1] = string(values[0][1]);
        
        return strings;
    }
    

    //Get a string from a storage slot and then a string from a mapping on the same target contract
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


    //Get a static bytes, extract a slice of it, use that as the key for getting a dynamic string from a mapping keyed on uint256
    function getHighscorerFromRefSlice() public view returns(string memory) {
        EVMFetcher.newFetchRequest(verifier, target)
            .getStatic(6)
                .refSlice(0, 2, 1)
            .getDynamic(3)
                .iref(0)
            .fetch(this.getHighscorerFromRefSliceCallback.selector, "");
    }

    function getHighscorerFromRefSliceCallback(bytes[][] memory values, bytes memory) public view returns(string memory) {
        string memory answer = string(values[0][1]);
        return string(values[0][1]);
    }


    //Get bytes from a slot
    function getPaddedAddress() public view returns(bytes memory) {
        EVMFetcher.newFetchRequest(verifier, target)
            .getStatic(7)
            .fetch(this.getPaddedAddressCallback.selector, "");
    }

    function getPaddedAddressCallback(bytes[][] memory values, bytes memory) public pure returns(bytes memory) {
        return values[0][0];
    }


    //Get bytes, slice out address, use address as key to get dynamic string from mapping keyed on address
    function getStringBytesUsingAddressSlicedFromBytes() public view returns(bytes memory) {
        EVMFetcher.newFetchRequest(verifier, target)
            .getStatic(7)
                .refSlice(0, 8, 20)
            .getDynamic(8)
                .iref(0)
            .fetch(this.getStringBytesUsingAddressSlicedFromBytesCallback.selector, "");
    }

    function getStringBytesUsingAddressSlicedFromBytesCallback(bytes[][] memory values, bytes memory) public view returns(bytes memory) {
        return values[0][1];
    }


    //Get an address from a slot, use it as the target from which to get a static uint256
    function getValueFromAddressFromRef() public view returns(uint256) {
        EVMFetcher.newFetchRequest(verifier, target)
            .getStatic(11)
            .setTargetRef(0)
            .getStatic(0)
            .fetch(this.getValueFromAddressFromRefCallback.selector, "");
    }

    function getValueFromAddressFromRefCallback(bytes[][] memory values, bytes memory) public view returns(uint256) {
        return abi.decode(values[1][0], (uint256));
    }


    //Get bytes, slice out address, use the sliced address as the target to get a static uint256 from a slot
    function getValueFromAddressFromRefSlice() public view returns(uint256) {
        EVMFetcher.newFetchRequest(verifier, target)
            .getStatic(7) //gets a padded address values[0][0]
                .refSlice(0, 8, 20) //slices the address out to an internal value
            .setTargetIref(0)
            .getStatic(0)
            .fetch(this.getValueFromAddressFromRefSliceCallback.selector, "");
    }

    function getValueFromAddressFromRefSliceCallback(bytes[][] memory values, bytes memory) public pure returns(uint256) {
        return abi.decode(values[1][0], (uint256));
    }


    //Get a dynamic string from a mapping keyed on uint256
    function getHighscorer(uint256 idx) public view returns(string memory) {
        EVMFetcher.newFetchRequest(verifier, target)
            .getDynamic(3)
                .element(idx)
            .fetch(this.getHighscorerCallback.selector, "");
    }

    function getHighscorerCallback(bytes[][] memory values, bytes memory) public pure returns(string memory) {
        return string(values[0][0]);
    }

    //Get a uint256 from a mapping keyed on uint256 that is pulled from a static storage slot
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


    //Get a string from a mapping keyed on uint256 that is pulled from a static storage slot
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


    //Get a string from a mapping keyed on string
    function getNickname(string memory _name) public view returns(string memory) {
        EVMFetcher.newFetchRequest(verifier, target)
            .getDynamic(4)
                .element(_name)
            .fetch(this.getNicknameCallback.selector, "");
    }

    function getNicknameCallback(bytes[][] memory values, bytes memory) public pure returns (string memory) {
        return string(values[0][0]);
    }


    //Get a dynamic string, then use it as the key for getting another string from a mapping keyed on string
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


    //Gets a 0 from an unitialized uint256 slot
    function getZero() public view returns(uint256) {
        EVMFetcher.newFetchRequest(verifier, target)
            .getStatic(5)
            .fetch(this.getZeroCallback.selector, "");
    }

    function getZeroCallback(bytes[][] memory values, bytes memory) public pure returns (uint256) {
        return abi.decode(values[0][0], (uint256));
    }


    //Get the 0 and use it as an index for getting a uint256 from a mapping keyed on uint256
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


    //TOM playing
    function memoryArrays(bytes[] memory input) public view returns (bytes[] memory output){
        
        console.log("Input length", input.length);
        console.log("Output length", output.length);

        assembly {
            mstore(output, 2)
        }

        output[1] = "0x00";

        console.log("Output length2", output.length);
    }
}
