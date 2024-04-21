//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { IEVMVerifier } from './IEVMVerifier.sol';
import { EVMFetchTarget } from './EVMFetchTarget.sol';
import { Address } from '@openzeppelin/contracts/utils/Address.sol';
import './console.sol';

interface IEVMGateway {
    function getStorageSlots(bytes32[] memory commands, bytes[] memory constants) external view returns(bytes memory witness);
}

uint8 constant TOP_CONSTANT = 0x00;   //00000000
uint8 constant TOP_BACKREF = 0x20;    //


uint8 constant FLAG_STATIC = 0x01;
uint8 constant FLAG_DYNAMIC = 0x01;
uint8 constant FLAG_SLICE = 0x01;
uint8 constant OP_CONSTANT = 0x00;
uint8 constant OP_BACKREF = 0x20;
uint8 constant OP_SLICE = 0x40;
uint8 constant OP_SETADDR = 0x60;
uint8 constant OP_IVALUE = 0x80;

uint8 constant OP_POSTPROCESS = 0xfe;
uint8 constant OP_END = 0xff;


//80, a0, c0, e0

/**
 * @dev A library to facilitate requesting storage data proofs from contracts, possibly on a different chain.
 *      See l1-verifier/test/TestL1.sol for example usage.
 */
library EVMFetcher {
    uint256 constant MAX_COMMANDS = 32;
    uint256 constant MAX_CONSTANTS = 32; // Must not be greater than 32

    using Address for address;

    error TooManyCommands(uint256 max);
    error CommandTooLong();
    error InvalidReference(uint256 value, uint256 max);
    error OffchainLookup(address sender, string[] urls, bytes callData, bytes4 callbackFunction, bytes extraData);

    struct EVMFetchRequest {
        IEVMVerifier verifier;
        uint8 currentTargetIndex;
        uint8 currentTargetByte;
        bytes32[] commands;
        uint256 operationIdx;
        bytes[] constants;
    }

    /**
     * @dev Creates a request to fetch the value of multiple storage slots from a contract via CCIP-Read, possibly from
     *      another chain.
     *      Supports dynamic length values and slot numbers derived from other retrieved values.
     * @param verifier An instance of a verifier contract that can provide and verify the storage slot information.
     * @param target The address of the contract to fetch storage proofs for.
     */
    function newFetchRequest(IEVMVerifier verifier, address target) internal view returns (EVMFetchRequest memory) {
        bytes32[] memory commands = new bytes32[](MAX_COMMANDS);
        bytes[] memory constants = new bytes[](MAX_CONSTANTS);
        assembly {
            mstore(commands, 0) // Set current array length to 0
            mstore(constants, 1)
        }        
        constants[0] = abi.encodePacked(target);
        return EVMFetchRequest(verifier, 0, 0, commands, 0, constants);
    }


    /**
     * @dev Starts describing a new fetch request.
     *      Paths specify a series of hashing operations to derive the final slot ID.
     *      See https://docs.soliditylang.org/en/v0.8.17/internals/layout_in_storage.html for details on how Solidity
     *      lays out storage variables.
     * @param request The request object being operated on.
     * @param baseSlot The base slot ID that forms the root of the path.
     */
    function getStatic(EVMFetchRequest memory request, uint256 baseSlot) internal view returns (EVMFetchRequest memory) {

        console.log("getStatic");

        bytes32[] memory commands = request.commands;
        uint256 commandIdx = commands.length;
        if(commandIdx > 0 && request.operationIdx < 32) {
            // Terminate previous command
                    console.log("term 1");

            _addOperation(request, OP_END);

            console.logBytes32(request.commands[0]);
        }
        assembly {
            mstore(commands, add(commandIdx, 1)) // Increment command array length
        }
        if(request.commands.length > MAX_COMMANDS) {
            revert TooManyCommands(MAX_COMMANDS);
        }

        request.operationIdx = 0;
                console.log("1");


        //_addOperation(request, T_CONSTANT | request.currentTargetIndex);
        _addOperation(request, request.currentTargetByte);

                console.log("2");

        _addOperation(request, 0);
                console.log("3");

        _addOperation(request, _addConstant(request, abi.encode(baseSlot)));
        return request;
    }




    /**
     * @dev Starts describing a new fetch request.
     *      Paths specify a series of hashing operations to derive the final slot ID.
     *      See https://docs.soliditylang.org/en/v0.8.17/internals/layout_in_storage.html for details on how Solidity
     *      lays out storage variables.
     * @param request The request object being operated on.
     * @param baseSlot The base slot ID that forms the root of the path.
     */
    function getDynamic(EVMFetchRequest memory request, uint256 baseSlot) internal view returns (EVMFetchRequest memory) {

        console.log("getDynamic");

        bytes32[] memory commands = request.commands;
        uint256 commandIdx = commands.length;
        if(commandIdx > 0 && request.operationIdx < 32) {
            // Terminate previous command

                    console.log("term");

            _addOperation(request, OP_END);
        }
        assembly {
            mstore(commands, add(commandIdx, 1)) // Increment command array length
        }
        if(request.commands.length > MAX_COMMANDS) {
            revert TooManyCommands(MAX_COMMANDS);
        }

        request.operationIdx = 0;
                console.log("a");

        _addOperation(request, request.currentTargetByte);
        //_addOperation(request, T_CONSTANT | request.currentTargetIndex);
                console.log("b");

        _addOperation(request, FLAG_DYNAMIC);
        console.log("---");
        _addOperation(request, _addConstant(request, abi.encode(baseSlot)));
        return request;
    }



    /**
     * @dev Adds a `uint256` element to the current path.
     * @param request The request object being operated on.
     * @param el The element to add.
     */
    function element(EVMFetchRequest memory request, uint256 el) internal view returns (EVMFetchRequest memory) {
        if(request.operationIdx >= 32) {
            revert CommandTooLong();
        }
                console.log("element e");

        _addOperation(request, _addConstant(request, abi.encode(el)));
        return request;
    }

    /**
     * @dev Adds a `bytes32` element to the current path.
     * @param request The request object being operated on.
     * @param el The element to add.
     */
    function element(EVMFetchRequest memory request, bytes32 el) internal view returns (EVMFetchRequest memory) {
        if(request.operationIdx >= 32) {
            revert CommandTooLong();
        }
                console.log("element d");

        _addOperation(request, _addConstant(request, abi.encode(el)));
        return request;
    }

    /**
     * @dev Adds an `address` element to the current path.
     * @param request The request object being operated on.
     * @param el The element to add.
     */
    function element(EVMFetchRequest memory request, address el) internal view returns (EVMFetchRequest memory) {
        if(request.operationIdx >= 32) {
            revert CommandTooLong();
        }
                console.log("element c");

        _addOperation(request, _addConstant(request, abi.encode(el)));
        return request;
    }

    /**
     * @dev Adds a `bytes` element to the current path.
     * @param request The request object being operated on.
     * @param el The element to add.
     */
    function element(EVMFetchRequest memory request, bytes memory el) internal view returns (EVMFetchRequest memory) {
        if(request.operationIdx >= 32) {
            revert CommandTooLong();
        }
                console.log("element b");

        _addOperation(request, _addConstant(request, el));
        return request;
    }

    /**
     * @dev Adds a `string` element to the current path.
     * @param request The request object being operated on.
     * @param el The element to add.
     */
    function element(EVMFetchRequest memory request, string memory el) internal view returns (EVMFetchRequest memory) {
        if(request.operationIdx >= 32) {
            revert CommandTooLong();
        }
        console.log("element");
        _addOperation(request, _addConstant(request, bytes(el)));
        return request;
    }

    /**
     * @dev Adds a reference to a previous fetch to the current path.
     * @param request The request object being operated on.
     * @param idx The index of the previous fetch request, starting at 0.
     */
    function ref(EVMFetchRequest memory request, uint8 idx) internal view returns (EVMFetchRequest memory) {
        if(request.operationIdx >= 32) {
            revert CommandTooLong();
        }
        if(idx > request.commands.length || idx > 31) {
            revert InvalidReference(idx, request.commands.length);
        }
        console.log("ref");
        _addOperation(request, OP_BACKREF | idx);
        return request;
    }


    /**
     * @dev Adds a reference to a previous fetch to the current path.
     * @param request The request object being operated on.
     * @param idx The index of the previous fetch request, starting at 0.
     */
    function pref(EVMFetchRequest memory request, uint8 idx) internal view returns (EVMFetchRequest memory) {
        if(request.operationIdx >= 32) {
            revert CommandTooLong();
        }
        if(idx > request.commands.length || idx > 31) {
            revert InvalidReference(idx, request.commands.length);
        }
        console.log("ref");
        _addOperation(request, OP_IVALUE | idx);
        return request;
    }


    function refSlice(EVMFetchRequest memory request, uint8 idx, uint8 offset, uint8 length) internal view returns (EVMFetchRequest memory) {
        if(request.operationIdx >= 32) {
            revert CommandTooLong();
        }
        if(idx > request.commands.length || idx > 31) {
            revert InvalidReference(idx, request.commands.length);
        }
        console.log("..pack");

        _addOperation(request, OP_POSTPROCESS);

        bytes memory pack = abi.encodePacked(offset, length);
        console.logBytes(pack);
        console.log(OP_SLICE | 2);
        _addOperation(request, OP_SLICE | _addConstant(request, abi.encodePacked(offset, length)));
        console.log(".-.");
        return request;
    }



    function setTarget(EVMFetchRequest memory request, address newTarget) internal view returns (EVMFetchRequest memory) {
        
        //request.operationIdx = 0;

        request.currentTargetIndex = _addConstant(request, abi.encodePacked(newTarget));
        //_addOperation(request, T_CONSTANT | request.currentTargetIndex);

        return request;
    }




    function setTargetRef(EVMFetchRequest memory request, uint8 idx) internal view returns (EVMFetchRequest memory) {
        
        request.currentTargetByte = TOP_BACKREF | idx;

        console.log("byteis",request.currentTargetByte);

        return request;
    }

    /**
     * @dev Initiates the fetch request.
     *      Calling this function terminates execution; clients that implement CCIP-Read will make a callback to
     *      `callback` with the results of the operation.
     * @param callbackId A callback function selector on this contract that will be invoked via CCIP-Read with the result of the lookup.
     *        The function must have a signature matching `(bytes[] memory values, bytes callbackData)` with a return type matching the call in which
     *        this function was invoked. Its return data will be returned as the return value of the entire CCIP-read operation.
     * @param callbackData Extra data to supply to the callback.
     */
    function fetch(EVMFetchRequest memory request, bytes4 callbackId, bytes memory callbackData) internal view {
        if(request.commands.length > 0 && request.operationIdx < 32) {
            // Terminate last command
            console.log("last");
            _addOperation(request, OP_END);
        }

        console.log("clen", request.commands.length);
        //console.logBytes32(request.commands[0]);
        //console.logBytes32(request.commands[1]);
        revert OffchainLookup(
            address(this),
            request.verifier.gatewayURLs(),
            abi.encodeCall(IEVMGateway.getStorageSlots, (request.commands, request.constants)),
            EVMFetchTarget.getStorageSlotsCallback.selector,
            abi.encode(request.verifier, request.commands, request.constants, callbackId, callbackData)
        );
    }

    function _addConstant(EVMFetchRequest memory request, bytes memory value) private view returns(uint8 idx) {
        bytes[] memory constants = request.constants;
        idx = uint8(constants.length);
        assembly {
            mstore(constants, add(idx, 1)) // Increment constant array length
        }
        console.log(idx);
        constants[idx] = value;
    }

    function _addOperation(EVMFetchRequest memory request, uint8 op) private view {
        uint256 commandIdx = request.commands.length - 1;
        console.log("operation");
        console.log(op);
        console.log("-operation-");

        request.commands[commandIdx] = request.commands[commandIdx] | (bytes32(bytes1(op)) >> (8 * request.operationIdx++));
    }
}
