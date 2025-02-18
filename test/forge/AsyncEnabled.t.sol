// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {AsyncEnabled} from "../../src/AsyncEnabled.sol";
import {LocalAsyncProxy} from "../../src/LocalAsyncProxy.sol";
import {AsyncPromise} from "../../src/AsyncPromise.sol";
import {AsyncUtils, AsyncCall, XAddress} from "../../src/AsyncUtils.sol";

import {MyAsyncEnabled, MyAsyncFunction1Promise} from "./MyAsyncEnabled.sol";

contract AsyncEnabledTest is Test {
    MyAsyncEnabled public asyncContract;

    function setUp() public {
        // Fork supersim state to ensure L2<>L2 CDM predeploy exists
        // It will not function but we need a contract there
        uint256 fork1 = vm.createFork("http://127.0.0.1:9545");
        vm.selectFork(fork1);

        asyncContract = new MyAsyncEnabled();
    }

    function test_spawnRemoteSelf() public {
        uint256 remoteChainId = 420;
        asyncContract.spawnRemoteSelf(remoteChainId);

        LocalAsyncProxy expectedRemoteSelf = AsyncUtils.calculateLocalAsyncProxyAddress(
            address(asyncContract),
            address(asyncContract),
            remoteChainId
        );

        assertEq(
            address(expectedRemoteSelf).codehash,
            keccak256(type(LocalAsyncProxy).runtimeCode)
        );

        XAddress memory remoteProxyTarget = expectedRemoteSelf.getRemoteXAddress();
        assertEq(remoteProxyTarget.addr, address(asyncContract));
        assertEq(remoteProxyTarget.chainId, remoteChainId);
    }

    // TODO: duplicate above test but for non-self address

    function test_makePromise() public {
        vm.skip(true);
        uint256 remoteChainId = 420;
        address myPromise = asyncContract.makeFunc1Promise(remoteChainId);

        AsyncCall memory asyncCall = AsyncCall(
            XAddress(address(asyncContract), block.chainid),    
            XAddress(address(asyncContract), remoteChainId),
            0,
            abi.encodeWithSelector(MyAsyncEnabled.myAsyncFunction1.selector)
        );

        bytes32 expectedMessageId = AsyncUtils.getAsyncCallId(asyncCall);

        bytes32 messageId = AsyncPromise(myPromise).messageId();
        assertEq(messageId, expectedMessageId);
    }

    function test_addCallback() public {
        vm.skip(true);
        uint256 remoteChainId = 420;
        address myPromise = asyncContract.makeFunc1Callback(remoteChainId);

        bytes4 callbackSelector = AsyncPromise(myPromise).callbackSelector();
        // assert callback selector is func1
        assertEq(callbackSelector, bytes4(MyAsyncEnabled.myCallback1.selector));
    }
}

contract AsyncUtilsTest is Test {
    function test_EncodeAsyncCall() public {
        AsyncCall memory asyncCall = AsyncCall(
            XAddress(address(0x123), 1),
            XAddress(address(0x456), 2),
            42,
            "test data"
        );

        bytes memory encoded = AsyncUtils.encodeAsyncCall(asyncCall);
        bytes memory expected = abi.encode(
            address(0x123),
            uint256(1),
            address(0x456),
            uint256(2),
            uint256(42),
            bytes("test data")
        );

        assertEq(encoded, expected, "Encoded data does not match expected value");
    }

    function test_DecodeAsyncCall() public {
        bytes memory data = abi.encode(
            address(0x123),
            uint256(1),
            address(0x456),
            uint256(2),
            uint256(42),
            bytes("test data")
        );

        AsyncCall memory asyncCall = AsyncUtils.decodeAsyncCall(data);

        assertEq(asyncCall.from.addr, address(0x123), "From address does not match");
        assertEq(asyncCall.from.chainId, 1, "From chainId does not match");
        assertEq(asyncCall.to.addr, address(0x456), "To address does not match");
        assertEq(asyncCall.to.chainId, 2, "To chainId does not match");
        assertEq(asyncCall.nonce, 42, "Nonce does not match");
        assertEq(asyncCall.data, bytes("test data"), "Data does not match");
    }

    function test_GetAsyncCallId() public {
        AsyncCall memory asyncCall = AsyncCall(
            XAddress(address(0x123), 1),
            XAddress(address(0x456), 2),
            42,
            "test data"
        );

        bytes32 id = AsyncUtils.getAsyncCallId(asyncCall);
        bytes32 expectedId = keccak256(abi.encode(
            address(0x123),
            uint256(1),
            address(0x456),
            uint256(2),
            uint256(42),
            bytes("test data")
        ));

        assertEq(id, expectedId, "AsyncCall ID does not match expected value");
    }
}