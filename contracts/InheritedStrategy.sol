// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Libraries
import {OrderStructs} from "./libraries/OrderStructs.sol";

// Shared errors
import {OrderInvalid} from "./interfaces/SharedErrors.sol";

// Assembly
import {OrderInvalid_error_selector, OrderInvalid_error_length, Error_selector_offset, OneWord} from "./constants/StrategyConstants.sol";

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
     * @param takerBid Taker bid struct (taker bid-specific parameters for the execution)
     * @param makerAsk Maker ask struct (maker ask-specific parameters for the execution)
     */
    function _verifyStandardSaleStrategyWithTakerBid(
        OrderStructs.TakerBid calldata takerBid,
        OrderStructs.MakerAsk calldata makerAsk
    ) internal pure {
        _verifyMatchingItemIdsAndAmountsAndPrice(
            makerAsk.assetType,
            makerAsk.amounts,
            takerBid.amounts,
            makerAsk.itemIds,
            takerBid.itemIds,
            makerAsk.minPrice,
            takerBid.maxPrice
        );
    }

    /**
     * @notice This function is internal and is used to validate the parameters for a standard sale strategy
     *         when the standard transaction is initiated by a taker ask.
     * @param takerAsk Taker ask struct (taker ask-specific parameters for the execution)
     * @param makerBid Maker bid struct (maker bid-specific parameters for the execution)
     */
    function _verifyStandardSaleStrategyWithTakerAsk(
        OrderStructs.TakerAsk calldata takerAsk,
        OrderStructs.MakerBid calldata makerBid
    ) internal pure {
        _verifyMatchingItemIdsAndAmountsAndPrice(
            makerBid.assetType,
            makerBid.amounts,
            takerAsk.amounts,
            makerBid.itemIds,
            takerAsk.itemIds,
            makerBid.maxPrice,
            takerAsk.minPrice
        );
    }

    function _verifyMatchingItemIdsAndAmountsAndPrice(
        uint256 assetType,
        uint256[] calldata amounts,
        uint256[] calldata counterpartyAmounts,
        uint256[] calldata itemIds,
        uint256[] calldata counterpartyItemIds,
        uint256 price,
        uint256 counterpartyPrice
    ) private pure {
        assembly {
            let end
            {
                /*
                 * @dev If A == B, then A XOR B == 0. So if all 4 lengths are equal, it should be 0 | 0 | 0 == 0
                 *
                 * if (
                 *     amountsLength == 0 ||
                 *     price != counterpartyPrice ||
                 *     ((amountsLength ^ itemIdsLength) |
                 *         (amountsLength ^ counterpartyAmountsLength) |
                 *         (amountsLength ^ counterpartyItemIdsLength)) !=
                 *     0
                 * ) {
                 *     revert OrderInvalid();
                 * }
                 */
                let amountsLength := amounts.length
                let itemIdsLength := itemIds.length
                let counterpartyAmountsLength := counterpartyAmounts.length
                let counterpartyItemIdsLength := counterpartyItemIds.length

                if or(
                    or(iszero(amountsLength), xor(price, counterpartyPrice)),
                    or(
                        or(xor(amountsLength, itemIdsLength), xor(amountsLength, counterpartyAmountsLength)),
                        xor(amountsLength, counterpartyItemIdsLength)
                    )
                ) {
                    mstore(0x00, OrderInvalid_error_selector)
                    revert(Error_selector_offset, OrderInvalid_error_length)
                }

                /**
                 * @dev Shifting left 5 times is equivalent to amountsLength * 32 bytes
                 */
                end := shl(5, amountsLength)
            }

            let _assetType := assetType
            let amountsOffset := amounts.offset
            let itemIdsOffset := itemIds.offset
            let counterpartyAmountsOffset := counterpartyAmounts.offset
            let counterpartyItemIdsOffset := counterpartyItemIds.offset

            for {

            } end {

            } {
                /**
                 * @dev Starting from the end of the array minus 32 bytes to load the last item,
                 *      ending with `end` equal to 0 to load the first item
                 *
                 * uint256 end = amountsLength;
                 *
                 * for (uint256 i = end - 1; i >= 0; i--) {
                 *   uint256 amount = amounts[i];
                 *   uint256 itemId = itemIds[i];
                 *
                 *   uint256 counterpartyAmount = counterpartyAmounts[i];
                 *   uint256 counterpartyItemId = counterpartyItemIds[i];
                 *
                 *   if (amount != counterpartyAmount || itemId != counterpartyItemId) {
                 *      revert OrderInvalid();
                 *   };
                 * }
                 */
                end := sub(end, OneWord)

                let amount := calldataload(add(amountsOffset, end))
                let invalidOrder

                {
                    let itemId := calldataload(add(itemIdsOffset, end))
                    let counterpartyAmount := calldataload(add(counterpartyAmountsOffset, end))
                    let counterpartyItemId := calldataload(add(counterpartyItemIdsOffset, end))

                    invalidOrder := or(xor(amount, counterpartyAmount), xor(itemId, counterpartyItemId))
                }

                /**
                 * @dev This is equivalent to
                 *
                 * if (amount != 1) {
                 *   if (amount == 0) {
                 *      revert OrderInvalid();
                 *   }
                 *
                 *   if (_assetType == 0) {
                 *      revert OrderInvalid();
                 *   }
                 * }
                 */
                invalidOrder := or(invalidOrder, or(iszero(amount), and(xor(amount, 1), iszero(_assetType))))

                if invalidOrder {
                    mstore(0x00, OrderInvalid_error_selector)
                    revert(Error_selector_offset, OrderInvalid_error_length)
                }
            }
        }
    }
}
