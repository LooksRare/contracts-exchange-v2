// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Libraries
import {OrderStructs} from "./libraries/OrderStructs.sol";

/**
 * @title InheritedStrategies
 * @notice This contract handles the execution of inherited strategies.
 *         - StrategyId = 0 --> Standard Order
 * @author LooksRare protocol team (👀,💎)
 */
contract InheritedStrategies {
    // Custom errors
    error OrderInvalid();

    /**
     * @notice Execute standard sale strategy with taker bid order
     * @param takerBid Taker bid struct (contains the taker bid-specific parameters for the execution of the transaction)
     * @param makerAsk Maker ask struct (contains the maker ask-specific parameters for the execution of the transaction)
     */
    function _executeStandardSaleStrategyWithTakerBid(
        OrderStructs.TakerBid calldata takerBid,
        OrderStructs.MakerAsk calldata makerAsk
    ) internal pure returns (uint256 price, uint256[] calldata itemIds, uint256[] calldata amounts) {
        price = makerAsk.minPrice;
        itemIds = makerAsk.itemIds;
        amounts = makerAsk.amounts;

        uint256 targetLength = amounts.length;

        _verifyEqualLengthsAndMatchingPrice(
            targetLength,
            takerBid.amounts.length,
            itemIds.length,
            takerBid.itemIds.length,
            price,
            takerBid.maxPrice
        );

        _verifyMatchingItemIdsAndAmounts(targetLength, amounts, takerBid.amounts, itemIds, takerBid.itemIds);
    }

    /**
     * @notice Execute standard sale strategy with taker ask order
     * @param takerAsk Taker ask struct (contains the taker ask-specific parameters for the execution of the transaction)
     * @param makerBid Maker bid struct (contains the maker bid-specific parameters for the execution of the transaction)
     */
    function _executeStandardSaleStrategyWithTakerAsk(
        OrderStructs.TakerAsk calldata takerAsk,
        OrderStructs.MakerBid calldata makerBid
    ) internal pure returns (uint256 price, uint256[] calldata itemIds, uint256[] calldata amounts) {
        price = makerBid.maxPrice;
        itemIds = makerBid.itemIds;
        amounts = makerBid.amounts;

        uint256 targetLength = amounts.length;

        _verifyEqualLengthsAndMatchingPrice(
            targetLength,
            takerAsk.amounts.length,
            itemIds.length,
            takerAsk.itemIds.length,
            price,
            takerAsk.minPrice
        );

        _verifyMatchingItemIdsAndAmounts(targetLength, amounts, takerAsk.amounts, itemIds, takerAsk.itemIds);
    }

    function _verifyEqualLengthsAndMatchingPrice(
        uint256 amountsLength,
        uint256 counterpartyAmountsLength,
        uint256 itemIdsLength,
        uint256 counterpartyItemIdsLength,
        uint256 price,
        uint256 counterpartyPrice
    ) private pure {
        if (
            amountsLength == 0 ||
            // If A == B, then A XOR B == 0. So if all 4 are equal, it should be 0 | 0 | 0 == 0
            ((amountsLength ^ itemIdsLength) |
                (counterpartyItemIdsLength ^ counterpartyAmountsLength) |
                (amountsLength ^ counterpartyItemIdsLength)) !=
            0 ||
            price != counterpartyPrice
        ) revert OrderInvalid();
    }

    function _verifyMatchingItemIdsAndAmounts(
        uint256 length,
        uint256[] calldata amounts,
        uint256[] calldata counterpartyAmounts,
        uint256[] calldata itemIds,
        uint256[] calldata counterpartyItemIds
    ) private pure {
        for (uint256 i; i < length; ) {
            if ((amounts[i] != counterpartyAmounts[i]) || amounts[i] == 0 || (itemIds[i] != counterpartyItemIds[i]))
                revert OrderInvalid();

            unchecked {
                ++i;
            }
        }
    }
}
