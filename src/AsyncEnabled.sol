// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import {AsyncUtils} from "./AsyncUtils.sol";
import {console} from "forge-std/console.sol";
import {LocalAsyncProxy} from "./LocalAsyncProxy.sol";
import {AsyncCall, AsyncCallback} from "./AsyncUtils.sol";
import {SuperchainEnabled} from "./SuperchainEnabled.sol";
import {AsyncPromise} from "./AsyncPromise.sol";
import { IL2ToL2CrossDomainMessenger } from "@interop/interfaces/IL2ToL2CrossDomainMessenger.sol";
import { PredeployAddresses } from "@interop/libraries/PredeployAddresses.sol";

contract AsyncEnabled is SuperchainEnabled {
    // mapping of address to chainId to remote caller proxy, should probably be private
    mapping(address => mapping(uint256 => LocalAsyncProxy)) public remoteAsyncProxies;

    constructor() {
        console.log("an asyncEnabled contract was just deployed!");
    }

    // gets a remote instance of the contract, creating it if it doesn't exist
    function getAsyncProxy(address _remoteAddress, uint256 _remoteChainId) internal returns (address) {
        if (address(remoteAsyncProxies[_remoteAddress][_remoteChainId]) == address(0)) {
            remoteAsyncProxies[_remoteAddress][_remoteChainId] = new LocalAsyncProxy{salt: bytes32(0)}(_remoteAddress, _remoteChainId);
        }
        return address(remoteAsyncProxies[_remoteAddress][_remoteChainId]);
    }

    function relayAsyncCall(AsyncCall calldata _asyncCall) external {
        // Ensure the crossDomainSender is a valid async proxy for the remote address and chain
        // TODO: other sanity checks on _asyncCall values
        LocalAsyncProxy expectedCrossDomainSender = AsyncUtils.calculateLocalAsyncProxyAddress(
            _asyncCall.from.addr,
            address(this),
            block.chainid
        );
        require(_isValidCrossDomainSender(address(expectedCrossDomainSender)));
        console.log("valid CDM, relaying async call");

        (bool success, bytes memory returndata) = address(this).call(_asyncCall.data);

        console.log("AsyncCallRelayer relayed, success: %s, returndata: ", success);
        console.logBytes(returndata);

        require(success, "Relaying async call failed");

        bytes32 asyncCallId = AsyncUtils.getAsyncCallId(_asyncCall);
        AsyncCallback memory callback = AsyncCallback({
            asyncCallId: asyncCallId,
            success: success,
            returnData: returndata
        });

        bytes memory relayCallbackPayload = abi.encodeWithSelector(
            this.relayAsyncCallback.selector,
            callback
        );

        _xMessageContract(
            _asyncCall.from.chainId,
            _asyncCall.from.addr,
            relayCallbackPayload
        );
    }

    function relayAsyncCallback(AsyncCallback calldata _callback) external {
        console.log("in relayAsyncCallback");

        address crossDomainCallbackSender = IL2ToL2CrossDomainMessenger(PredeployAddresses.L2_TO_L2_CROSS_DOMAIN_MESSENGER).crossDomainMessageSender();
        uint256 crossDomainCallbackSource = IL2ToL2CrossDomainMessenger(PredeployAddresses.L2_TO_L2_CROSS_DOMAIN_MESSENGER).crossDomainMessageSource();
        // TODO

        LocalAsyncProxy remoteProxy = AsyncUtils.calculateLocalAsyncProxyAddress(
            address(this),
            crossDomainCallbackSender,
            crossDomainCallbackSource
        );

        AsyncPromise promiseContract = remoteProxy.promisesById(_callback.asyncCallId);

        require(promiseContract.remoteTarget() == crossDomainCallbackSender, "Invalid promise callback sender");

        bytes4 callbackSelector = promiseContract.callbackSelector();
        (bool success, bytes memory returnData) = address(this).call(
            abi.encodePacked(callbackSelector, _callback.returnData)
        );

        require(success, "Callback execution failed");

        console.log("Callback executed, success: %s, returnData: ", success);
        console.logBytes(returnData);

        promiseContract.markResolved();
    }

    modifier async() {
        // only callable by self via relayAsyncCall
        require(msg.sender == address(this));
        _;
    }

    modifier asyncCallback() {
        // only callable by self via relayAsyncCallback
        require(msg.sender == address(this));
        _;
    }
}
