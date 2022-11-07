// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IRoyaltyFeeRegistry
 * @notice This interface is used for the logic used to determine the collection owner for the CollectionStakingRegistry.
 * @author LooksRare protocol team (👀,💎)
 */
interface IRoyaltyFeeRegistry {
    function royaltyFeeInfoCollection(address collection)
        external
        view
        returns (
            address,
            address,
            uint256
        );
}
