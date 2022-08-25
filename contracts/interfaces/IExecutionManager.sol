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
    error StrategyProtocolFeeTooHigh(uint16 strategyId);

    // Events
    event NewCollectionDiscountFactor(address collection, uint256 discountFactor);
    event NewProtocolFeeRecipient(address protocolFeeRecipient);
    event NewStrategy(uint16 strategyId, address implementation);
    event StrategyUpdated(uint16 strategyId, bool isActive, bool hasRoyalties, uint16 protocolFee);

    // Custom structs
    struct Strategy {
        bool isActive;
        bool hasRoyalties;
        uint16 protocolFee;
        uint16 maxProtocolFee;
        address implementation;
    }
}
