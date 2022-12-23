// SPDXLicenseIdentifier: MIT
pragma solidity ^0.8.17;

// LooksRare unopinionated libraries
import {OwnableTwoSteps} from "@looksrare/contracts-libs/contracts/OwnableTwoSteps.sol";

// Interfaces
import {ICurrencyManager} from "./interfaces/ICurrencyManager.sol";

/**
 * @title CurrencyManager
 * @notice This contract manages the whitelist of valid fungible currencies.
 * @author LooksRare protocol team (👀,💎)
 */
contract CurrencyManager is ICurrencyManager, OwnableTwoSteps {
    // Check whether the currency is whitelisted
    mapping(address => bool) public isCurrencyWhitelisted;

    /**
     * @notice Constructor
     * @param _owner Owner address
     */
    constructor(address _owner) OwnableTwoSteps(_owner) {}

    /**
     * @notice Whitelist/blacklist currency for execution
     * @param currency Currency address (address(0) for ETH)
     * @param isWhitelisted Whether the currency is whitelisted
     */
    function updateCurrencyWhitelistStatus(address currency, bool isWhitelisted) external onlyOwner {
        isCurrencyWhitelisted[currency] = isWhitelisted;
        emit CurrencyWhitelistStatusUpdated(currency, isWhitelisted);
    }
}
