// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

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

    // Custom events
    event NewCollectionStakingRegistry(address collectionStakingRegistry);
    event NewProtocolFeeRecipient(address protocolFeeRecipient);
}
