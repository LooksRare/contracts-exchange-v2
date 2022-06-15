// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import {OwnableTwoSteps} from "@looksrare/contract-libs/contracts/OwnableTwoSteps.sol";

/**
 * @title ReferralManager
 * @notice This contract handles the list of referrers for the LooksRare protocol.
 * @author LooksRare protocol team (👀,💎)
 */
contract ReferralManager is OwnableTwoSteps {
    // Address of the referral controller
    address public referralController;

    // Custom errors
    error NotController();
    error NotReferrer();
    error PercentageTooHigh();

    // Events
    event NewReferralController(address referralController);
    event NewReferrer(address referrer, uint16 percentage);
    event ReferrerRemoved(address referrer);

    modifier onlyController() {
        if (msg.sender == referralController) {
            revert NotController();
        }
        _;
    }

    // Tracks referrer status
    mapping(address => uint16) internal _referrers;

    /**
     * @notice Register referrer with its associated percentage
     * @param referrer referrer address
     * @param percentage percentage to collect (e.g., 100 = 1%)
     */
    function registerReferrer(address referrer, uint16 percentage) external onlyController {
        if (percentage > 10000) {
            revert PercentageTooHigh();
        }

        _referrers[referrer] = percentage;

        emit NewReferrer(referrer, percentage);
    }

    /**
     * @notice Unregister referrer
     * @param referrer referrer address
     */
    function unregisterReferrer(address referrer) external onlyController {
        if (_referrers[referrer] == 0) {
            revert NotReferrer();
        }

        delete _referrers[referrer];

        emit ReferrerRemoved(referrer);
    }

    /**
     * @notice Add referral controller
     * @param newReferralController address of new referral controller contract
     */
    function updateReferralController(address newReferralController) external onlyOwner {
        referralController = newReferralController;
        emit NewReferralController(newReferralController);
    }
}
