// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title ICriteriaStakingRegistry
 * @author LooksRare protocol team (👀,💎)
 */
interface ICriteriaStakingRegistry {
    error NotRoyaltyFeeSetterInRegistry(); // If the royalty fee setter is set in the original registry, it is impossible to claim ownership otherwise

    function verifyCollectionOwner(address collection, address sender) external view returns (bool isVerified);
}
