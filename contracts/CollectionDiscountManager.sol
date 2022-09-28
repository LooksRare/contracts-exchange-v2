// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import {OwnableTwoSteps} from "@looksrare/contracts-libs/contracts/OwnableTwoSteps.sol";
import {ICollectionDiscountManager} from "./interfaces/ICollectionDiscountManager.sol";

/**
 * @title CollectionDiscountManager
 * @notice This contract handles the set up of protocol fee discounts for collection addresses.
 * @author LooksRare protocol team (👀,💎)
 */
contract CollectionDiscountManager is ICollectionDiscountManager, OwnableTwoSteps {
    // Address of the referral controller
    address public collectionDiscountController;

    // Track collection discount factors (e.g., 100 = 1%, 5,000 = 50%) relative to strategy fee
    mapping(address => uint256) internal _collectionDiscountFactors;

    // Modifier for collection discount controller
    modifier onlyCollectionDiscountController() {
        if (msg.sender != collectionDiscountController) revert NotCollectionDiscountController();
        _;
    }

    /**
     * @notice Add custom discount for collection
     * @param collection Collection address
     * @param discountFactor Discount factor (e.g., 1000 = -10% relative to the protocol fee)
     */
    function adjustDiscountFactorCollection(address collection, uint256 discountFactor)
        external
        onlyCollectionDiscountController
    {
        if (discountFactor > 10000) revert CollectionDiscountFactorTooHigh();

        if (discountFactor != 0) {
            _collectionDiscountFactors[collection] = discountFactor;
        } else {
            delete _collectionDiscountFactors[collection];
        }

        emit NewCollectionDiscountFactor(collection, discountFactor);
    }

    /**
     * @notice Update collection discount controller
     * @param newCollectionDiscountController New collection discount controller address
     */
    function updateCollectionDiscountController(address newCollectionDiscountController) external onlyOwner {
        collectionDiscountController = newCollectionDiscountController;
        emit NewCollectionDiscountController(newCollectionDiscountController);
    }

    /**
     * @notice View collection discount factor
     * @param collection Collection address
     * @return collectionDiscountFactor Collection discount factor (e.g., 500 --> 5% relative to protocol fee)
     */
    function viewCollectionDiscountFactor(address collection) external view returns (uint256 collectionDiscountFactor) {
        return _collectionDiscountFactors[collection];
    }
}
