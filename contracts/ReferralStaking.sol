// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import {OwnableTwoSteps} from "@looksrare/contracts-libs/contracts/OwnableTwoSteps.sol";
import {LowLevelERC20} from "@looksrare/contracts-libs/contracts/lowLevelCallers/LowLevelERC20.sol";
import {IReferralStaking} from "./interfaces/IReferralStaking.sol";
import {LooksRareProtocol} from "./LooksRareProtocol.sol";

/**
 * @title ReferralStaking
 * @notice This contract handles the staking process for referrals.
 * @author LooksRare protocol team (👀,💎)
 */
contract ReferralStaking is IReferralStaking, OwnableTwoSteps, LowLevelERC20 {
    // Maximum timelock period that can be set by this contract owner
    uint256 public constant MAX_TIMELOCK_PERIOD = 30 days;

    // Address of the LooksRare protocol
    LooksRareProtocol public immutable looksRareProtocol;

    // Address of the LOOKS token
    address public immutable looksRareToken;

    // Current number of referral tiers
    uint8 public numberOfTiers;

    // Lockup after deposit (in seconds)
    uint256 public timelockPeriod;

    // Tracks user status (staked amount and last deposit timestamp)
    mapping(address => UserStatus) internal _userStatus;

    // List of tiers, simulate an array behavior
    mapping(uint8 => Tier) internal _tiers;

    /**
     * @notice Constructor
     * @param _looksRareProtocol LooksRare protocol address
     * @param _looksRareToken LOOKS token address
     * @param _timelockPeriod Lockup period after deposit, in seconds
     */
    constructor(
        address _looksRareProtocol,
        address _looksRareToken,
        uint256 _timelockPeriod
    ) {
        looksRareToken = _looksRareToken;
        looksRareProtocol = LooksRareProtocol(_looksRareProtocol);
        timelockPeriod = _timelockPeriod;
    }

    /**
     * @notice Upgrade to a new tier
     * @param tier Tier index the user wants to reach
     * @param amount Amount to deposit (in LOOKS)
     */
    function upgrade(uint8 tier, uint256 amount) external {
        uint256 userStake = _userStatus[msg.sender].stake;

        if (tier >= numberOfTiers) revert StakingTierDoesntExist();

        // If the amount added is not exactly the amount needed to climb to the next tier, reverts
        if (_tiers[tier].stake - userStake != amount) revert WrongDepositAmount();

        if (amount != 0) {
            _executeERC20TransferFrom(looksRareToken, msg.sender, address(this), amount);
        }

        _userStatus[msg.sender] = UserStatus({stake: userStake + amount, lastDepositTimestamp: block.timestamp});
        looksRareProtocol.updateReferrerRate(msg.sender, _tiers[tier].rate);

        emit Deposit(msg.sender, tier);
    }

    /**
     * @notice Withdraw all staked LOOKS for a user
     */
    function withdrawAll() external {
        uint256 userStake = _userStatus[msg.sender].stake;
        if (userStake == 0 && looksRareProtocol.referrerRates(msg.sender) == 0) revert NoFundsStaked();
        _checkTimelock(_userStatus[msg.sender].lastDepositTimestamp);

        delete _userStatus[msg.sender];
        looksRareProtocol.updateReferrerRate(msg.sender, 0);

        if (userStake != 0) {
            _executeERC20DirectTransfer(looksRareToken, msg.sender, userStake);
        }

        emit WithdrawAll(msg.sender);
    }

    /**
     * @notice Downgrade to a lower staking tier
     * @param tier Tier index the user wants to reach
     */
    function downgrade(uint8 tier) external {
        uint256 userStake = _userStatus[msg.sender].stake;

        if (tier >= numberOfTiers) revert StakingTierDoesntExist();
        if (_tiers[tier].stake >= userStake) revert TierTooHigh();
        _checkTimelock(_userStatus[msg.sender].lastDepositTimestamp);

        _userStatus[msg.sender].stake = _tiers[tier].stake;
        looksRareProtocol.updateReferrerRate(msg.sender, _tiers[tier].rate);
        _executeERC20DirectTransfer(looksRareToken, msg.sender, userStake - _tiers[tier].stake);

        emit Downgrade(msg.sender, tier);
    }

    /**
     * @notice Update referrer tier without requirement to stake
     * @param user User address
     * @param tier Tier for the user
     */
    function updateReferrerRate(address user, uint8 tier) external onlyOwner {
        if (tier >= numberOfTiers) revert StakingTierDoesntExist();
        looksRareProtocol.updateReferrerRate(user, _tiers[tier].rate);
    }

    /**
     * @notice Set tier
     * @param index Tier index
     * @param rate Rate for the tier
     * @param stake Stake required for the tier (in LOOKS)
     */
    function setTier(
        uint8 index,
        uint16 rate,
        uint256 stake
    ) external onlyOwner {
        require(
            index <= numberOfTiers,
            "Use an existing index to update a tier, or use numberOfTiers to create a new tier"
        );

        _tiers[index] = Tier(rate, stake);
        if (index == numberOfTiers) {
            numberOfTiers++;
        }

        emit NewTier(index, rate, stake);
    }

    /**
     * @notice Remove last tier
     */
    function removeLastTier() external onlyOwner {
        require(numberOfTiers > 0, "No tiers left");
        delete _tiers[--numberOfTiers];
        emit LastTierRemoved();
    }

    /**
     * @notice Set new timelock period
     * @param newTimelockPeriod Timelock period (in seconds)
     */
    function setTimelockPeriod(uint256 newTimelockPeriod) external onlyOwner {
        require(newTimelockPeriod <= MAX_TIMELOCK_PERIOD, "Time lock too high");
        timelockPeriod = newTimelockPeriod;
        emit UpdateTimelock(newTimelockPeriod);
    }

    /**
     * @notice View user status (stake and latest deposit time)
     * @param user User address
     */
    function viewUserStatus(address user) external view returns (UserStatus memory userStatus) {
        return _userStatus[user];
    }

    /**
     * @notice View tier information
     * @param tier Tier index
     */
    function viewTier(uint8 tier) external view returns (Tier memory) {
        return _tiers[tier];
    }

    /**
     * @notice Check timelock
     * @param lastDepositTimestamp Last deposit timestamp
     */
    function _checkTimelock(uint256 lastDepositTimestamp) internal view {
        if (lastDepositTimestamp + timelockPeriod > block.timestamp) revert FundsTimelocked();
    }
}
