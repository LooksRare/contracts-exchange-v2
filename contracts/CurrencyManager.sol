// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

// LooksRare unopinionated libraries
import {OwnableTwoSteps} from "@looksrare/contracts-libs/contracts/OwnableTwoSteps.sol";

// Interfaces
import {ICurrencyManager} from "./interfaces/ICurrencyManager.sol";

/**
 * @title CurrencyManager
 * @notice This contract manages the whitelist of valid currencies for exchanging NFTs on the exchange.
 * @author LooksRare protocol team (👀,💎)
 */
contract CurrencyManager is ICurrencyManager, OwnableTwoSteps {
    // Check whether the currency is whitelisted
    mapping(address => bool) public isCurrencyWhitelisted;

    /**
     * @notice Whitelist currency for execution
     * @param currency Currency address (address(0) for ETH)
     */
    function addCurrency(address currency) external onlyOwner {
        if (currency != address(0) && currency.code.length == 0) revert CurrencyNotContract(currency);
        if (isCurrencyWhitelisted[currency]) revert CurrencyAlreadyWhitelisted(currency);

        isCurrencyWhitelisted[currency] = true;
        emit CurrencyWhitelisted(currency);
    }

    /**
     * @notice Remove currency for execution
     * @param currency Currency address (address(0) for ETH)
     */
    function removeCurrency(address currency) external onlyOwner {
        if (!isCurrencyWhitelisted[currency]) revert CurrencyNotWhitelisted(currency);

        delete isCurrencyWhitelisted[currency];
        emit CurrencyRemoved(currency);
    }
}
