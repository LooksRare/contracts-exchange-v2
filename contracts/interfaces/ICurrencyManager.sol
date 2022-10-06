// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

/**
 * @title ICurrencyManager
 * @author LooksRare protocol team (👀,💎)
 */
interface ICurrencyManager {
    // Custom errors
    error CurrencyAlreadyWhitelisted(address currency);
    error CurrencyNotContract(address currency);
    error CurrencyNotWhitelisted(address currency);

    // Events
    event CurrencyRemoved(address currency);
    event CurrencyWhitelisted(address currency);
}
