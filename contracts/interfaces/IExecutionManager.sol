// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title IExecutionManager
 * @author LooksRare protocol team (👀,💎)
 */
interface IExecutionManager {
    // Custom errors
    error CreatorFeeBpTooHigh();
    error NoSelectorForTakerAsk();
    error NoSelectorForTakerBid();
    error OutsideOfTimeRange();
    error SlippageAsk();
    error SlippageBid();
    error StrategyNotAvailable(uint16 strategyId);

    // Custom events
    event NewCreatorFeeManager(address creatorFeeManager);
    event NewMaximumCreatorFeeBp(uint256 maximumCreatorFeeBp);
    event NewProtocolFeeRecipient(address protocolFeeRecipient);
}
