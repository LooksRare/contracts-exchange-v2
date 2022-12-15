// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title IRoyaltyFeeRegistry
 * @author LooksRare protocol team (👀,💎)
 */
interface IRoyaltyFeeRegistry {
    function royaltyInfo(
        address collection,
        uint256 price
    ) external view returns (address receiver, uint256 royaltyFee);
}
