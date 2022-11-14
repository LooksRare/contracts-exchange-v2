// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// LooksRare unopinionated libraries
import {OwnableTwoSteps} from "@looksrare/contracts-libs/contracts/OwnableTwoSteps.sol";

// Interfaces
import {IAffiliateManager} from "./interfaces/IAffiliateManager.sol";

/**
 * @title AffiliateManager
 * @notice This contract handles the list of affiliates for the LooksRare protocol.
 * @author LooksRare protocol team (👀,💎)
 */
contract AffiliateManager is IAffiliateManager, OwnableTwoSteps {
    // Whether the affiliate program is active
    bool public isAffiliateProgramActive;

    // Address of the affiliate controller
    address public affiliateController;

    // Tracks affiliate rates
    mapping(address => uint256) public affiliateRates;

    /**
     * @notice Update affiliate rate
     * @param affiliate Affiliate address
     * @param bp Rate basis point to collect (e.g., 100 = 1%) per referred trade
     */
    function updateAffiliateRate(address affiliate, uint256 bp) external {
        if (msg.sender != affiliateController) revert NotAffiliateController();
        if (bp > 10000) revert PercentageTooHigh();

        affiliateRates[affiliate] = bp;
        emit NewAffiliateRate(affiliate, bp);
    }

    /**
     * @notice Update status for affiliate program
     * @param isActive whether the affiliate program is active
     */
    function updateAffiliateProgramStatus(bool isActive) external onlyOwner {
        isAffiliateProgramActive = isActive;
        emit NewAffiliateProgramStatus(isActive);
    }

    /**
     * @notice Update affiliate controller
     * @param newAffiliateController address of new affiliate controller contract
     */
    function updateAffiliateController(address newAffiliateController) external onlyOwner {
        affiliateController = newAffiliateController;
        emit NewAffiliateController(newAffiliateController);
    }
}
