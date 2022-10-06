// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title ICollectionDiscountManager
 * @author LooksRare protocol team (👀,💎)
 */
interface ICollectionDiscountManager {
    // Custom errors
    error CollectionDiscountFactorTooHigh();
    error NotCollectionDiscountController();

    // Events
    event NewCollectionDiscountController(address collectionDiscountController);
    event NewCollectionDiscountFactor(address collection, uint16 discountFactor);
}
