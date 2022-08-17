// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import {IRoyaltyFeeRegistry} from "@looksrare/contracts-exchange-v1/contracts/interfaces/IRoyaltyFeeRegistry.sol";
import {IERC165} from "@looksrare/contracts-libs/contracts/interfaces/IERC165.sol";
import {IERC2981} from "@looksrare/contracts-libs/contracts/interfaces/IERC2981.sol";
import {OwnableTwoSteps} from "@looksrare/contracts-libs/contracts/OwnableTwoSteps.sol";

import {OrderStructs} from "./libraries/OrderStructs.sol";
import {IExecutionManager} from "./interfaces/IExecutionManager.sol";
import {IExecutionStrategy} from "./interfaces/IExecutionStrategy.sol";

/**
 * @title ExecutionManager
 * @notice This contract handles the execution and resolution of transactions. A transaction is executed on-chain when off-chain maker orders is matched by on-chain taker orders of a different kind (i.e., taker ask with maker bid or taker bid with maker ask).
 * @author LooksRare protocol team (👀,💎)
 */
contract ExecutionManager is IExecutionManager, OwnableTwoSteps {
    uint8 private immutable _COUNT_INTERNAL_STRATEGIES = 2;

    // Royalty fee registry
    IRoyaltyFeeRegistry internal _royaltyFeeRegistry;

    // Protocol fee recipient
    address internal _protocolFeeRecipient;

    // Track collection discount factors (e.g., 100 = 1%, 5000 = 50%) relative to strategy fee
    mapping(address => uint256) internal _collectionDiscountFactors;

    // Track strategy status and implementation
    mapping(uint16 => Strategy) internal _strategies;

    /**
     * @notice Constructor
     * @param royaltyFeeRegistry address of the royalty fee registry
     */
    constructor(address royaltyFeeRegistry) {
        _royaltyFeeRegistry = IRoyaltyFeeRegistry(royaltyFeeRegistry);
        _strategies[0] = Strategy({isActive: true, hasRoyalties: true, protocolFee: 200, implementation: address(0)});
        _strategies[1] = Strategy({isActive: true, hasRoyalties: true, protocolFee: 200, implementation: address(0)});
    }

    /**
     * @notice Execute strategy for taker ask
     * @param takerAsk takerAsk struct (contains the taker ask-specific parameters for the execution of the transaction)
     * @param makerBid makerBid struct (contains bid-specific parameter for the maker side of the transaction)
     * @param baseMaker baseMaker struct (contains base parameters for the maker side of the transaction)
     */
    function _executeStrategyForTakerAsk(
        OrderStructs.TakerAskOrder calldata takerAsk,
        OrderStructs.SingleMakerBidOrder calldata makerBid,
        OrderStructs.BaseMakerOrder calldata baseMaker
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
        (price, itemIds, amounts) = _executeStrategyHooksForTakerAsk(
            takerAsk,
            makerBid,
            baseMaker.collection,
            baseMaker.strategyId,
            baseMaker.startTime,
            baseMaker.endTime
        );

        (royaltyRecipient, royaltyFeeAmount) = _strategies[baseMaker.strategyId].hasRoyalties
            ? _getRoyaltyRecipientAndAmount(baseMaker.collection, itemIds, price)
            : (address(0), 0);

        protocolFeeAmount =
            (((price * _strategies[baseMaker.strategyId].protocolFee) / 10000) *
                (10000 - _collectionDiscountFactors[baseMaker.collection])) /
            10000;

        netPrice = price - protocolFeeAmount - royaltyFeeAmount;

        if (netPrice < (price * takerAsk.minNetRatio) / 10000) {
            revert AskSlippage();
        }
    }

    /**
     * @notice Execute strategy for taker bid
     * @param takerBid takerBid struct (contains the taker bid-specific parameters for the execution of the transaction)
     * @param makerAsk makerAsk struct (contains ask-specific parameter for the maker side of the transaction)
     * @param baseMaker baseMaker struct (contains base parameters for the maker side of the transaction)
     */
    function _executeStrategyForTakerBid(
        OrderStructs.TakerBidOrder calldata takerBid,
        OrderStructs.SingleMakerAskOrder calldata makerAsk,
        OrderStructs.BaseMakerOrder calldata baseMaker
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
        (price, itemIds, amounts) = _executeStrategyHooksForTakerBid(
            takerBid,
            makerAsk,
            baseMaker.collection,
            baseMaker.strategyId,
            baseMaker.startTime,
            baseMaker.endTime
        );

        (royaltyRecipient, royaltyFeeAmount) = _strategies[baseMaker.strategyId].hasRoyalties
            ? _getRoyaltyRecipientAndAmount(baseMaker.collection, itemIds, price)
            : (address(0), 0);

        protocolFeeAmount =
            (((price * _strategies[baseMaker.strategyId].protocolFee) / 10000) *
                (10000 - _collectionDiscountFactors[baseMaker.collection])) /
            10000;

        netPrice = price - royaltyFeeAmount - protocolFeeAmount;

        if (netPrice < (price * makerAsk.minNetRatio) / 10000) {
            revert AskSlippage();
        }
    }

    /**
     * @notice Execute strategy hooks for takerBid
     * @param takerBid takerBid struct (contains the taker bid-specific parameters for the execution of the transaction)
     * @param makerAsk makerAsk struct (contains ask-specific parameter for the maker side of the transaction)
     * @param collection address of the collection
     * @param strategyId id of the strategy
     * @param startTime start timestamp
     * @param endTime end timestamp
     */
    function _executeStrategyHooksForTakerBid(
        OrderStructs.TakerBidOrder calldata takerBid,
        OrderStructs.SingleMakerAskOrder calldata makerAsk,
        address collection,
        uint16 strategyId,
        uint256 startTime,
        uint256 endTime
    )
        internal
        returns (
            uint256 price,
            uint256[] memory itemIds,
            uint256[] memory amounts
        )
    {
        // Verify the order validity for timestamps
        _verifyOrderTimestampValidity(startTime, endTime);

        if (strategyId == 0) {
            (price, itemIds, amounts) = _executeStandardSaleStrategyWithTakerBid(takerBid, makerAsk);
        } else if (strategyId == 1) {
            // Collection offer is not available for taker bid
            revert StrategyNotAvailable(strategyId);
        } else {
            if (_strategies[strategyId].isActive) {
                (price, itemIds, amounts) = IExecutionStrategy(_strategies[strategyId].implementation)
                    .executeStrategyWithTakerBid(takerBid, makerAsk, collection, startTime, endTime);
            } else {
                revert StrategyNotAvailable(strategyId);
            }
        }
    }

    /**
     * @notice Execute strategy hooks for takerAsk
     * @param takerAsk takerAsk struct (contains the taker ask-specific parameters for the execution of the transaction)
     * @param makerBid makerBid struct (contains bid-specific parameter for the maker side of the transaction)
     * @param collection address of the collection
     * @param strategyId id of the strategy
     * @param startTime start timestamp
     * @param endTime end timestamp
     */
    function _executeStrategyHooksForTakerAsk(
        OrderStructs.TakerAskOrder calldata takerAsk,
        OrderStructs.SingleMakerBidOrder calldata makerBid,
        address collection,
        uint16 strategyId,
        uint256 startTime,
        uint256 endTime
    )
        internal
        returns (
            uint256 price,
            uint256[] memory itemIds,
            uint256[] memory amounts
        )
    {
        // Verify the order validity for timestamps
        _verifyOrderTimestampValidity(startTime, endTime);

        if (strategyId == 0) {
            (price, itemIds, amounts) = _executeStandardSaleStrategyWithTakerAsk(takerAsk, makerBid);
        } else if (strategyId == 1) {
            (price, itemIds, amounts) = _executeCollectionStrategyWithTakerAsk(takerAsk, makerBid);
        } else {
            if (_strategies[strategyId].isActive) {
                (price, itemIds, amounts) = IExecutionStrategy(_strategies[strategyId].implementation)
                    .executeStrategyWithTakerAsk(takerAsk, makerBid, collection, startTime, endTime);
            } else {
                revert StrategyNotAvailable(strategyId);
            }
        }
    }

    /**
     * @notice Execute standard sale strategy with takerBid
     * @param takerBid takerBid struct (contains the taker bid-specific parameters for the execution of the transaction)
     * @param makerAsk makerAsk struct (contains ask-specific parameter for the maker side of the transaction)
     * @dev It doesn't verify the items for takerBids match the ones from makerAsk
     */
    function _executeStandardSaleStrategyWithTakerBid(
        OrderStructs.TakerBidOrder calldata takerBid,
        OrderStructs.SingleMakerAskOrder calldata makerAsk
    )
        internal
        pure
        returns (
            uint256 price,
            uint256[] calldata itemIds,
            uint256[] calldata amounts
        )
    {
        price = makerAsk.minPrice;
        itemIds = makerAsk.itemIds;
        amounts = makerAsk.amounts;

        {
            bool canOrderBeExecuted = amounts.length != 0 &&
                itemIds.length == amounts.length &&
                price == takerBid.maxPrice;

            if (!canOrderBeExecuted) {
                revert OrderInvalid();
            }
        }
    }

    /**
     * @notice Execute standard sale strategy with takerAsk
     * @param takerAsk takerAsk struct (contains the taker ask-specific parameters for the execution of the transaction)
     * @param makerBid makerBid struct (contains bid-specific parameter for the maker side of the transaction)
     * @dev It doesn't verify the items for takerAsk match the ones from makerBid
     */
    function _executeStandardSaleStrategyWithTakerAsk(
        OrderStructs.TakerAskOrder calldata takerAsk,
        OrderStructs.SingleMakerBidOrder calldata makerBid
    )
        internal
        pure
        returns (
            uint256 price,
            uint256[] calldata itemIds,
            uint256[] calldata amounts
        )
    {
        price = makerBid.maxPrice;
        itemIds = makerBid.itemIds;
        amounts = makerBid.amounts;

        {
            bool canOrderBeExecuted = itemIds.length != 0 &&
                itemIds.length == amounts.length &&
                price == takerAsk.minPrice;

            if (!canOrderBeExecuted) {
                revert OrderInvalid();
            }
        }
    }

    /**
     * @notice Execute collection strategy with takerAsk
     * @param takerAsk takerAsk struct (contains the taker ask-specific parameters for the execution of the transaction)
     * @param makerBid makerBid struct (contains bid-specific parameter for the maker side of the transaction)
     */
    function _executeCollectionStrategyWithTakerAsk(
        OrderStructs.TakerAskOrder calldata takerAsk,
        OrderStructs.SingleMakerBidOrder calldata makerBid
    )
        internal
        pure
        returns (
            uint256 price,
            uint256[] calldata itemIds,
            uint256[] calldata amounts
        )
    {
        price = makerBid.maxPrice;
        itemIds = takerAsk.itemIds;
        amounts = makerBid.amounts;

        {
            bool canOrderBeExecuted = itemIds.length != 0 &&
                itemIds.length == amounts.length &&
                price == takerAsk.minPrice;

            if (!canOrderBeExecuted) {
                revert OrderInvalid();
            }
        }
    }

    /**
     * @notice Get royalty recipient and amount
     * @param collection address of the collection
     * @param itemIds array of itemIds
     * @param amount price amount of the sale
     */
    function _getRoyaltyRecipientAndAmount(
        address collection,
        uint256[] memory itemIds,
        uint256 amount
    ) internal view returns (address royaltyRecipient, uint256 royaltyAmount) {
        // Call registry
        (royaltyRecipient, royaltyAmount) = _royaltyFeeRegistry.royaltyInfo(collection, amount);

        // Try calling ERC2981 if it exists
        if (itemIds.length == 1 && royaltyRecipient == address(0) && royaltyAmount == 0) {
            if (IERC165(collection).supportsInterface(0x2a55205a)) {
                (royaltyRecipient, royaltyAmount) = IERC2981(collection).royaltyInfo(itemIds[0], amount);
            }
        }
    }

    /**
     * @notice Set protocol fee recipient
     * @param newProtocolFeeRecipient address of the new protocol fee recipient
     */
    function setProtocolFeeRecipient(address newProtocolFeeRecipient) external onlyOwner {
        _protocolFeeRecipient = newProtocolFeeRecipient;
        emit NewProtocolFeeRecipient(newProtocolFeeRecipient);
    }

    /**
     * @notice Add strategy
     * @param strategyId id of the new strategy
     * @param hasRoyalties whether the strategy has royalties
     * @param protocolFee protocol fee
     * @param implementation address of the implementation
     */
    function addStrategy(
        uint16 strategyId,
        bool hasRoyalties,
        uint8 protocolFee,
        address implementation
    ) external onlyOwner {
        if (strategyId < _COUNT_INTERNAL_STRATEGIES || _strategies[strategyId].implementation != address(0)) {
            revert StrategyUsed(strategyId);
        }

        _strategies[strategyId] = Strategy({
            isActive: true,
            hasRoyalties: hasRoyalties,
            protocolFee: protocolFee,
            implementation: implementation
        });

        emit NewStrategy(strategyId, implementation);
    }

    /**
     * @notice Add custom discount for collection
     * @param collection address of the collection
     * @param discountFactor discount factor (e.g., 1000 = -10% relative to the protocol fee)
     */
    function adjustDiscountFactorCollection(address collection, uint256 discountFactor) external onlyOwner {
        if (discountFactor >= 10000) {
            revert CollectionDiscountFactorTooHigh();
        }

        _collectionDiscountFactors[collection] = discountFactor;
        emit NewCollectionDiscountFactor(collection, discountFactor);
    }

    /**
     * @notice Remove strategy
     * @param strategyId id of the strategy
     */
    function removeStrategy(uint16 strategyId) external onlyOwner {
        if (
            strategyId < _COUNT_INTERNAL_STRATEGIES ||
            _strategies[strategyId].implementation == address(0) ||
            !_strategies[strategyId].isActive
        ) {
            revert StrategyNotUsed(strategyId);
        }

        _strategies[strategyId].isActive = false;

        emit StrategyRemoved(strategyId);
    }

    /**
     * @notice Reactivate removed strategy
     * @param strategyId id of the strategy
     */
    function reactivateStrategy(uint16 strategyId) external onlyOwner {
        if (
            strategyId < _COUNT_INTERNAL_STRATEGIES ||
            _strategies[strategyId].implementation == address(0) ||
            _strategies[strategyId].isActive
        ) {
            revert StrategyNotUsed(strategyId);
        }

        _strategies[strategyId].isActive = true;

        emit StrategyReactivated(strategyId);
    }

    /**
     * @notice Verify order timestamp validity
     * @param startTime start timestamp
     * @param endTime end timestamp
     */
    function _verifyOrderTimestampValidity(uint256 startTime, uint256 endTime) internal view {
        if (startTime > block.timestamp || endTime < block.timestamp) {
            revert OutsideOfTimeRange();
        }
    }

    /**
     * @notice View collection discount factor
     * @param collection address of the collection
     * @return collectionDiscountFactor collection discount factor (e.g., 500 --> 5% relative to protocol fee)
     */
    function viewCollectionDiscountFactor(address collection) external view returns (uint256 collectionDiscountFactor) {
        return _collectionDiscountFactors[collection];
    }

    /**
     * @notice View strategy information
     * @param strategyId id of the strategy
     * @return strategy parameters of the strategy (e.g., implementation address, protocol fee)
     */
    function viewStrategy(uint16 strategyId) external view returns (Strategy memory strategy) {
        return _strategies[strategyId];
    }
}
