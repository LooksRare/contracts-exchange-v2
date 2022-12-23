// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// LooksRare unopinionated libraries
import {CurrencyManager} from "./CurrencyManager.sol";

// Interfaces
import {IStrategyManager} from "./interfaces/IStrategyManager.sol";

/**
 * @title StrategyManager
 * @notice This contract handles the addition and the update of execution strategies.
 * @author LooksRare protocol team (👀,💎)
 */
contract StrategyManager is IStrategyManager, CurrencyManager {
    // Count how many strategies exist (it includes strategies that have been removed)
    uint256 public countStrategies = 1;

    // Track strategy information for a strategy id
    mapping(uint256 => Strategy) public strategyInfo;

    /**
     * @notice Constructor
     * @param _owner Owner address
     */
    constructor(address _owner) CurrencyManager(_owner) {
        strategyInfo[0] = Strategy({
            isActive: true,
            standardProtocolFee: 150,
            minTotalFee: 200,
            maxProtocolFee: 300,
            selector: bytes4(0),
            isMakerBid: false,
            implementation: address(0)
        });
    }

    /**
     * @notice Add a new strategy
     * @param standardProtocolFee Protocol fee
     * @param maxProtocolFee Maximum protocol fee
     * @param selector Selector
     * @param isMakerBid Whether the function selector is for maker bids
     * @param implementation Implementation address
     * @dev Strategies have an id that is incremental.
     */
    function addStrategy(
        uint16 standardProtocolFee,
        uint16 minTotalFee,
        uint16 maxProtocolFee,
        bytes4 selector,
        bool isMakerBid,
        address implementation
    ) external onlyOwner {
        if (maxProtocolFee < standardProtocolFee || maxProtocolFee < minTotalFee || maxProtocolFee > 5_000)
            revert StrategyProtocolFeeTooHigh();

        if (selector == bytes4(0)) revert StrategyHasNoSelector();

        strategyInfo[countStrategies] = Strategy({
            isActive: true,
            standardProtocolFee: standardProtocolFee,
            minTotalFee: minTotalFee,
            maxProtocolFee: maxProtocolFee,
            selector: selector,
            isMakerBid: isMakerBid,
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
        uint256 strategyId,
        uint16 newStandardProtocolFee,
        uint16 newMinTotalFee,
        bool isActive
    ) external onlyOwner {
        if (strategyId >= countStrategies) revert StrategyNotUsed();

        uint256 maxProtocolFee = strategyInfo[strategyId].maxProtocolFee;
        if (newStandardProtocolFee > maxProtocolFee || newMinTotalFee > maxProtocolFee)
            revert StrategyProtocolFeeTooHigh();

        strategyInfo[strategyId].isActive = isActive;
        strategyInfo[strategyId].standardProtocolFee = newStandardProtocolFee;
        strategyInfo[strategyId].minTotalFee = newMinTotalFee;

        emit StrategyUpdated(strategyId, isActive, newStandardProtocolFee, newMinTotalFee);
    }
}
