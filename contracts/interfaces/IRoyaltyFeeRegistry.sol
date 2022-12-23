// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title IRoyaltyFeeRegistry
 * @author LooksRare protocol team (👀,💎)
 */
interface IRoyaltyFeeRegistry {
    /**
     * @notice View royalty info
     * @param collection Collection address
     * @param price Price of the transaction
     * @return receiver Receiver address
     * @return royaltyFee Royalty fee
     */
    function royaltyInfo(
        address collection,
        uint256 price
    ) external view returns (address receiver, uint256 royaltyFee);
}
