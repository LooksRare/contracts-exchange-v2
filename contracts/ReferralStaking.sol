// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import {OwnableTwoSteps} from "@looksrare/contracts-libs/contracts/OwnableTwoSteps.sol";
import {LowLevelERC20} from "./lowLevelCallers/LowLevelERC20.sol";
import {LooksRareProtocol} from "./LooksRareProtocol.sol";
import {IReferralStaking} from "./interfaces/IReferralStaking.sol";

contract ReferralStaking is IReferralStaking, OwnableTwoSteps, LowLevelERC20 {
    struct Tier {
        // Referral share relative to the protocol fees (per 10000)
        uint16 rate;
        // Amount of LOOKS to stake to enable this tier
        uint256 stake;
    }

    uint256 public constant MAX_TIMELOCK_PERIOD = 30 days;

    address public immutable looksRareTokenAddress;
    LooksRareProtocol public immutable looksRareProtocol;

    // Lockup after deposit
    uint256 public timelockPeriod;
    mapping(address => uint256) internal _lastDepositTimestamp;

    // List of tiers, simulate an array behavior
    mapping(uint8 => Tier) internal _tiers;
    uint8 public numberOfTiers;

    // Amount of LOOKS staked per address
    mapping(address => uint256) internal _userStakes;

    /**
     * @notice Constructor
     * @param _looksRareProtocol LooksRare protocol address
     * @param _looksRareTokenAddress LOOKS token address
     * @param _timelockPeriod Lockup period after deposit, in seconds
     */
    constructor(
        address _looksRareProtocol,
        address _looksRareTokenAddress,
        uint256 _timelockPeriod
    ) {
        looksRareTokenAddress = _looksRareTokenAddress;
        looksRareProtocol = LooksRareProtocol(_looksRareProtocol);
        timelockPeriod = _timelockPeriod;
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
        if (_tiers[tier].stake - _userStakes[msg.sender] != amount) {
            revert WrongDepositAmount();
        }

        _executeERC20Transfer(looksRareTokenAddress, msg.sender, address(this), amount);
        _userStakes[msg.sender] += amount;
        looksRareProtocol.registerReferrer(msg.sender, _tiers[tier].rate);
        _lastDepositTimestamp[msg.sender] = block.timestamp;

        emit Deposit(msg.sender, tier);
    }

    /**
     * @notice Withdraw all staked LOOKS for a user
     */
    function withdrawAll() external {
        if (_userStakes[msg.sender] == 0) {
            revert NoFundsStaked();
        }
        if (_lastDepositTimestamp[msg.sender] + timelockPeriod > block.timestamp) {
            revert FundsTimelocked();
        }

        _executeERC20DirectTransfer(looksRareTokenAddress, msg.sender, _userStakes[msg.sender]);
        delete _userStakes[msg.sender];
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
        if (_tiers[tier].stake >= _userStakes[msg.sender]) {
            revert TierTooHigh();
        }
        if (_lastDepositTimestamp[msg.sender] + timelockPeriod > block.timestamp) {
            revert FundsTimelocked();
        }

        _executeERC20DirectTransfer(looksRareTokenAddress, msg.sender, _userStakes[msg.sender] - _tiers[tier].stake);
        _userStakes[msg.sender] = _userStakes[msg.sender] - (_userStakes[msg.sender] - _tiers[tier].stake);
        looksRareProtocol.unregisterReferrer(msg.sender);
        looksRareProtocol.registerReferrer(msg.sender, _tiers[tier].rate);

        emit Downgrade(msg.sender, tier);
    }

    /* Owner only functions */

    function registerReferrer(address user, uint8 tier) external onlyOwner {
        if (tier >= numberOfTiers) {
            revert StakingTierDoesntExist();
        }
        if (_userStakes[user] > 0) {
            revert UserAlreadyStaking();
        }
        looksRareProtocol.registerReferrer(user, _tiers[tier].rate);
    }

    function unregisterReferrer(address user) external onlyOwner {
        looksRareProtocol.unregisterReferrer(user);
    }

    function setTier(
        uint8 index,
        uint16 _rate,
        uint256 _stake
    ) external onlyOwner {
        require(
            index <= numberOfTiers,
            "Use an existing index to update a tier, or use numberOfTiers to create a new tier"
        );
        _tiers[index] = Tier(_rate, _stake);
        if (index == numberOfTiers) {
            numberOfTiers++;
        }
        emit NewTier(index, _rate, _stake);
    }

    function setTimelockPeriod(uint256 _timelockPeriod) external onlyOwner {
        require(_timelockPeriod <= MAX_TIMELOCK_PERIOD, "Time lock too high");
        timelockPeriod = _timelockPeriod;
        emit NewTimelock(_timelockPeriod);
    }

    /* Getter functions */

    function viewUserStake(address user) external view returns (uint256) {
        return _userStakes[user];
    }

    function viewTier(uint8 tier) external view returns (Tier memory) {
        return _tiers[tier];
    }

    function viewUserTimelock(address user) external view returns (uint256, uint256) {
        return (_lastDepositTimestamp[user], timelockPeriod);
    }
}
