// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

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
     * @notice Whitelist/blacklist currency for execution
     * @param currency Currency address (address(0) for ETH)
     * @param isWhitelisted Whether the currency is whitelisted
     */
    function setIsCurrencyWhitelisted(address currency, bool isWhitelisted) external onlyOwner {
        isCurrencyWhitelisted[currency] = isWhitelisted;
        emit CurrencyWhitelistSet(currency, isWhitelisted);
    }
}
