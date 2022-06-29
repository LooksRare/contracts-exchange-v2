// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import {OwnableTwoSteps} from "@looksrare/contract-libs/contracts/OwnableTwoSteps.sol";
import {ReentrancyGuard} from "@looksrare/contract-libs/contracts/ReentrancyGuard.sol";
import {LowLevelERC20} from "./lowLevelCallers/LowLevelERC20.sol";

contract ReferralStaking is OwnableTwoSteps, ReentrancyGuard, LowLevelERC20 {
    // Errors
    error NotEnoughFundsStaked();
    error TierRateTooHigh();
    error AmountCannotBeZero();
    error NoFundsStaked();

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
     * @param amount Amount to deposit
     */
    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) {
            revert AmountCannotBeZero();
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
        stake[msg.sender] = 0;

        emit Withdraw(msg.sender);
    }

    /**
     * @notice Retrieve a user tier based on his stake
     * @param user User address
     */
    function getUserTier(address user) external view returns (Tier memory) {}

    function setTier(uint8 index, Tier calldata tier) external onlyOwner {}
}
