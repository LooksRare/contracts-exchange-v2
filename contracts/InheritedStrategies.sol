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

        {
            if (
                targetLength == 0 ||
                itemIds.length != targetLength ||
                takerBid.itemIds.length != targetLength ||
                takerBid.amounts.length != targetLength ||
                price != takerBid.maxPrice
            ) revert OrderInvalid();

            for (uint256 i; i < targetLength; ) {
                if ((takerBid.amounts[i] != amounts[i]) || amounts[i] == 0 || (takerBid.itemIds[i] != itemIds[i]))
                    revert OrderInvalid();

                unchecked {
                    ++i;
                }
            }
        }
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

        {
            if (
                targetLength == 0 ||
                itemIds.length != targetLength ||
                takerAsk.itemIds.length != targetLength ||
                takerAsk.amounts.length != targetLength ||
                price != takerAsk.minPrice
            ) revert OrderInvalid();

            for (uint256 i; i < targetLength; ) {
                if ((takerAsk.amounts[i] != amounts[i]) || amounts[i] == 0 || (takerAsk.itemIds[i] != itemIds[i]))
                    revert OrderInvalid();

                unchecked {
                    ++i;
                }
            }
        }
    }
}
