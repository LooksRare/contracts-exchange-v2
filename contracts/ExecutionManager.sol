// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// LooksRare unopinionated libraries
import {OwnableTwoSteps} from "@looksrare/contracts-libs/contracts/OwnableTwoSteps.sol";

// Libraries
import {OrderStructs} from "./libraries/OrderStructs.sol";

// Interfaces
import {IExecutionManager} from "./interfaces/IExecutionManager.sol";
import {ICreatorFeeManager} from "./interfaces/ICreatorFeeManager.sol";

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

    // Creator fee manager
    ICreatorFeeManager public creatorFeeManager;

    /**
     * @notice Set collection staking registry
     * @param newCreatorFeeManager Address of the creator fee manager
     * @dev Only callable by owner.
     */
    function setCreatorFeeManager(address newCreatorFeeManager) external onlyOwner {
        creatorFeeManager = ICreatorFeeManager(newCreatorFeeManager);
        emit NewCreatorFeeManager(newCreatorFeeManager);
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
            uint256[] memory fees,
            bool isNonceInvalidated
        )
    {
        uint256 price;

        recipients = new address[](3);
        fees = new uint256[](3);

        (price, itemIds, amounts, isNonceInvalidated) = _executeStrategyHooksForTakerAsk(takerAsk, makerBid);

        {
            // 0 --> Creator fee and adjustment of protocol fee
            (recipients[1], fees[1]) = creatorFeeManager.viewCreatorFee(makerBid.collection, price, itemIds);
            uint256 minTotalFee = (price * strategyInfo[makerBid.strategyId].minTotalFee) / 10000;

            // 1 --> Protocol fee
            if (recipients[1] == address(0) || fees[1] == 0) {
                fees[0] = minTotalFee;
            } else {
                uint256 standardProtocolFee = (price * strategyInfo[makerBid.strategyId].standardProtocolFee) / 10000;

                if (fees[1] + standardProtocolFee > minTotalFee) {
                    fees[0] = standardProtocolFee;
                } else {
                    fees[0] = minTotalFee - fees[1];
                }
            }

            recipients[0] = protocolFeeRecipient;

            // 2 --> Amount for seller
            fees[2] = price - fees[1] - fees[0];
            recipients[2] = takerAsk.recipient == address(0) ? sender : takerAsk.recipient;
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
            uint256[] memory fees,
            bool isNonceInvalidated
        )
    {
        uint256 price;

        recipients = new address[](3);
        fees = new uint256[](3);

        (price, itemIds, amounts, isNonceInvalidated) = _executeStrategyHooksForTakerBid(takerBid, makerAsk);

        {
            // 0 --> Creator fee and adjustment of protocol fee
            (recipients[1], fees[1]) = creatorFeeManager.viewCreatorFee(makerAsk.collection, price, itemIds);
            uint256 minTotalFee = (price * strategyInfo[makerAsk.strategyId].minTotalFee) / 10000;

            // 1 --> Protocol fee
            if (recipients[1] == address(0) || fees[1] == 0) {
                fees[0] = minTotalFee;
            } else {
                uint256 standardProtocolFee = (price * strategyInfo[makerAsk.strategyId].standardProtocolFee) / 10000;

                if (fees[1] + standardProtocolFee > minTotalFee) {
                    fees[0] = standardProtocolFee;
                } else {
                    fees[0] = minTotalFee - fees[1];
                }
            }

            recipients[0] = protocolFeeRecipient;

            // 2 --> Amount for seller
            fees[2] = price - fees[1] - fees[0];
            recipients[2] = makerAsk.recipient == address(0) ? makerAsk.signer : makerAsk.recipient;
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
            uint256[] memory amounts,
            bool isNonceInvalidated
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
            if (strategyInfo[makerAsk.strategyId].isActive) {
                bytes4 selector = strategyInfo[makerAsk.strategyId].selectorTakerBid;
                if (selector == bytes4(0)) revert NoSelectorForTakerBid();

                (bool status, bytes memory data) = strategyInfo[makerAsk.strategyId].implementation.call(
                    abi.encodeWithSelector(selector, takerBid, makerAsk)
                );

                if (!status) {
                    assembly {
                        revert(add(data, 32), mload(data))
                    }
                }

                (price, itemIds, amounts, isNonceInvalidated) = abi.decode(data, (uint256, uint256[], uint256[], bool));

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
            uint256[] memory amounts,
            bool isNonceInvalidated
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
            if (strategyInfo[makerBid.strategyId].isActive) {
                bytes4 selector = strategyInfo[makerBid.strategyId].selectorTakerAsk;
                if (selector == bytes4(0)) revert NoSelectorForTakerAsk();

                (bool status, bytes memory data) = strategyInfo[makerBid.strategyId].implementation.call(
                    abi.encodeWithSelector(selector, takerAsk, makerBid)
                );

                if (!status) {
                    assembly {
                        revert(add(data, 32), mload(data))
                    }
                }

                (price, itemIds, amounts, isNonceInvalidated) = abi.decode(data, (uint256, uint256[], uint256[], bool));

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
