// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import {IRoyaltyFeeRegistry} from "@looksrare/contracts-exchange-v1/contracts/interfaces/IRoyaltyFeeRegistry.sol";
import {IERC165} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC165.sol";
import {IERC2981} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC2981.sol";
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
    // Maximum protocol fee
    uint16 private immutable _MAX_PROTOCOL_FEE = 5000;

    // Royalty fee registry
    IRoyaltyFeeRegistry internal _royaltyFeeRegistry;

    // Track collection discount factors (e.g., 100 = 1%, 5,000 = 50%) relative to strategy fee
    mapping(address => uint256) internal _collectionDiscountFactors;

    // Track strategy status and implementation
    mapping(uint16 => Strategy) internal _strategies;

    // Protocol fee recipient
    address internal _protocolFeeRecipient;

    // Count how many strategies exist (it includes strategies that have been removed)
    uint16 public countStrategies = 2;

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
     * @notice Add strategy
     * @param hasRoyalties whether the strategy has royalties
     * @param protocolFee protocol fee
     * @param maxProtocolFee protocol fee
     * @param implementation address of the implementation
     */
    function addStrategy(
        bool hasRoyalties,
        uint16 protocolFee,
        uint16 maxProtocolFee,
        address implementation
    ) external onlyOwner {
        if (maxProtocolFee < protocolFee || maxProtocolFee > _MAX_PROTOCOL_FEE) revert StrategyProtocolFeeTooHigh();

        _strategies[countStrategies] = Strategy({
            isActive: true,
            hasRoyalties: hasRoyalties,
            protocolFee: protocolFee,
            maxProtocolFee: maxProtocolFee,
            implementation: implementation
        });

        emit NewStrategy(countStrategies++, implementation);
    }

    /**
     * @notice Add custom discount for collection
     * @param collection address of the collection
     * @param discountFactor discount factor (e.g., 1000 = -10% relative to the protocol fee)
     */
    function adjustDiscountFactorCollection(address collection, uint256 discountFactor) external onlyOwner {
        if (discountFactor > 10000) revert CollectionDiscountFactorTooHigh();

        _collectionDiscountFactors[collection] = discountFactor;
        emit NewCollectionDiscountFactor(collection, discountFactor);
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
     * @notice Set royalty fee registry
     * @param newRoyaltyFeeRegistry address of the new royalty fee registry
     */
    function setRoyaltyFeeRegistry(address newRoyaltyFeeRegistry) external onlyOwner {
        _royaltyFeeRegistry = IRoyaltyFeeRegistry(newRoyaltyFeeRegistry);
        emit NewRoyaltyFeeRegistry(newRoyaltyFeeRegistry);
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
        if (strategyId >= countStrategies) revert StrategyNotUsed();
        if (protocolFee > _strategies[strategyId].maxProtocolFee) revert StrategyProtocolFeeTooHigh();

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

        if (netPrice < (price * takerAsk.minNetRatio) / 10000) revert SlippageAsk();
        if (netPrice < (price * makerBid.minNetRatio) / 10000) revert SlippageBid();
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

        if (netPrice < (price * makerAsk.minNetRatio) / 10000) revert SlippageAsk();
        if (netPrice < (price * takerBid.minNetRatio) / 10000) revert SlippageBid();
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

            if (!canOrderBeExecuted) revert OrderInvalid();
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

            if (!canOrderBeExecuted) revert OrderInvalid();
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

            if (!canOrderBeExecuted) revert OrderInvalid();
        }
    }

    /**
     * @notice Get royalty recipient and amount for a collection, set of itemIds, and gross sale amount.
     * @param collection address of the collection
     * @param itemIds array of itemIds
     * @param amount price amount of the sale
     * @return royaltyRecipient address of the royalty recipient
     * @return royaltyAmount amount to pay in royalties to the royalty recipient
     * @dev There are two onchain sources for the royalty fee to distribute.
     *      1. RoyaltyFeeRegistry: It is an onchain registry where royalty fee is defined across all items of a collection.
     *      2. ERC2981: The NFT Royalty Standard where royalty fee is defined at a tokenId level for each item of a collection.
     *      The onchain logic looks up the registry first. If it doesn't find anything, it checks if a collection is ERC2981.
     *      If so, it fetches the proper royalty information for the itemId.
     *      For a bundle that contains multiple itemIds (for a collection using ERC2981), if the royalty fee/recipient differ among the itemIds
     *      part of the bundle, the trade reverts.
     */
    function _getRoyaltyRecipientAndAmount(
        address collection,
        uint256[] memory itemIds,
        uint256 amount
    ) internal view returns (address royaltyRecipient, uint256 royaltyAmount) {
        // 1. Royalty fee registry
        (royaltyRecipient, royaltyAmount) = _royaltyFeeRegistry.royaltyInfo(collection, amount);

        // 2. ERC2981 logic
        if (royaltyRecipient == address(0) && royaltyAmount == 0) {
            (bool status, bytes memory data) = collection.staticcall(
                abi.encodeWithSelector(IERC2981.royaltyInfo.selector, itemIds[0], amount)
            );

            if (status) {
                (royaltyRecipient, royaltyAmount) = abi.decode(data, (address, uint256));
            }

            // Specific logic if bundle
            if (status && itemIds.length > 1) {
                for (uint256 i = 1; i < itemIds.length; ) {
                    (address royaltyRecipientForToken, uint256 royaltyAmountForToken) = IERC2981(collection)
                        .royaltyInfo(itemIds[i], amount);

                    if (royaltyRecipientForToken != royaltyRecipient || royaltyAmount != royaltyAmountForToken)
                        revert BundleEIP2981NotAllowed(collection, itemIds);

                    unchecked {
                        ++i;
                    }
                }
            }
        }
    }

    /**
     * @notice Verify order timestamp validity
     * @param startTime start timestamp
     * @param endTime end timestamp
     */
    function _verifyOrderTimestampValidity(uint256 startTime, uint256 endTime) internal view {
        if (startTime > block.timestamp || endTime < block.timestamp) revert OutsideOfTimeRange();
    }
}
