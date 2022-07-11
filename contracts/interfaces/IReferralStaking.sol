// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

interface IReferralStaking {
    // Events
    event Deposit(address user, uint8 tier);
    event Downgrade(address user, uint8 tier);
    event WithdrawAll(address user);
    event TierUpdate(uint8 index, uint16 rate, uint256 stake);
    event NewTier(uint8 index, uint256 rate, uint256 stake);
    event NewTimelock(uint256 timelockPeriod);

    // Custom Errors
    error WrongDepositAmount();
    error NoFundsStaked();
    error StakingTierDoesntExist();
    error TierTooHigh();
    error UserAlreadyStaking();
    error FundsTimelocked();
}
