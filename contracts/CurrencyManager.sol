// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import {OwnableTwoSteps} from "@looksrare/contracts-libs/contracts/OwnableTwoSteps.sol";
import {ICurrencyManager} from "./interfaces/ICurrencyManager.sol";

/**
 * @title CurrencyManager
 * @notice This contract manages the whitelist of valid currencies for exchanging NFTs on the exchange.
 * @author LooksRare protocol team (👀,💎)
 */
contract CurrencyManager is ICurrencyManager, OwnableTwoSteps {
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

    /**
     * @notice Is currency whitelisted
     * @param currency address of the currency (address(0) for ETH)
     * @return isWhitelisted whether the currency is whitelisted
     */
    function isCurrencyWhitelisted(address currency) external view returns (bool isWhitelisted) {
        return _isCurrencyWhitelisted[currency];
    }
}
