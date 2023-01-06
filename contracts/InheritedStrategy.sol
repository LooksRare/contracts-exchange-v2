// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Libraries
import {OrderStructs} from "./libraries/OrderStructs.sol";

// Shared errors
import {OrderInvalid} from "./interfaces/SharedErrors.sol";

/**
 * @title InheritedStrategy
 * @notice This contract handles the verification of parameters for standard transactions.
 * @dev A standard transaction (bid or ask) is mapped to strategyId = 0.
 * @author LooksRare protocol team (👀,💎)
 */
contract InheritedStrategy {
    /**
     * @notice This function is internal and is used to validate the parameters for a standard sale strategy
     *         when the standard transaction is initiated by a taker bid.
     * @param takerBid Taker bid struct (contains the taker bid-specific parameters for the execution of the transaction)
     * @param makerAsk Maker ask struct (contains the maker ask-specific parameters for the execution of the transaction)
     */
    function _verifyStandardSaleStrategyWithTakerBid(
        OrderStructs.TakerBid calldata takerBid,
        OrderStructs.MakerAsk calldata makerAsk
    ) internal pure {
        uint256 targetLength = makerAsk.amounts.length;

        _verifyEqualLengthsAndMatchingPrice(
            targetLength,
            takerBid.amounts.length,
            makerAsk.itemIds.length,
            takerBid.itemIds.length,
            makerAsk.minPrice,
            takerBid.maxPrice
        );

        _verifyMatchingItemIdsAndAmounts(
            makerAsk.assetType,
            targetLength,
            makerAsk.amounts,
            takerBid.amounts,
            makerAsk.itemIds,
            takerBid.itemIds
        );
    }

    /**
     * @notice This function is internal and is used to validate the parameters for a standard sale strategy
     *         when the standard transaction is initiated by a taker ask.
     * @param takerAsk Taker ask struct (contains the taker ask-specific parameters for the execution of the transaction)
     * @param makerBid Maker bid struct (contains the maker bid-specific parameters for the execution of the transaction)
     */
    function _verifyStandardSaleStrategyWithTakerAsk(
        OrderStructs.TakerAsk calldata takerAsk,
        OrderStructs.MakerBid calldata makerBid
    ) internal pure {
        uint256 targetLength = makerBid.amounts.length;

        _verifyEqualLengthsAndMatchingPrice(
            targetLength,
            takerAsk.amounts.length,
            makerBid.itemIds.length,
            takerAsk.itemIds.length,
            makerBid.maxPrice,
            takerAsk.minPrice
        );

        _verifyMatchingItemIdsAndAmounts(
            makerBid.assetType,
            targetLength,
            makerBid.amounts,
            takerAsk.amounts,
            makerBid.itemIds,
            takerAsk.itemIds
        );
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
        ) {
            revert OrderInvalid();
        }
    }

    function _verifyMatchingItemIdsAndAmounts(
        uint256 assetType,
        uint256 length,
        uint256[] calldata amounts,
        uint256[] calldata counterpartyAmounts,
        uint256[] calldata itemIds,
        uint256[] calldata counterpartyItemIds
    ) private pure {
        for (uint256 i; i < length; ) {
            if ((amounts[i] != counterpartyAmounts[i]) || (itemIds[i] != counterpartyItemIds[i])) {
                revert OrderInvalid();
            }

            uint256 amount = amounts[i];

            if (amount != 1) {
                if (amount == 0) {
                    revert OrderInvalid();
                }
                if (assetType == 0) {
                    revert OrderInvalid();
                }
            }

            unchecked {
                ++i;
            }
        }
    }
}
