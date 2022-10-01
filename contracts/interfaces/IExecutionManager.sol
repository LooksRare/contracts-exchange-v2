// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

interface IExecutionManager {
    // Custom errors
    error OrderInvalid();
    error OutsideOfTimeRange();
    error SlippageAsk();
    error SlippageBid();
    error StrategyNotAvailable(uint16 strategyId);
}
