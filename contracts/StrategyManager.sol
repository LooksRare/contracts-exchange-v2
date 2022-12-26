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
            standardProtocolFeeBp: 150,
            minTotalFeeBp: 200,
            maxProtocolFeeBp: 300,
            selector: bytes4(0),
            isMakerBid: false,
            implementation: address(0)
        });
    }

    /**
     * @notice Add a new strategy
     * @param standardProtocolFeeBp Protocol fee
     * @param maxProtocolFeeBp Maximum protocol fee
     * @param selector Selector
     * @param isMakerBid Whether the function selector is for maker bids
     * @param implementation Implementation address
     * @dev Strategies have an id that is incremental.
     */
    function addStrategy(
        uint16 standardProtocolFeeBp,
        uint16 minTotalFeeBp,
        uint16 maxProtocolFeeBp,
        bytes4 selector,
        bool isMakerBid,
        address implementation
    ) external onlyOwner {
        if (maxProtocolFeeBp < standardProtocolFeeBp || maxProtocolFeeBp < minTotalFeeBp || maxProtocolFeeBp > 500)
            revert StrategyProtocolFeeTooHigh();

        if (selector == bytes4(0)) revert StrategyHasNoSelector();

        strategyInfo[countStrategies] = Strategy({
            isActive: true,
            standardProtocolFeeBp: standardProtocolFeeBp,
            minTotalFeeBp: minTotalFeeBp,
            maxProtocolFeeBp: maxProtocolFeeBp,
            selector: selector,
            isMakerBid: isMakerBid,
            implementation: implementation
        });

        emit NewStrategy(
            countStrategies++,
            standardProtocolFeeBp,
            minTotalFeeBp,
            maxProtocolFeeBp,
            selector,
            isMakerBid,
            implementation
        );
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

        uint256 maxProtocolFeeBp = strategyInfo[strategyId].maxProtocolFeeBp;
        if (newStandardProtocolFee > maxProtocolFeeBp || newMinTotalFee > maxProtocolFeeBp)
            revert StrategyProtocolFeeTooHigh();

        strategyInfo[strategyId].isActive = isActive;
        strategyInfo[strategyId].standardProtocolFeeBp = newStandardProtocolFee;
        strategyInfo[strategyId].minTotalFeeBp = newMinTotalFee;

        emit StrategyUpdated(strategyId, isActive, newStandardProtocolFee, newMinTotalFee);
    }
}
