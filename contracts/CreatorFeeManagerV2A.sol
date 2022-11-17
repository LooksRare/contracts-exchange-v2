// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Interfaces
import {ICreatorFeeManager} from "./interfaces/ICreatorFeeManager.sol";
import {IRoyaltyFeeRegistry} from "./interfaces/IRoyaltyFeeRegistry.sol";

/**
 * @title CreatorFeeManagerV2A
 */
contract CreatorFeeManagerV2A is ICreatorFeeManager {
    // Standard royalty
    uint256 public constant STANDARD_ROYALTY_FEE_BP = 50;

    // Royalty fee registry
    IRoyaltyFeeRegistry public immutable royaltyFeeRegistry;

    /**
     * @notice Constructor
     * @param _royaltyFeeRegistry Address of the Royalty Fee Registry
     */
    constructor(address _royaltyFeeRegistry) {
        royaltyFeeRegistry = IRoyaltyFeeRegistry(_royaltyFeeRegistry);
    }

    /**
     * @notice View receiver and creator fee
     * @param collection Collection address
     * @param price Trade price
     */
    function viewCreatorFee(
        address collection,
        uint256 price,
        uint256[] memory
    ) external view returns (address receiver, uint256 creatorFee) {
        // Check if there is a royalty info in the system
        (receiver, ) = royaltyFeeRegistry.royaltyInfo(collection, price);

        // A fixed royalty fee is applied
        if (receiver != address(0)) {
            creatorFee = (STANDARD_ROYALTY_FEE_BP * price) / 10000;
        }

        // TODO: implement EIP-2981 support
    }
}
