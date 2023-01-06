// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// LooksRare unopinionated libraries
import {CurrencyManager} from "./CurrencyManager.sol";

// Interfaces
import {IBaseStrategy} from "./interfaces/IBaseStrategy.sol";
import {IStrategyManager} from "./interfaces/IStrategyManager.sol";

/**
 * @title StrategyManager
 * @notice This contract handles the addition and the update of execution strategies.
 * @author LooksRare protocol team (👀,💎)
 */
contract StrategyManager is IStrategyManager, CurrencyManager {
    /**
     * @notice This variable keeps the count of how many strategies exist.
     *         It includes strategies that have been removed.
     */
    uint256 public countStrategies = 1;

    /**
     * @notice This returns the strategy information for a strategy id.
     */
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
     * @notice This function allows the owner to add a new execution strategy to the protocol.
     * @param standardProtocolFeeBp Protocol fee
     * @param maxProtocolFeeBp Maximum protocol fee
     * @param selector Selector
     * @param isMakerBid Whether the function selector is for maker bids
     * @param implementation Implementation address
     * @dev Strategies have an id that is incremental.
     *      Only callable by owner.
     */
    function addStrategy(
        uint16 standardProtocolFeeBp,
        uint16 minTotalFeeBp,
        uint16 maxProtocolFeeBp,
        bytes4 selector,
        bool isMakerBid,
        address implementation
    ) external onlyOwner {
        if (minTotalFeeBp > maxProtocolFeeBp || standardProtocolFeeBp > minTotalFeeBp || maxProtocolFeeBp > 500) {
            revert StrategyProtocolFeeTooHigh();
        }

        if (selector == bytes4(0)) {
            revert StrategyHasNoSelector();
        }

        if (!IBaseStrategy(implementation).isLooksRareV2Strategy()) {
            revert NotV2Strategy();
        }

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
     * @notice This function allows the owner to update parameters for an existing execution strategy.
     * @param strategyId Strategy id
     * @param newStandardProtocolFee New standard protocol fee (e.g., 200 --> 2%)
     * @param newMinTotalFee New minimum total fee
     * @param isActive Whether the strategy must remain active
     * @dev Only callable by owner.
     */
    function updateStrategy(
        uint256 strategyId,
        uint16 newStandardProtocolFee,
        uint16 newMinTotalFee,
        bool isActive
    ) external onlyOwner {
        if (strategyId >= countStrategies) {
            revert StrategyNotUsed();
        }

        if (newMinTotalFee > strategyInfo[strategyId].maxProtocolFeeBp || newStandardProtocolFee > newMinTotalFee) {
            revert StrategyProtocolFeeTooHigh();
        }

        strategyInfo[strategyId].isActive = isActive;
        strategyInfo[strategyId].standardProtocolFeeBp = newStandardProtocolFee;
        strategyInfo[strategyId].minTotalFeeBp = newMinTotalFee;

        emit StrategyUpdated(strategyId, isActive, newStandardProtocolFee, newMinTotalFee);
    }
}
