//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { IEVMVerifier } from './IEVMVerifier.sol';
import { Address } from '@openzeppelin/contracts/utils/Address.sol';

import "./console.sol";

/**
 * @dev Callback implementation for users of `EVMFetcher`. If you use `EVMFetcher`, your contract must
 *      inherit from this contract in order to handle callbacks correctly.
 */
abstract contract EVMFetchTarget {
    using Address for address;

    error ResponseLengthMismatch(uint256 actual, uint256 expected);
error Oops(uint8);
error Resp(bytes);
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

//revert Resp(proofsDataBytes);

//revert Oops(uint8(3));
        (IEVMVerifier verifier, address[] memory targets, bytes32[] memory commands, bytes[] memory constants, bytes4 callback, bytes memory callbackData) =
            abi.decode(extradata, (IEVMVerifier, address[], bytes32[], bytes[], bytes4, bytes));

            console.log("QQ1");
        bytes[][] memory values = verifier.getStorageValues(targets, commands, constants, proofsData);
            console.log("QQ2");

                //revert Oops(uint8(3));

    console.log("val length");
    console.log(values.length);

    console.log("commands length");
    console.log(commands.length);

        if(values.length != commands.length) {
            //This should move to helper and be renamed. as values in an array indexed by target so 2 commands, 1 target = 1 value key with 2 nested values
            //revert ResponseLengthMismatch(values.length, commands.length);
        }

        console.log("LAA");
        //console.logBytes(values[1][0]);
        //console.logBytes(values[1][0]);
        bytes memory ret = address(this).functionCall(abi.encodeWithSelector(callback, values, callbackData));
        

                console.log("ret");
        console.logBytes(ret);
        //revert Oops(uint8(1));

        bytes[] memory rets = new bytes[](2);

        console.logBytes(values[0][0]);

        //return ret;

        console.log(ret.length);

        assembly {
            return(add(ret, 32), mload(ret))
        }
    }
}
