// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

/**
 * @title IExecutionManager
 * @author LooksRare protocol team (👀,💎)
 */
interface IExecutionManager {
    // Custom errors
    error OutsideOfTimeRange();
    error SlippageAsk();
    error SlippageBid();
    error StrategyNotAvailable(uint16 strategyId);
}
