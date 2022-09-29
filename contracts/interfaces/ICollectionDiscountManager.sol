// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

interface ICollectionDiscountManager {
    // Custom errors
    error CollectionDiscountFactorTooHigh();
    error NotCollectionDiscountController();

    // Events
    event NewCollectionDiscountController(address collectionDiscountController);
    event NewCollectionDiscountFactor(address collection, uint256 discountFactor);
}
