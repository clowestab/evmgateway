// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { EVMFetcher } from '@ensdomains/evm-verifier/contracts/EVMFetcher.sol';
import { EVMFetchTarget } from '@ensdomains/evm-verifier/contracts/EVMFetchTarget.sol';
import { IEVMVerifier } from '@ensdomains/evm-verifier/contracts/IEVMVerifier.sol';

contract SlotExamples is EVMFetchTarget {
    using EVMFetcher for EVMFetcher.EVMFetchRequest;

    IEVMVerifier verifier;                  // Slot 0
    address target;

    constructor(IEVMVerifier _verifier, address _target) {
        verifier = _verifier;
        target = _target;
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
}
