// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import {OwnableTwoSteps} from "@looksrare/contracts-libs/contracts/OwnableTwoSteps.sol";
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
    mapping(uint16 => Strategy) internal _strategyInfo;

    /**
     * @notice Constructor
     */
    constructor() {
        _strategyInfo[0] = Strategy({
            isActive: true,
            hasRoyalties: true,
            protocolFee: 200,
            maxProtocolFee: 300,
            implementation: address(0)
        });
        _strategyInfo[1] = Strategy({
            isActive: true,
            hasRoyalties: true,
            protocolFee: 200,
            maxProtocolFee: 300,
            implementation: address(0)
        });
    }

    /**
     * @notice Add a new strategy
     * @param hasRoyalties Whether the strategy has royalties
     * @param protocolFee Protocol fee
     * @param maxProtocolFee Maximum protocol fee
     * @param implementation Implementation address
     * @dev Strategies have an id that is incremental.
     */
    function addStrategy(
        bool hasRoyalties,
        uint16 protocolFee,
        uint16 maxProtocolFee,
        address implementation
    ) external onlyOwner {
        if (maxProtocolFee < protocolFee || maxProtocolFee > _MAX_PROTOCOL_FEE) revert StrategyProtocolFeeTooHigh();

        _strategyInfo[countStrategies] = Strategy({
            isActive: true,
            hasRoyalties: hasRoyalties,
            protocolFee: protocolFee,
            maxProtocolFee: maxProtocolFee,
            implementation: implementation
        });

        emit NewStrategy(countStrategies++, implementation);
    }

    /**
     * @notice Update strategy
     * @param strategyId Strategy id
     * @param hasRoyalties Whether the strategy should distribute royalties
     * @param protocolFee Protocol fee (e.g., 200 --> 2%)
     * @param isActive Whether the strategy is active
     */
    function updateStrategy(
        uint16 strategyId,
        bool hasRoyalties,
        uint16 protocolFee,
        bool isActive
    ) external onlyOwner {
        if (strategyId >= countStrategies) revert StrategyNotUsed();
        if (protocolFee > _strategyInfo[strategyId].maxProtocolFee) revert StrategyProtocolFeeTooHigh();

        _strategyInfo[strategyId] = Strategy({
            isActive: isActive,
            hasRoyalties: hasRoyalties,
            protocolFee: protocolFee,
            maxProtocolFee: _strategyInfo[strategyId].maxProtocolFee,
            implementation: _strategyInfo[strategyId].implementation
        });

        emit StrategyUpdated(strategyId, isActive, hasRoyalties, protocolFee);
    }

    /**
     * @notice View strategy information for a given strategy id
     * @param strategyId Strategy id
     * @return strategy Information about the strategy (protocol fee, maximum protocol fee, royalty status, implementation address)
     */
    function strategyInfo(uint16 strategyId) external view returns (Strategy memory strategy) {
        return _strategyInfo[strategyId];
    }
}
