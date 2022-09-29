// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import {OwnableTwoSteps} from "@looksrare/contracts-libs/contracts/OwnableTwoSteps.sol";
import {IReferralManager} from "./interfaces/IReferralManager.sol";

/**
 * @title ReferralManager
 * @notice This contract handles the list of referrers for the LooksRare protocol.
 * @author LooksRare protocol team (👀,💎)
 */
contract ReferralManager is IReferralManager, OwnableTwoSteps {
    // Whether the referral program is active
    bool public isReferralProgramActive;

    // Address of the referral controller
    address public referralController;

    // Tracks referrer rates
    mapping(address => uint16) public referrerRates;

    /**
     * @notice Register referrer with its associated percentage
     * @param referrer referrer address
     * @param percentage percentage to collect (e.g., 100 = 1%)
     */
    function registerReferrer(address referrer, uint16 percentage) external {
        if (msg.sender != referralController) revert NotReferralController();
        if (percentage > 10000) revert PercentageTooHigh();

        referrerRates[referrer] = percentage;

        emit NewReferrer(referrer, percentage);
    }

    /**
     * @notice Unregister referrer
     * @param referrer referrer address
     */
    function unregisterReferrer(address referrer) external {
        if (msg.sender != referralController) revert NotReferralController();
        if (referrerRates[referrer] == 0) revert NotReferrer();

        delete referrerRates[referrer];

        emit ReferrerRemoved(referrer);
    }

    /**
     * @notice Update status for referral program
     * @param isActive whether the referral program is active
     */
    function updateReferralProgramStatus(bool isActive) external onlyOwner {
        isReferralProgramActive = isActive;
        emit NewReferralProgramStatus(isActive);
    }

    /**
     * @notice Update referral controller
     * @param newReferralController address of new referral controller contract
     */
    function updateReferralController(address newReferralController) external onlyOwner {
        referralController = newReferralController;
        emit NewReferralController(newReferralController);
    }
}
