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
     */
    function _verifyStandardSaleStrategyWithTakerBid(
        uint256 assetType,
        OrderStructs.Item[] calldata items,
        uint256 minAskPrice,
        uint256 maxBidPrice
    ) internal pure returns (uint256 price, uint256[] memory itemIds, uint256[] memory amounts) {
        if (minAskPrice != maxBidPrice) {
            revert OrderInvalid();
        }

        price = minAskPrice;

        uint256 length = items.length;

        if (length == 0) {
            revert OrderInvalid();
        }

        itemIds = new uint256[](length);
        amounts = new uint256[](length);

        for (uint256 i; i < length; ) {
            OrderStructs.Item calldata item = items[i];
            uint256 amount = item.amount;

            // TODO: optimize
            if (amount != 1) {
                if (assetType == 0) {
                    revert OrderInvalid();
                }
                if (amount == 0) {
                    revert OrderInvalid();
                }
            }

            itemIds[i] = item.itemId;
            amounts[i] = amount;

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice This function is internal and is used to validate the parameters for a standard sale strategy
     *         when the standard transaction is initiated by a taker ask.
     */
    function _verifyStandardSaleStrategyWithTakerAsk(
        uint256 assetType,
        OrderStructs.Item[] calldata items,
        uint256 minAskPrice,
        uint256 maxBidPrice
    ) internal pure returns (uint256 price, uint256[] memory itemIds, uint256[] memory amounts) {
        if (minAskPrice != maxBidPrice) {
            revert OrderInvalid();
        }

        price = maxBidPrice;

        uint256 length = items.length;

        if (length == 0) {
            revert OrderInvalid();
        }

        itemIds = new uint256[](length);
        amounts = new uint256[](length);

        for (uint256 i; i < length; ) {
            OrderStructs.Item calldata item = items[i];
            uint256 amount = item.amount;

            // TODO: optimize
            if (amount != 1) {
                if (assetType == 0) {
                    revert OrderInvalid();
                }
                if (amount == 0) {
                    revert OrderInvalid();
                }
            }

            itemIds[i] = item.itemId;
            amounts[i] = amount;

            unchecked {
                ++i;
            }
        }
    }
}
