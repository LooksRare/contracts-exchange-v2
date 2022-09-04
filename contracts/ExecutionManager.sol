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
 * @notice This contract handles the execution and resolution of transactions. A transaction is executed on-chain
 *         when off-chain maker orders is matched by on-chain taker orders of a different kind.
 *         For instance, a taker ask is executed against a maker bid (and a taker bid against a maker ask).
 * @author LooksRare protocol team (👀,💎)
 */
contract ExecutionManager is IExecutionManager, OwnableTwoSteps {
    // Number of internal strategies
    uint8 private immutable _COUNT_INTERNAL_STRATEGIES = 2;

    // Maximum protocol fee
    uint16 private immutable _MAX_PROTOCOL_FEE = 5000;

    // Royalty fee registry
    IRoyaltyFeeRegistry internal _royaltyFeeRegistry;

    // Protocol fee recipient
    address internal _protocolFeeRecipient;

    // Track collection discount factors (e.g., 100 = 1%, 5,000 = 50%) relative to strategy fee
    mapping(address => uint256) internal _collectionDiscountFactors;

    // Track strategy status and implementation
    mapping(uint16 => Strategy) internal _strategies;

    /**
     * @notice Constructor
     * @param royaltyFeeRegistry address of the royalty fee registry
     */
    constructor(address royaltyFeeRegistry) {
        _royaltyFeeRegistry = IRoyaltyFeeRegistry(royaltyFeeRegistry);
        _strategies[0] = Strategy({
            isActive: true,
            hasRoyalties: true,
            protocolFee: 200,
            maxProtocolFee: 300,
            implementation: address(0)
        });
        _strategies[1] = Strategy({
            isActive: true,
            hasRoyalties: true,
            protocolFee: 200,
            maxProtocolFee: 300,
            implementation: address(0)
        });
    }

    /**
     * @notice Execute strategy for taker ask
     * @param takerAsk takerAsk struct (contains the taker ask-specific parameters for the execution of the transaction)
     * @param makerBid makerBid struct (contains bid-specific parameter for the maker side of the transaction)
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

        (royaltyRecipient, royaltyFeeAmount) = _strategies[makerBid.strategyId].hasRoyalties
            ? _getRoyaltyRecipientAndAmount(makerBid.collection, itemIds, price)
            : (address(0), 0);

        protocolFeeAmount =
            (((price * _strategies[makerBid.strategyId].protocolFee) / 10000) *
                (10000 - _collectionDiscountFactors[makerBid.collection])) /
            10000;

        netPrice = price - protocolFeeAmount - royaltyFeeAmount;

        if (netPrice < (price * takerAsk.minNetRatio) / 10000) {
            revert SlippageAsk();
        } else if (netPrice < (price * makerBid.minNetRatio) / 10000) {
            revert SlippageBid();
        }
    }

    /**
     * @notice Execute strategy for taker bid
     * @param takerBid takerBid struct (contains the taker bid-specific parameters for the execution of the transaction)
     * @param makerAsk makerAsk struct (contains ask-specific parameter for the maker side of the transaction)
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

        (royaltyRecipient, royaltyFeeAmount) = _strategies[makerAsk.strategyId].hasRoyalties
            ? _getRoyaltyRecipientAndAmount(makerAsk.collection, itemIds, price)
            : (address(0), 0);

        protocolFeeAmount =
            (((price * _strategies[makerAsk.strategyId].protocolFee) / 10000) *
                (10000 - _collectionDiscountFactors[makerAsk.collection])) /
            10000;

        netPrice = price - royaltyFeeAmount - protocolFeeAmount;

        if (netPrice < (price * makerAsk.minNetRatio) / 10000) {
            revert SlippageAsk();
        } else if (netPrice < (price * takerBid.minNetRatio) / 10000) {
            revert SlippageBid();
        }
    }

    /**
     * @notice Execute strategy hooks for takerBid
     * @param takerBid takerBid struct (contains the taker bid-specific parameters for the execution of the transaction)
     * @param makerAsk makerAsk struct (contains ask-specific parameter for the maker side of the transaction)
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
            if (_strategies[makerAsk.strategyId].isActive) {
                (price, itemIds, amounts) = IExecutionStrategy(_strategies[makerAsk.strategyId].implementation)
                    .executeStrategyWithTakerBid(takerBid, makerAsk);
            } else {
                revert StrategyNotAvailable(makerAsk.strategyId);
            }
        }
    }

    /**
     * @notice Execute strategy hooks for takerAsk
     * @param takerAsk takerAsk struct (contains the taker ask-specific parameters for the execution of the transaction)
     * @param makerBid makerBid struct (contains bid-specific parameter for the maker side of the transaction)
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
            if (_strategies[makerBid.strategyId].isActive) {
                (price, itemIds, amounts) = IExecutionStrategy(_strategies[makerBid.strategyId].implementation)
                    .executeStrategyWithTakerAsk(takerAsk, makerBid);
            } else {
                revert StrategyNotAvailable(makerBid.strategyId);
            }
        }
    }

    /**
     * @notice Execute standard sale strategy with takerBid
     * @param takerBid takerBid struct (contains the taker bid-specific parameters for the execution of the transaction)
     * @param makerAsk makerAsk struct (contains ask-specific parameter for the maker side of the transaction)
     */
    function _executeStandardSaleStrategyWithTakerBid(
        OrderStructs.TakerBid calldata takerBid,
        OrderStructs.MakerAsk calldata makerAsk
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

        uint256 targetLength = amounts.length;

        {
            bool canOrderBeExecuted = targetLength != 0 &&
                itemIds.length == targetLength &&
                takerBid.itemIds.length == targetLength &&
                takerBid.amounts.length == targetLength &&
                price == takerBid.maxPrice;

            if (canOrderBeExecuted) {
                for (uint256 i; i < targetLength; ) {
                    if ((takerBid.amounts[i] != amounts[i]) || amounts[i] == 0 || (takerBid.itemIds[i] != itemIds[i])) {
                        canOrderBeExecuted = false;
                        // Exit loop if false
                        break;
                    }

                    unchecked {
                        ++i;
                    }
                }
            }

            if (!canOrderBeExecuted) {
                revert OrderInvalid();
            }
        }
    }

    /**
     * @notice Execute standard sale strategy with takerAsk
     * @param takerAsk takerAsk struct (contains the taker ask-specific parameters for the execution of the transaction)
     * @param makerBid makerBid struct (contains bid-specific parameter for the maker side of the transaction)
     */
    function _executeStandardSaleStrategyWithTakerAsk(
        OrderStructs.TakerAsk calldata takerAsk,
        OrderStructs.MakerBid calldata makerBid
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

        uint256 targetLength = amounts.length;

        {
            bool canOrderBeExecuted = targetLength != 0 &&
                itemIds.length == targetLength &&
                takerAsk.itemIds.length == targetLength &&
                takerAsk.amounts.length == targetLength &&
                price == takerAsk.minPrice;

            if (canOrderBeExecuted) {
                for (uint256 i; i < targetLength; ) {
                    if ((takerAsk.amounts[i] != amounts[i]) || amounts[i] == 0 || (takerAsk.itemIds[i] != itemIds[i])) {
                        canOrderBeExecuted = false;
                        // Exit loop if false
                        break;
                    }

                    unchecked {
                        ++i;
                    }
                }
            }

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
        OrderStructs.TakerAsk calldata takerAsk,
        OrderStructs.MakerBid calldata makerBid
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

        // A collection order can only be executable for 1 itemId but quantity to fill can vary
        {
            bool canOrderBeExecuted = itemIds.length == 1 &&
                amounts.length == 1 &&
                price == takerAsk.minPrice &&
                takerAsk.amounts[0] == amounts[0] &&
                amounts[0] > 0;

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
     * @param maxProtocolFee protocol fee
     * @param implementation address of the implementation
     */
    function addStrategy(
        uint16 strategyId,
        bool hasRoyalties,
        uint16 protocolFee,
        uint16 maxProtocolFee,
        address implementation
    ) external onlyOwner {
        if (strategyId < _COUNT_INTERNAL_STRATEGIES || _strategies[strategyId].implementation != address(0)) {
            revert StrategyUsed(strategyId);
        }

        if (maxProtocolFee < protocolFee || maxProtocolFee > _MAX_PROTOCOL_FEE) {
            revert StrategyProtocolFeeTooHigh(strategyId);
        }

        _strategies[strategyId] = Strategy({
            isActive: true,
            hasRoyalties: hasRoyalties,
            protocolFee: protocolFee,
            maxProtocolFee: maxProtocolFee,
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
        if (discountFactor > 10000) {
            revert CollectionDiscountFactorTooHigh();
        }

        _collectionDiscountFactors[collection] = discountFactor;
        emit NewCollectionDiscountFactor(collection, discountFactor);
    }

    /**
     * @notice Update strategy
     * @param strategyId id of the strategy
     * @param hasRoyalties whether the strategy should distribute royalties
     * @param protocolFee protocol fee
     * @param isActive whether the strategy is active
     */
    function updateStrategy(
        uint16 strategyId,
        bool hasRoyalties,
        uint16 protocolFee,
        bool isActive
    ) external onlyOwner {
        if (strategyId > _COUNT_INTERNAL_STRATEGIES && _strategies[strategyId].implementation == address(0)) {
            revert StrategyNotUsed(strategyId);
        }

        if (protocolFee > _strategies[strategyId].maxProtocolFee) {
            revert StrategyProtocolFeeTooHigh(strategyId);
        }

        _strategies[strategyId] = Strategy({
            isActive: isActive,
            hasRoyalties: hasRoyalties,
            protocolFee: protocolFee,
            maxProtocolFee: _strategies[strategyId].maxProtocolFee,
            implementation: _strategies[strategyId].implementation
        });

        emit StrategyUpdated(strategyId, isActive, hasRoyalties, protocolFee);
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
}
