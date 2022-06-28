// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import {OwnableTwoSteps} from "@looksrare/contract-libs/contracts/OwnableTwoSteps.sol";

/**
 * @title CurrencyManager
 * @notice This contract is the contract that manages the whitelist of valid currencies for exchanging NFTs on the exchange.
 * @author LooksRare protocol team (👀,💎)
 */
contract CurrencyManager is OwnableTwoSteps {
    // Custom errors
    error CurrencyAlreadyWhitelisted(address currency);
    error CurrencyNotContract(address currency);
    error CurrencyNotWhitelisted(address currency);

    // Events
    event CurrencyRemoved(address currency);
    event CurrencyWhitelisted(address currency);

    // Whether the currency is whitelisted
    mapping(address => bool) internal _isCurrencyWhitelisted;

    /**
     * @notice Whitelist currency for execution
     * @param currency address of the currency (address(0) for ETH)
     */
    function addCurrency(address currency) external onlyOwner {
        if (currency != address(0) && currency.code.length == 0) {
            revert CurrencyNotContract(currency);
        }

        if (_isCurrencyWhitelisted[currency]) {
            revert CurrencyAlreadyWhitelisted(currency);
        }

        _isCurrencyWhitelisted[currency] = true;
        emit CurrencyWhitelisted(currency);
    }

    /**
     * @notice Remove currency for execution
     * @param currency address of the currency (address(0) for ETH)
     */
    function removeCurrency(address currency) external onlyOwner {
        if (!_isCurrencyWhitelisted[currency]) {
            revert CurrencyNotWhitelisted(currency);
        }

        delete _isCurrencyWhitelisted[currency];
        emit CurrencyRemoved(currency);
    }
}
