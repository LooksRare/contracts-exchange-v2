// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import {OwnableTwoSteps} from "@looksrare/contracts-libs/contracts/OwnableTwoSteps.sol";
import {LowLevelERC20} from "./lowLevelCallers/LowLevelERC20.sol";
import {LooksRareProtocol} from "./LooksRareProtocol.sol";

contract ReferralStaking is OwnableTwoSteps, LowLevelERC20 {
    // Errors
    error WrongDepositAmount();
    error NoFundsStaked();
    error StakingTierDoesntExist();
    error TierTooHigh();

    // Events
    event Deposit(address user, uint256 amount);
    event WithdrawAll(address user);
    event TierUpdate(uint8 index, uint16 rate, uint256 stake);

    struct Tier {
        // Referral share relative to the protocol fees (per 10000)
        uint16 rate;
        // Amount of LOOKS to stake to enable this tier
        uint256 stake;
    }

    // List of tiers, simulate an array behavior
    mapping(uint8 => Tier) internal tiers;
    uint8 public numberOfTiers;

    // Amount of LOOKS staked per address
    mapping(address => uint256) internal stake;

    // LOOKS token address
    address public immutable looksRareTokenAddress;
    LooksRareProtocol public immutable looksRareProtocol;

    /**
     * @notice Constructor
     * @param _looksRareTokenAddress LOOKS token address
     */
    constructor(address _looksRareProtocol, address _looksRareTokenAddress) {
        looksRareTokenAddress = _looksRareTokenAddress;
        looksRareProtocol = LooksRareProtocol(_looksRareProtocol);
    }

    /**
     * @notice Deposit LOOKS for staking
     * @param tier Tier index the user wants to reach with the new deposit
     * @param amount Amount to deposit
     */
    function deposit(uint8 tier, uint256 amount) external {
        if (tier >= numberOfTiers) {
            revert StakingTierDoesntExist();
        }
        // If the amount added is not exactly the amount needed to climb to the next tier, reverts
        if (tiers[tier].stake - stake[msg.sender] != amount) {
            revert WrongDepositAmount();
        }

        _executeERC20Transfer(looksRareTokenAddress, msg.sender, address(this), amount);
        stake[msg.sender] += amount;
        looksRareProtocol.registerReferrer(msg.sender, tiers[tier].rate);

        emit Deposit(msg.sender, amount);
    }

    /**
     * @notice Withdraw all staked LOOKS for a user
     */
    function withdrawAll() external {
        if (stake[msg.sender] == 0) {
            revert NoFundsStaked();
        }

        _executeERC20Transfer(looksRareTokenAddress, address(this), msg.sender, stake[msg.sender]);
        delete stake[msg.sender];
        looksRareProtocol.unregisterReferrer(msg.sender);

        emit WithdrawAll(msg.sender);
    }

    /**
     * @notice Downgrade to a lower staking tier
     * @param tier Tier index the user wants to reach
     */
    function downgrade(uint8 tier) external {
        if (tier >= numberOfTiers) {
            revert StakingTierDoesntExist();
        }
        if (tiers[tier].stake >= stake[msg.sender]) {
            revert TierTooHigh();
        }

        _executeERC20Transfer(looksRareTokenAddress, address(this), msg.sender, stake[msg.sender] - tiers[tier].stake);
        looksRareProtocol.unregisterReferrer(msg.sender);
        looksRareProtocol.registerReferrer(msg.sender, tiers[tier].rate);
    }

    /* Getters */

    function viewUserStake(address user) external view returns (uint256) {
        return stake[user];
    }

    function viewTier(uint8 tier) external view returns (Tier memory) {
        return tiers[tier];
    }

    /* Owner only functions */

    function registerReferrer(address user, uint8 tier) external onlyOwner {
        if (tier >= numberOfTiers) {
            revert StakingTierDoesntExist();
        }
        looksRareProtocol.registerReferrer(user, tiers[tier].rate);
    }

    function unregisterReferrer(address user) external onlyOwner {
        looksRareProtocol.unregisterReferrer(user);
    }

    function setTier(
        uint8 index,
        uint16 _rate,
        uint256 _stake
    ) external onlyOwner {
        require(index <= numberOfTiers, "You skipped a tier");
        tiers[index] = Tier(_rate, _stake);
        numberOfTiers++;
    }
}
