// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title IFeeManager
 * @author LooksRare protocol team (👀,💎)
 */
interface IFeeManager {
    // Custom errors
    error BundleEIP2981NotAllowed(address collection, uint256[] itemIds);

    // Events
    event NewProtocolFeeRecipient(address protocolFeeRecipient);
    event NewRoyaltyFeeRegistry(address royaltyFeeRegistry);
}
