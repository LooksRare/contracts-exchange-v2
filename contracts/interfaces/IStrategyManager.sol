// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title IStrategyManager
 * @author LooksRare protocol team (👀,💎)
 */
interface IStrategyManager {
    // Custom errors
    error StrategyNotUsed();
    error StrategyProtocolFeeTooHigh();
    error StrategyHasNoSelector();

    // Events
    event NewStrategy(uint16 strategyId, address implementation);
    event StrategyUpdated(uint16 strategyId, bool isActive, uint16 standardProtocolFee, uint16 minTotalFee);

    // Custom structs
    struct Strategy {
        bool isActive;
        uint16 standardProtocolFee;
        uint16 minTotalFee;
        uint16 maxProtocolFee;
        bytes4 selectorTakerAsk;
        bytes4 selectorTakerBid;
        address implementation;
    }
}
