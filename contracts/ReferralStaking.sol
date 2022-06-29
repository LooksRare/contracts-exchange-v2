// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import {OwnableTwoSteps} from "@looksrare/contract-libs/contracts/OwnableTwoSteps.sol";
import {ReentrancyGuard} from "@looksrare/contract-libs/contracts/ReentrancyGuard.sol";
import {LowLevelERC20} from "./lowLevelCallers/LowLevelERC20.sol";

contract ReferralStaking is OwnableTwoSteps, ReentrancyGuard, LowLevelERC20 {
    // Errors
    error NotEnoughFundsStaked();
    error TierRateTooHigh();
    error WrongDepositAmount();
    error NoFundsStaked();
    error StakingTierDoesntExist();

    // Events
    event Deposit(address user, uint256 amount);
    event Withdraw(address user);
    event TierUpdate(uint8 index, uint16 rate, uint256 stake);

    struct Tier {
        // Referral share relative to the protocol fees (per 10000)
        uint16 rate;
        // Amount of LOOKS to stake to enable this tier
        uint256 stake;
    }

    // List of tiers, simulate an array behavior
    mapping(uint8 => Tier) public tiers;
    uint8 public numberOfTiers;

    // Amount of LOOKS staked per address
    mapping(address => uint256) public stake;

    // LOOKS token address
    address public immutable looksRareTokenAddress;

    /**
     * @notice Constructor
     * @param _looksRareTokenAddress LOOKS token address
     */
    constructor(address _looksRareTokenAddress) {
        looksRareTokenAddress = _looksRareTokenAddress;
    }

    /**
     * @notice Deposit LOOKS for staking
     * @param tier Tier index the user wants to reach with the new deposit
     * @param amount Amount to deposit
     */
    function deposit(uint8 tier, uint256 amount) external nonReentrant {
        if (tier > numberOfTiers) {
            revert StakingTierDoesntExist();
        }
        // If the amount added is not exactly the amount needed to climb to the next tier, reverts
        if (tiers[tier].stake - stake[msg.sender] != amount) {
            revert WrongDepositAmount();
        }

        _executeERC20Transfer(looksRareTokenAddress, msg.sender, address(this), amount);
        stake[msg.sender] += amount;

        emit Deposit(msg.sender, amount);
    }

    /**
     * @notice Withdraw all staked LOOKS for a user
     */
    function withdraw() external nonReentrant {
        if (stake[msg.sender] == 0) {
            revert NoFundsStaked();
        }

        _executeERC20Transfer(looksRareTokenAddress, address(this), msg.sender, stake[msg.sender]);
        delete stake[msg.sender];

        emit Withdraw(msg.sender);
    }

    function setTier(uint8 index, Tier calldata tier) external onlyOwner {}
}
