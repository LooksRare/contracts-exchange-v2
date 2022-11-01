// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title IAffiliateManager
 * @author LooksRare protocol team (👀,💎)
 */
interface IAffiliateManager {
    // Custom errors
    error NotAffiliateController();
    error NotAffiliate();
    error PercentageTooHigh();

    // Events
    event NewAffiliateController(address affiliateController);
    event NewAffiliateProgramStatus(bool isActive);
    event NewAffiliateRate(address affiliate, uint16 rate);
}
