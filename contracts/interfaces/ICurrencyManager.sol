// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title ICurrencyManager
 * @author LooksRare protocol team (👀,💎)
 */
interface ICurrencyManager {
    // Events
    event CurrencyWhitelistStatusUpdated(address currency, bool isWhitelisted);
}
