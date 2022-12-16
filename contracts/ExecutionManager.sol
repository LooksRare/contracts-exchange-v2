// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

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

    // Maximum creator fee (in basis point)
    uint16 public maximumCreatorFeeBp = 1_000;

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
     * @notice Update the maximum creator fee (in bp)
     * @param newMaximumCreatorFeeBp New maximum creator fee (in basis point)
     * @dev The maximum value that can be set is 25%.
     */
    function setMaximumCreatorFeeBp(uint16 newMaximumCreatorFeeBp) external onlyOwner {
        if (newMaximumCreatorFeeBp > 2_500) revert CreatorFeeBpTooHigh();
        maximumCreatorFeeBp = newMaximumCreatorFeeBp;

        emit NewMaximumCreatorFeeBp(newMaximumCreatorFeeBp);
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
            address[3] memory recipients,
            uint256[3] memory fees,
            bool isNonceInvalidated
        )
    {
        uint256 price;

        (price, itemIds, amounts, isNonceInvalidated) = _executeStrategyHooksForTakerAsk(takerAsk, makerBid);

        {
            // 0 --> Creator fee and adjustment of protocol fee
            if (address(creatorFeeManager) != address(0)) {
                (recipients[1], fees[1]) = creatorFeeManager.viewCreatorFee(makerBid.collection, price, itemIds);
                if (fees[1] * 10_000 > (price * uint256(maximumCreatorFeeBp))) revert CreatorFeeBpTooHigh();
            }

            uint256 minTotalFee = (price * strategyInfo[makerBid.strategyId].minTotalFee) / 10_000;

            // 1 --> Protocol fee
            if (recipients[1] == address(0) || fees[1] == 0) {
                fees[0] = minTotalFee;
            } else {
                fees[0] = _calculateProtocolFee(price, makerBid.strategyId, fees[1], minTotalFee);
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
            address[3] memory recipients,
            uint256[3] memory fees,
            bool isNonceInvalidated
        )
    {
        uint256 price;

        (price, itemIds, amounts, isNonceInvalidated) = _executeStrategyHooksForTakerBid(takerBid, makerAsk);

        {
            // 0 --> Creator fee and adjustment of protocol fee
            if (address(creatorFeeManager) != address(0)) {
                (recipients[1], fees[1]) = creatorFeeManager.viewCreatorFee(makerAsk.collection, price, itemIds);
                if (fees[1] * 10_000 > (price * uint256(maximumCreatorFeeBp))) revert CreatorFeeBpTooHigh();
            }
            uint256 minTotalFee = (price * strategyInfo[makerAsk.strategyId].minTotalFee) / 10_000;

            // 1 --> Protocol fee
            if (recipients[1] == address(0) || fees[1] == 0) {
                fees[0] = minTotalFee;
            } else {
                fees[0] = _calculateProtocolFee(price, makerAsk.strategyId, fees[1], minTotalFee);
            }

            recipients[0] = protocolFeeRecipient;

            // 2 --> Amount for seller
            fees[2] = price - fees[1] - fees[0];
            recipients[2] = makerAsk.signer;
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
    ) internal returns (uint256 price, uint256[] memory itemIds, uint256[] memory amounts, bool isNonceInvalidated) {
        // Verify the order validity for timestamps
        _verifyOrderTimestampValidity(makerAsk.startTime, makerAsk.endTime);

        if (makerAsk.strategyId == 0) {
            (price, itemIds, amounts) = _executeStandardSaleStrategyWithTakerBid(takerBid, makerAsk);
            isNonceInvalidated = true;
        } else {
            if (strategyInfo[makerAsk.strategyId].isActive) {
                if (strategyInfo[makerAsk.strategyId].isMakerBid) revert NoSelectorForMakerAsk();

                bytes4 selector = strategyInfo[makerAsk.strategyId].selector;
                if (selector == bytes4(0)) revert NoSelectorForMakerAsk();

                (bool status, bytes memory data) = strategyInfo[makerAsk.strategyId].implementation.call(
                    abi.encodeWithSelector(selector, takerBid, makerAsk)
                );

                if (!status) {
                    assembly {
                        revert(add(data, 32), mload(data))
                    }
                }

                (price, itemIds, amounts, isNonceInvalidated) = abi.decode(data, (uint256, uint256[], uint256[], bool));
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
    ) internal returns (uint256 price, uint256[] memory itemIds, uint256[] memory amounts, bool isNonceInvalidated) {
        // Verify the order validity for timestamps
        _verifyOrderTimestampValidity(makerBid.startTime, makerBid.endTime);

        if (makerBid.strategyId == 0) {
            (price, itemIds, amounts) = _executeStandardSaleStrategyWithTakerAsk(takerAsk, makerBid);
            isNonceInvalidated = true;
        } else {
            if (strategyInfo[makerBid.strategyId].isActive) {
                if (!strategyInfo[makerBid.strategyId].isMakerBid) revert NoSelectorForMakerBid();

                bytes4 selector = strategyInfo[makerBid.strategyId].selector;
                if (selector == bytes4(0)) revert NoSelectorForMakerBid();

                (bool status, bytes memory data) = strategyInfo[makerBid.strategyId].implementation.call(
                    abi.encodeWithSelector(selector, takerAsk, makerBid)
                );

                if (!status) {
                    assembly {
                        revert(add(data, 32), mload(data))
                    }
                }

                (price, itemIds, amounts, isNonceInvalidated) = abi.decode(data, (uint256, uint256[], uint256[], bool));
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
        // if (startTime > block.timestamp || endTime < block.timestamp) revert OutsideOfTimeRange();
        assembly {
            if or(gt(startTime, timestamp()), lt(endTime, timestamp())) {
                mstore(0x00, 0x7476320f)
                revert(0x1c, 0x04)
            }
        }
    }

    function _calculateProtocolFee(
        uint256 price,
        uint256 strategyId,
        uint256 creatorFee,
        uint256 minTotalFee
    ) private view returns (uint256 protocolFee) {
        uint256 standardProtocolFee = (price * strategyInfo[strategyId].standardProtocolFee) / 10_000;

        if (creatorFee + standardProtocolFee > minTotalFee) {
            protocolFee = standardProtocolFee;
        } else {
            protocolFee = minTotalFee - creatorFee;
        }
    }
}
