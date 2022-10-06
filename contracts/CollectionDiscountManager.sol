// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// LooksRare unopinionated libraries
import {OwnableTwoSteps} from "@looksrare/contracts-libs/contracts/OwnableTwoSteps.sol";

// Interfaces
import {ICollectionDiscountManager} from "./interfaces/ICollectionDiscountManager.sol";

/**
 * @title CollectionDiscountManager
 * @notice This contract handles the set up of protocol fee discounts for collection addresses.
 * @author LooksRare protocol team (👀,💎)
 */
contract CollectionDiscountManager is ICollectionDiscountManager, OwnableTwoSteps {
    // Address of the referral controller
    address public collectionDiscountController;

    // Check the collection discount factor (e.g., 100 = 1%, 5,000 = 50%) relative to strategy fee
    mapping(address => uint16) public collectionDiscountFactor;

    /**
     * @notice Update discount factor for a collection address
     * @param collection Collection address
     * @param discountFactor Discount factor (e.g., 1000 = -10% relative to the protocol fee)
     */
    function updateCollectionDiscountFactor(address collection, uint16 discountFactor) external {
        if (msg.sender != collectionDiscountController) revert NotCollectionDiscountController();
        if (discountFactor > 10000) revert CollectionDiscountFactorTooHigh();

        if (discountFactor != 0) {
            collectionDiscountFactor[collection] = discountFactor;
        } else {
            delete collectionDiscountFactor[collection];
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
}
