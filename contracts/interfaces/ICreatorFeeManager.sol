// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IRoyaltyFeeRegistry} from "./IRoyaltyFeeRegistry.sol";

/**
 * @title ICreatorFeeManager
 * @author LooksRare protocol team (👀,💎)
 */
interface ICreatorFeeManager {
    error BundleEIP2981NotAllowed(address collection);

    function royaltyFeeRegistry() external view returns (IRoyaltyFeeRegistry);

    /**
     * @notice View creator address and calculate creator fee
     * @param collection Collection address
     * @param price Trade price
     * @param itemIds Array of item ids
     * @return creator Creator address
     * @return creatorFeeBp Creator fee (in basis point)
     */
    function viewCreatorFeeInfo(
        address collection,
        uint256 price,
        uint256[] memory itemIds
    ) external view returns (address creator, uint256 creatorFeeBp);
}
