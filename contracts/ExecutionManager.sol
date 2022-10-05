// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

// LooksRare unopinionated libraries
import {OwnableTwoSteps} from "@looksrare/contracts-libs/contracts/OwnableTwoSteps.sol";

// Interfaces
import {IExecutionManager} from "./interfaces/IExecutionManager.sol";
import {IExecutionStrategy} from "./interfaces/IExecutionStrategy.sol";

// Libraries
import {OrderStructs} from "./libraries/OrderStructs.sol";

// Direct dependencies
import {CollectionDiscountManager} from "./CollectionDiscountManager.sol";
import {FeeManager} from "./FeeManager.sol";
import {InheritedStrategies} from "./InheritedStrategies.sol";
import {StrategyManager} from "./StrategyManager.sol";

/**
 * @title ExecutionManager
 * @notice This contract handles the execution and resolution of transactions. A transaction is executed on-chain
 *         when off-chain maker orders is matched by on-chain taker orders of a different kind.
 *         For instance, a taker ask is executed against a maker bid (or a taker bid against a maker ask).
 * @author LooksRare protocol team (👀,💎)
 */
contract ExecutionManager is
    CollectionDiscountManager,
    FeeManager,
    InheritedStrategies,
    StrategyManager,
    IExecutionManager
{
    /**
     * @notice Constructor
     * @param _royaltyFeeRegistry Royalty fee registry address
     */
    constructor(address _royaltyFeeRegistry) FeeManager(_royaltyFeeRegistry) {}

    /**
     * @notice Execute strategy for taker ask
     * @param takerAsk Taker ask struct (contains the taker ask-specific parameters for the execution of the transaction)
     * @param makerBid Maker bid struct (contains bid-specific parameter for the maker side of the transaction)
     */
    function _executeStrategyForTakerAsk(
        OrderStructs.TakerAsk calldata takerAsk,
        OrderStructs.MakerBid calldata makerBid
    )
        internal
        returns (
            uint256[] memory itemIds,
            uint256[] memory amounts,
            uint256 netPrice,
            uint256 protocolFeeAmount,
            address royaltyRecipient,
            uint256 royaltyFeeAmount
        )
    {
        uint256 price;
        (price, itemIds, amounts) = _executeStrategyHooksForTakerAsk(takerAsk, makerBid);

        (royaltyRecipient, royaltyFeeAmount) = _strategyInfo[makerBid.strategyId].hasRoyalties
            ? _getRoyaltyRecipientAndAmount(makerBid.collection, itemIds, price)
            : (address(0), 0);

        protocolFeeAmount =
            (((price * _strategyInfo[makerBid.strategyId].protocolFee) / 10000) *
                (10000 - collectionDiscountFactor[makerBid.collection])) /
            10000;

        netPrice = price - protocolFeeAmount - royaltyFeeAmount;

        if (netPrice < (price * takerAsk.minNetRatio) / 10000) revert SlippageAsk();
        if (netPrice < (price * makerBid.minNetRatio) / 10000) revert SlippageBid();
    }

    /**
     * @notice Execute strategy for taker bid
     * @param takerBid Taker bid struct (contains the taker bid-specific parameters for the execution of the transaction)
     * @param makerAsk Maker ask struct (contains ask-specific parameter for the maker side of the transaction)
     */
    function _executeStrategyForTakerBid(
        OrderStructs.TakerBid calldata takerBid,
        OrderStructs.MakerAsk calldata makerAsk
    )
        internal
        returns (
            uint256[] memory itemIds,
            uint256[] memory amounts,
            uint256 netPrice,
            uint256 protocolFeeAmount,
            address royaltyRecipient,
            uint256 royaltyFeeAmount
        )
    {
        uint256 price;
        (price, itemIds, amounts) = _executeStrategyHooksForTakerBid(takerBid, makerAsk);

        (royaltyRecipient, royaltyFeeAmount) = _strategyInfo[makerAsk.strategyId].hasRoyalties
            ? _getRoyaltyRecipientAndAmount(makerAsk.collection, itemIds, price)
            : (address(0), 0);

        protocolFeeAmount =
            (((price * _strategyInfo[makerAsk.strategyId].protocolFee) / 10000) *
                (10000 - collectionDiscountFactor[makerAsk.collection])) /
            10000;

        netPrice = price - royaltyFeeAmount - protocolFeeAmount;

        if (netPrice < (price * makerAsk.minNetRatio) / 10000) revert SlippageAsk();
        if (netPrice < (price * takerBid.minNetRatio) / 10000) revert SlippageBid();
    }

    /**
     * @notice Execute strategy hooks for takerBid
     * @param takerBid Taker bid struct (contains the taker bid-specific parameters for the execution of the transaction)
     * @param makerAsk Maker ask struct (contains ask-specific parameter for the maker side of the transaction)
     */
    function _executeStrategyHooksForTakerBid(
        OrderStructs.TakerBid calldata takerBid,
        OrderStructs.MakerAsk calldata makerAsk
    )
        internal
        returns (
            uint256 price,
            uint256[] memory itemIds,
            uint256[] memory amounts
        )
    {
        // Verify the order validity for timestamps
        _verifyOrderTimestampValidity(makerAsk.startTime, makerAsk.endTime);

        if (makerAsk.strategyId == 0) {
            (price, itemIds, amounts) = _executeStandardSaleStrategyWithTakerBid(takerBid, makerAsk);
        } else if (makerAsk.strategyId == 1) {
            // Collection offer is not available for taker bid
            revert StrategyNotAvailable(makerAsk.strategyId);
        } else {
            if (_strategyInfo[makerAsk.strategyId].isActive) {
                (price, itemIds, amounts) = IExecutionStrategy(_strategyInfo[makerAsk.strategyId].implementation)
                    .executeStrategyWithTakerBid(takerBid, makerAsk);
            } else {
                revert StrategyNotAvailable(makerAsk.strategyId);
            }
        }
    }

    /**
     * @notice Execute strategy hooks for takerAsk
     * @param takerAsk Taker ask struct (contains the taker ask-specific parameters for the execution of the transaction)
     * @param makerBid Maker bid struct (contains bid-specific parameter for the maker side of the transaction)
     */
    function _executeStrategyHooksForTakerAsk(
        OrderStructs.TakerAsk calldata takerAsk,
        OrderStructs.MakerBid calldata makerBid
    )
        internal
        returns (
            uint256 price,
            uint256[] memory itemIds,
            uint256[] memory amounts
        )
    {
        // Verify the order validity for timestamps
        _verifyOrderTimestampValidity(makerBid.startTime, makerBid.endTime);

        if (makerBid.strategyId == 0) {
            (price, itemIds, amounts) = _executeStandardSaleStrategyWithTakerAsk(takerAsk, makerBid);
        } else if (makerBid.strategyId == 1) {
            (price, itemIds, amounts) = _executeCollectionStrategyWithTakerAsk(takerAsk, makerBid);
        } else {
            if (_strategyInfo[makerBid.strategyId].isActive) {
                (price, itemIds, amounts) = IExecutionStrategy(_strategyInfo[makerBid.strategyId].implementation)
                    .executeStrategyWithTakerAsk(takerAsk, makerBid);
            } else {
                revert StrategyNotAvailable(makerBid.strategyId);
            }
        }
    }

    /**
     * @notice Verify order timestamp validity
     * @param startTime Start timestamp
     * @param endTime End timestamp
     */
    function _verifyOrderTimestampValidity(uint256 startTime, uint256 endTime) internal view {
        if (startTime > block.timestamp || endTime < block.timestamp) revert OutsideOfTimeRange();
    }
}
