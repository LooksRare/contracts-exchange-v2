// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

/**
 * @title IStrategyManager
 * @author LooksRare protocol team (👀,💎)
 */
interface IStrategyManager {
    // Custom errors
    error StrategyNotUsed();
    error StrategyProtocolFeeTooHigh();

    // Events
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
