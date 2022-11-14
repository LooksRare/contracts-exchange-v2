// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// LooksRare unopinionated libraries
import {OwnableTwoSteps} from "@looksrare/contracts-libs/contracts/OwnableTwoSteps.sol";

// Libraries
import {OrderStructs} from "./libraries/OrderStructs.sol";

// Interfaces
import {IExecutionManager} from "./interfaces/IExecutionManager.sol";
import {IExecutionStrategy} from "./interfaces/IExecutionStrategy.sol";
import {ICollectionStakingRegistry} from "./interfaces/ICollectionStakingRegistry.sol";

// Direct dependencies
import {InheritedStrategies} from "./InheritedStrategies.sol";
import {NonceManager} from "./NonceManager.sol";
import {StrategyManager} from "./StrategyManager.sol";

/**
 * @title ExecutionManager
 * @notice This contract handles the execution and resolution of transactions. A transaction is executed on-chain
 *         when off-chain maker orders is matched by on-chain taker orders of a different kind.
 *         For instance, a taker ask is executed against a maker bid (or a taker bid against a maker ask).
 * @author LooksRare protocol team (👀,💎)
 */
contract ExecutionManager is InheritedStrategies, NonceManager, StrategyManager, IExecutionManager {
    // Protocol fee recipient
    address public protocolFeeRecipient;

    // Collection staking registry
    ICollectionStakingRegistry public collectionStakingRegistry;

    /**
     * @notice Set collection staking registry
     * @param newCollectionStakingRegistry Address of the collection staking registry
     * @dev Only callable by owner.
     */
    function setCollectionStakingRegistry(address newCollectionStakingRegistry) external onlyOwner {
        collectionStakingRegistry = ICollectionStakingRegistry(newCollectionStakingRegistry);
        emit NewCollectionStakingRegistry(newCollectionStakingRegistry);
    }

    /**
     * @notice Set protocol fee recipient
     * @param newProtocolFeeRecipient New protocol fee recipient address
     */
    function setProtocolFeeRecipient(address newProtocolFeeRecipient) external onlyOwner {
        protocolFeeRecipient = newProtocolFeeRecipient;
        emit NewProtocolFeeRecipient(newProtocolFeeRecipient);
    }

    /**
     * @notice Execute strategy for taker ask
     * @param takerAsk Taker ask struct (contains the taker ask-specific parameters for the execution of the transaction)
     * @param makerBid Maker bid struct (contains bid-specific parameter for the maker side of the transaction)
     */
    function _executeStrategyForTakerAsk(
        OrderStructs.TakerAsk calldata takerAsk,
        OrderStructs.MakerBid calldata makerBid,
        address sender
    )
        internal
        returns (
            uint256[] memory itemIds,
            uint256[] memory amounts,
            address[] memory recipients,
            uint256[] memory fees
        )
    {
        uint256 price;

        recipients = new address[](3);
        fees = new uint256[](3);

        (price, itemIds, amounts) = _executeStrategyHooksForTakerAsk(takerAsk, makerBid);

        {
            // 0 -> Protocol fee
            fees[0] = (price * _strategyInfo[makerBid.strategyId].standardProtocolFee) / 10000;
            recipients[0] = protocolFeeRecipient;

            // 1 --> Amount for seller
            fees[2] = price - fees[0];
            recipients[2] = takerAsk.recipient == address(0) ? sender : takerAsk.recipient;

            // 2 --> Rebate and adjustment of protocol fee
            uint16 rebateBp;
            (recipients[1], rebateBp) = collectionStakingRegistry.viewProtocolFeeRebate(makerBid.collection);
            fees[1] = (rebateBp * fees[0]) / 10000;
            fees[0] -= fees[1];
        }
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
            address[] memory recipients,
            uint256[] memory fees
        )
    {
        uint256 price;

        recipients = new address[](3);
        fees = new uint256[](3);

        (price, itemIds, amounts) = _executeStrategyHooksForTakerBid(takerBid, makerAsk);

        {
            // 0 -> Protocol fee
            fees[0] = (price * _strategyInfo[makerAsk.strategyId].standardProtocolFee) / 10000;
            recipients[0] = protocolFeeRecipient;

            // 1 --> Amount for seller
            fees[2] = price - fees[0];
            recipients[2] = makerAsk.recipient == address(0) ? makerAsk.signer : makerAsk.recipient;

            // 2 --> Rebate and adjustment of protocol fee
            uint16 rebateBp;
            (recipients[1], rebateBp) = collectionStakingRegistry.viewProtocolFeeRebate(makerAsk.collection);
            fees[1] = (rebateBp * fees[0]) / 10000;
            fees[0] -= fees[1];
        }
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
            userOrderNonce[makerAsk.signer][makerAsk.orderNonce] = true;
        } else if (makerAsk.strategyId == 1) {
            // Collection offer is not available for taker bid
            revert StrategyNotAvailable(makerAsk.strategyId);
        } else {
            if (_strategyInfo[makerAsk.strategyId].isActive) {
                bool isNonceInvalidated;

                (price, itemIds, amounts, isNonceInvalidated) = IExecutionStrategy(
                    _strategyInfo[makerAsk.strategyId].implementation
                ).executeStrategyWithTakerBid(takerBid, makerAsk);

                if (isNonceInvalidated) {
                    // Invalidate order at this nonce for future execution
                    userOrderNonce[makerAsk.signer][makerAsk.orderNonce] = true;
                }
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
            userOrderNonce[makerBid.signer][makerBid.orderNonce] = true;
        } else if (makerBid.strategyId == 1) {
            (price, itemIds, amounts) = _executeCollectionStrategyWithTakerAsk(takerAsk, makerBid);
            userOrderNonce[makerBid.signer][makerBid.orderNonce] = true;
        } else {
            if (_strategyInfo[makerBid.strategyId].isActive) {
                bool isNonceInvalidated;
                (price, itemIds, amounts, isNonceInvalidated) = IExecutionStrategy(
                    _strategyInfo[makerBid.strategyId].implementation
                ).executeStrategyWithTakerAsk(takerAsk, makerBid);

                if (isNonceInvalidated) {
                    // Invalidate order at this nonce for future execution
                    userOrderNonce[makerBid.signer][makerBid.orderNonce] = true;
                }
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
