pragma solidity ^0.8.13;

// SuperchainEnabled provides utilities for cross-chain event validation,
// sending messages, and receiving messages with modifiers.

import { IL2ToL2CrossDomainMessenger } from "@interop/interfaces/IL2ToL2CrossDomainMessenger.sol";
import { PredeployAddresses } from "@interop/libraries/PredeployAddresses.sol";

abstract contract SuperchainEnabled {
    // Error definitions
    error CallerNotL2ToL2CrossDomainMessenger();
    error InvalidCrossDomainSender();
    error InvalidSourceChain();
    error AlreadyOnDestinationChain();

    /// @notice Sends a cross-chain message to a destination address on another chain
    /// @param destChainId The chain ID of the destination chain
    /// @param destAddress The address of the destination contract
    /// @param data The calldata to send to the destination contract
    function _xMessageContract(
        uint256 destChainId,
        address destAddress,
        bytes memory data
    ) internal {
        IL2ToL2CrossDomainMessenger(PredeployAddresses.L2_TO_L2_CROSS_DOMAIN_MESSENGER).sendMessage(
            destChainId,
            destAddress,
            data
        );
    }

    /// @notice Sends a cross-chain message to this contract on another chain
    /// @param destChainId The chain ID of the destination chain
    /// @param data The calldata to send to this contract on the destination chain
    function _xMessageSelf(
        uint256 destChainId,
        bytes memory data
    ) internal {
        if (destChainId == block.chainid) {
            revert AlreadyOnDestinationChain();
        }
        _xMessageContract(destChainId, address(this), data);
    }

    /// @notice Checks if the cross-domain message is from the expected source
    /// @param expectedSource The expected source address
    /// @return bool True if the message is from the expected source, false otherwise
    function _isValidCrossDomainSender(address expectedSource) internal view returns (bool) {
        if (msg.sender != PredeployAddresses.L2_TO_L2_CROSS_DOMAIN_MESSENGER) {
            return false;
        }
        return IL2ToL2CrossDomainMessenger(PredeployAddresses.L2_TO_L2_CROSS_DOMAIN_MESSENGER).crossDomainMessageSender() == expectedSource;
    }

    /// @notice Modifier to validate messages from a specific address
    /// @param expectedSource The expected source address
    modifier xOnlyFromAddress(address expectedSource) {
        if (!_isValidCrossDomainSender(expectedSource)) {
            revert InvalidCrossDomainSender();
        }
        _;
    }

    /// @notice Modifier to validate messages from this contract itself
    modifier xOnlyFromSelf() {
        if (!_isValidCrossDomainSender(address(this))) {
            revert InvalidCrossDomainSender();
        }
        _;
    }

    /// @notice Modifier to validate messages from a specific address on a specific chain
    /// @param expectedSource The expected source address
    /// @param expectedChainId The expected source chain ID
    modifier xOnlyFromContract(address expectedSource, uint256 expectedChainId) {
        if (msg.sender != PredeployAddresses.L2_TO_L2_CROSS_DOMAIN_MESSENGER) {
            revert CallerNotL2ToL2CrossDomainMessenger();
        }
        if (IL2ToL2CrossDomainMessenger(PredeployAddresses.L2_TO_L2_CROSS_DOMAIN_MESSENGER).crossDomainMessageSender() != expectedSource) {
            revert InvalidCrossDomainSender();
        }
        if (IL2ToL2CrossDomainMessenger(PredeployAddresses.L2_TO_L2_CROSS_DOMAIN_MESSENGER).crossDomainMessageSource() != expectedChainId) {
            revert InvalidSourceChain();
        }
        _;
    }
}
