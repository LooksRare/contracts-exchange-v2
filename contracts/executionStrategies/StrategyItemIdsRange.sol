// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Libraries
import {OrderStructs} from "../libraries/OrderStructs.sol";

// Shared errors
import {OrderInvalid, FunctionSelectorInvalid} from "../errors/SharedErrors.sol";

// Base strategy contracts
import {BaseStrategy} from "./BaseStrategy.sol";

/**
 * @title StrategyItemIdsRange
 * @notice This contract offers a single execution strategy for users to bid on
 *         a specific amount of items in a range bounded by 2 item ids.
 * @author LooksRare protocol team (👀,💎)
 */
contract StrategyItemIdsRange is BaseStrategy {
    /**
     * @notice This function validates the order under the context of the chosen strategy
     *         and returns the fulfillable items/amounts/price/nonce invalidation status.
     *         With this strategy, the bidder picks a item id range (e.g. 1-100)
     *         and a seller can fulfill the order with any tokens within the specified id range.
     * @param takerAsk Taker ask struct (taker ask-specific parameters for the execution)
     * @param makerBid Maker bid struct (maker bid-specific parameters for the execution)
     */
    function executeStrategyWithTakerAsk(
        OrderStructs.Taker calldata takerAsk,
        OrderStructs.MakerBid calldata makerBid
    )
        external
        pure
        returns (uint256 price, uint256[] memory itemIds, uint256[] memory amounts, bool isNonceInvalidated)
    {
        (itemIds, amounts) = abi.decode(takerAsk.additionalParameters, (uint256[], uint256[]));
        uint256 length = itemIds.length;
        if (length != amounts.length) {
            revert OrderInvalid();
        }

        (uint256 minItemId, uint256 maxItemId, uint256 desiredAmount) = abi.decode(
            makerBid.additionalParameters,
            (uint256, uint256, uint256)
        );

        if (minItemId >= maxItemId || desiredAmount == 0) {
            revert OrderInvalid();
        }

        uint256 totalOfferedAmount;
        uint256 lastItemId;

        for (uint256 i; i < length; ) {
            uint256 offeredItemId = itemIds[i];
            // Force the client to sort the item ids in ascending order,
            // in order to prevent taker ask from providing duplicated
            // item ids
            if (offeredItemId <= lastItemId) {
                if (i != 0) {
                    revert OrderInvalid();
                }
            }

            if (offeredItemId < minItemId || offeredItemId > maxItemId) {
                revert OrderInvalid();
            }

            totalOfferedAmount += amounts[i];

            lastItemId = offeredItemId;

            unchecked {
                ++i;
            }
        }

        if (totalOfferedAmount != desiredAmount) {
            revert OrderInvalid();
        }

        price = makerBid.maxPrice;
        isNonceInvalidated = true;
    }

    /**
     * @notice This function validates *only the maker* order under the context of the chosen strategy.
     *         It does not revert if the maker order is invalid.
     *         Instead it returns false and the error's 4 bytes selector.
     * @param makerBid Maker bid struct (maker bid-specific parameters for the execution)
     * @param functionSelector Function selector for the strategy
     * @return isValid Whether the maker struct is valid
     * @return errorSelector If isValid is false, it returns the error's 4 bytes selector
     */
    function isMakerBidValid(
        OrderStructs.MakerBid calldata makerBid,
        bytes4 functionSelector
    ) external pure returns (bool isValid, bytes4 errorSelector) {
        if (functionSelector != StrategyItemIdsRange.executeStrategyWithTakerAsk.selector) {
            return (isValid, FunctionSelectorInvalid.selector);
        }

        (uint256 minItemId, uint256 maxItemId, uint256 desiredAmount) = abi.decode(
            makerBid.additionalParameters,
            (uint256, uint256, uint256)
        );

        if (minItemId >= maxItemId || desiredAmount == 0) {
            return (isValid, OrderInvalid.selector);
        }

        isValid = true;
    }
}
