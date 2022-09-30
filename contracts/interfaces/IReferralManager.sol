// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

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
