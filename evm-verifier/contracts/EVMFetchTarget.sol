//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { IEVMVerifier } from './IEVMVerifier.sol';
import { Address } from '@openzeppelin/contracts/utils/Address.sol';

/**
 * @dev Callback implementation for users of `EVMFetcher`. If you use `EVMFetcher`, your contract must
 *      inherit from this contract in order to handle callbacks correctly.
 */
abstract contract EVMFetchTarget {
    using Address for address;

    error ResponseLengthMismatch(uint256 actual, uint256 expected);
    
    /**
     * @dev Internal callback function invoked by CCIP-Read in response to a `getStorageSlots` request.
     */
    function getStorageSlotsCallback(bytes calldata response, bytes calldata extradata) external {

        //bytes memory proofsDataBytes = abi.decode(response, (bytes));
        bytes[] memory proofsData = abi.decode(response, (bytes[]));

        //so we have an array of proofs which are of the form
        //[
        //'tuple(uint256 blockNo, bytes blockHeader)',
        //'tuple(bytes[] stateTrieWitness, bytes[][] storageProofs)',
        //]

        (IEVMVerifier verifier, bytes32[] memory commands, bytes[] memory constants, bytes4 callback, bytes memory callbackData) =
            abi.decode(extradata, (IEVMVerifier, bytes32[], bytes[], bytes4, bytes));

        bytes[][] memory values = verifier.getStorageValues(commands, constants, proofsData);

        if(values.length != commands.length) {
            //This should move to helper and be renamed. as values in an array indexed by target so 2 commands, 1 target = 1 value key with 2 nested values
            //revert ResponseLengthMismatch(values.length, commands.length);
        }

        bytes memory ret = address(this).functionCall(abi.encodeWithSelector(callback, values, callbackData));

        bytes[] memory rets = new bytes[](2);

        assembly {
            return(add(ret, 32), mload(ret))
        }
    }
}
