// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title ICriteriaStakingRegistry
 * @author LooksRare protocol team (👀,💎)
 */
interface ICriteriaStakingRegistry {
    function verifyCollectionOwner(address collection, address sender) external view returns (bool isVerified);
}
