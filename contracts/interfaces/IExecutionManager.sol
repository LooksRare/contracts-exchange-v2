// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

interface IExecutionManager {
    // Custom errors
    error AskSlippage();
    error CollectionDiscountFactorTooHigh();
    error OrderInvalid();
    error OutsideOfTimeRange();
    error StrategyNotAvailable(uint16 strategyId);
    error StrategyUsed(uint16 strategyId);
    error StrategyNotUsed(uint16 strategyId);

    // Events
    event NewCollectionDiscountFactor(address collection, uint256 discountFactor);
    event NewProtocolFeeRecipient(address protocolFeeRecipient);
    event NewStrategy(uint16 strategyId, address implementation);
    event StrategyReactivated(uint16 strategyId);
    event StrategyRemoved(uint16 strategyId);
}
