// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Interfaces
import {ICurrencyManager} from "./interfaces/ICurrencyManager.sol";

// Dependencies
import {AffiliateManager} from "./AffiliateManager.sol";

/**
 * @title CurrencyManager
 * @notice This contract manages the whitelist of valid fungible currencies.
 * @author LooksRare protocol team (👀,💎)
 */
contract CurrencyManager is ICurrencyManager, AffiliateManager {
    // Check whether the currency is whitelisted
    mapping(address => bool) public isCurrencyWhitelisted;

    /**
     * @notice Constructor
     * @param _owner Owner address
     */
    constructor(address _owner) AffiliateManager(_owner) {}

    /**
     * @notice Whitelist/blacklist currency for execution
     * @param currency Currency address (address(0) for ETH)
     * @param isWhitelisted Whether the currency is whitelisted
     * @dev Only callable by owner.
     */
    function updateCurrencyWhitelistStatus(address currency, bool isWhitelisted) external onlyOwner {
        isCurrencyWhitelisted[currency] = isWhitelisted;
        emit CurrencyWhitelistStatusUpdated(currency, isWhitelisted);
    }
}
