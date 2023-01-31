// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Libraries
import {OrderStructs} from "./libraries/OrderStructs.sol";

// Shared errors
import {OrderInvalid} from "./errors/SharedErrors.sol";

// Assembly
import {OrderInvalid_error_selector, OrderInvalid_error_length, Error_selector_offset, OneWord} from "./constants/StrategyConstants.sol";

/**
 * @title InheritedStrategy
 * @notice This contract handles the verification of parameters for standard transactions.
 *         We do not verify the taker struct's itemIds and amounts array as well as
 *         minPrice (taker ask) / maxPrice (taker bid) because before the taker executes the
 *         transaction, the maker itemIds/amounts/price should have already been seen and
 *         confirmed off-chain.
 * @dev A standard transaction (bid or ask) is mapped to strategyId = 0.
 * @author LooksRare protocol team (👀,💎)
 */
contract InheritedStrategy {
    /**
     * @notice This function is internal and is used to validate the parameters for a standard sale strategy
     *         when the standard transaction is initiated by a taker bid.
     * @param makerAsk Maker ask struct (maker ask-specific parameters for the execution)
     */
    function _verifyStandardSaleStrategyWithMakerAsk(OrderStructs.MakerAsk calldata makerAsk) internal pure {
        _verifyItemIdsAndAmountsEqualLengthsAndValidAmounts(makerAsk.assetType, makerAsk.amounts, makerAsk.itemIds);
    }

    /**
     * @notice This function is internal and is used to validate the parameters for a standard sale strategy
     *         when the standard transaction is initiated by a taker ask.
     * @param makerBid Maker bid struct (maker bid-specific parameters for the execution)
     */
    function _verifyStandardSaleStrategyWithMakerBid(OrderStructs.MakerBid calldata makerBid) internal pure {
        _verifyItemIdsAndAmountsEqualLengthsAndValidAmounts(makerBid.assetType, makerBid.amounts, makerBid.itemIds);
    }

    function _verifyItemIdsAndAmountsEqualLengthsAndValidAmounts(
        uint256 assetType,
        uint256[] calldata amounts,
        uint256[] calldata itemIds
    ) private pure {
        assembly {
            let end
            {
                /*
                 * @dev If A == B, then A XOR B == 0.
                 *
                 * if (amountsLength == 0 || amountsLength != itemIdsLength) {
                 *     revert OrderInvalid();
                 * }
                 */
                let amountsLength := amounts.length
                let itemIdsLength := itemIds.length

                if or(iszero(amountsLength), xor(amountsLength, itemIdsLength)) {
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
                 *   if (amount != 1) {
                 *     if (amount == 0) {
                 *        revert OrderInvalid();
                 *     }
                 *
                 *     if (_assetType == 0) {
                 *        revert OrderInvalid();
                 *     }
                 *   }
                 * }
                 */
                end := sub(end, OneWord)

                let amount := calldataload(add(amountsOffset, end))

                let invalidOrder := or(iszero(amount), and(xor(amount, 1), iszero(_assetType)))

                if invalidOrder {
                    mstore(0x00, OrderInvalid_error_selector)
                    revert(Error_selector_offset, OrderInvalid_error_length)
                }
            }
        }
    }
}
