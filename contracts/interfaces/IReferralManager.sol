// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title IReferralManager
 * @author LooksRare protocol team (👀,💎)
 */
interface IReferralManager {
    // Custom errors
    error NotReferralController();
    error NotReferrer();
    error PercentageTooHigh();

    // Events
    event NewReferralController(address referralController);
    event NewReferralProgramStatus(bool isActive);
    event NewReferrerRate(address referrer, uint16 rate);
}
