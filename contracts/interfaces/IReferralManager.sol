// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

interface IReferralManager {
    // Custom errors
    error NotController();
    error NotReferrer();
    error PercentageTooHigh();

    // Events
    event NewReferralController(address referralController);
    event NewReferrer(address referrer, uint16 percentage);
    event ReferrerRemoved(address referrer);
}
