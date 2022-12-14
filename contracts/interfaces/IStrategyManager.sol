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
    event NewStrategy(uint256 strategyId, address implementation);
    event StrategyUpdated(uint256 strategyId, bool isActive, uint16 standardProtocolFee, uint16 minTotalFee);

    // Custom structs
    struct Strategy {
        bool isActive;
        uint16 standardProtocolFee;
        uint16 minTotalFee;
        uint16 maxProtocolFee;
        bytes4 selector;
        bool isMakerBid;
        address implementation;
    }
}
