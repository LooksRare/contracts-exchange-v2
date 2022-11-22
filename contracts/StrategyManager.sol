// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// LooksRare unopinionated libraries
import {OwnableTwoSteps} from "@looksrare/contracts-libs/contracts/OwnableTwoSteps.sol";

// Interfaces
import {IStrategyManager} from "./interfaces/IStrategyManager.sol";

/**
 * @title StrategyManager
 * @notice This contract handles the addition and the update of execution strategies.
 * @author LooksRare protocol team (👀,💎)
 */
contract StrategyManager is IStrategyManager, OwnableTwoSteps {
    // Maximum protocol fee
    uint16 private immutable _MAX_PROTOCOL_FEE = 5000;

    // Count how many strategies exist (it includes strategies that have been removed)
    uint16 public countStrategies = 2;

    // Track strategy information for a strategy id
    mapping(uint16 => Strategy) public strategyInfo;

    /**
     * @notice Constructor
     */
    constructor() {
        strategyInfo[0] = Strategy({
            isActive: true,
            standardProtocolFee: 150,
            maxProtocolFee: 300,
            minTotalFee: 200,
            selectorTakerAsk: bytes4(0),
            selectorTakerBid: bytes4(0),
            implementation: address(0)
        });

        strategyInfo[1] = Strategy({
            isActive: true,
            standardProtocolFee: 150,
            maxProtocolFee: 300,
            minTotalFee: 200,
            selectorTakerAsk: bytes4(0),
            selectorTakerBid: bytes4(0),
            implementation: address(0)
        });
    }

    /**
     * @notice Add a new strategy
     * @param standardProtocolFee Protocol fee
     * @param maxProtocolFee Maximum protocol fee
     * @param selectorTakerAsk Selector for takerAsk
     * @param selectorTakerBid Selector for takerBid
     * @param implementation Implementation address
     * @dev Strategies have an id that is incremental.
     */
    function addStrategy(
        uint16 standardProtocolFee,
        uint16 minTotalFee,
        uint16 maxProtocolFee,
        bytes4 selectorTakerAsk,
        bytes4 selectorTakerBid,
        address implementation
    ) external onlyOwner {
        if (maxProtocolFee < standardProtocolFee || maxProtocolFee < minTotalFee || maxProtocolFee > _MAX_PROTOCOL_FEE)
            revert StrategyProtocolFeeTooHigh();

        if (selectorTakerAsk == bytes4(0)) {
            if (selectorTakerBid == bytes4(0)) revert StrategyHasNoSelector();
        }

        strategyInfo[countStrategies] = Strategy({
            isActive: true,
            standardProtocolFee: standardProtocolFee,
            minTotalFee: minTotalFee,
            maxProtocolFee: maxProtocolFee,
            selectorTakerAsk: selectorTakerAsk,
            selectorTakerBid: selectorTakerBid,
            implementation: implementation
        });

        emit NewStrategy(countStrategies++, implementation);
    }

    /**
     * @notice Update strategy
     * @param strategyId Strategy id
     * @param newStandardProtocolFee New standard protocol fee (e.g., 200 --> 2%)
     * @param newMinTotalFee New minimum total fee
     * @param isActive Whether the strategy is active
     */
    function updateStrategy(
        uint16 strategyId,
        uint16 newStandardProtocolFee,
        uint16 newMinTotalFee,
        bool isActive
    ) external onlyOwner {
        Strategy memory currentStrategyInfo = strategyInfo[strategyId];
        if (strategyId >= countStrategies) revert StrategyNotUsed();

        if (
            newStandardProtocolFee > currentStrategyInfo.maxProtocolFee ||
            newMinTotalFee > currentStrategyInfo.maxProtocolFee
        ) revert StrategyProtocolFeeTooHigh();

        strategyInfo[strategyId] = Strategy({
            isActive: isActive,
            standardProtocolFee: newStandardProtocolFee,
            minTotalFee: newMinTotalFee,
            maxProtocolFee: currentStrategyInfo.maxProtocolFee,
            selectorTakerAsk: currentStrategyInfo.selectorTakerAsk,
            selectorTakerBid: currentStrategyInfo.selectorTakerBid,
            implementation: currentStrategyInfo.implementation
        });

        emit StrategyUpdated(strategyId, isActive, newStandardProtocolFee, newMinTotalFee);
    }
}
