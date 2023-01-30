// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Libraries
import {OrderStructs} from "../libraries/OrderStructs.sol";

// Shared errors
import {BidTooLow, OrderInvalid, FunctionSelectorInvalid} from "../errors/SharedErrors.sol";

// Base strategy contracts
import {BaseStrategy} from "./BaseStrategy.sol";

// Constants
import {ASSET_TYPE_ERC721} from "../constants/NumericConstants.sol";

/**
 * @title StrategyDutchAuction
 * @notice This contract offers a single execution strategy for users to create Dutch auctions.
 * @author LooksRare protocol team (👀,💎)
 */
contract StrategyDutchAuction is BaseStrategy {
    /**
     * @notice This function validates the order under the context of the chosen strategy
     *         and returns the fulfillable items/amounts/price/nonce invalidation status.
     *         The execution price set by the seller decreases linearly within the defined period.
     * @param takerBid Taker bid struct (taker ask-specific parameters for the execution)
     * @param makerAsk Maker ask struct (maker bid-specific parameters for the execution)
     * @dev The client has to provide the seller's desired initial start price as the additionalParameters.
     */
    function executeStrategyWithTakerBid(
        OrderStructs.TakerBid calldata takerBid,
        OrderStructs.MakerAsk calldata makerAsk
    )
        external
        view
        returns (uint256 price, uint256[] memory itemIds, uint256[] memory amounts, bool isNonceInvalidated)
    {
        uint256 itemIdsLength = makerAsk.itemIds.length;

        if (itemIdsLength == 0 || itemIdsLength != makerAsk.amounts.length) {
            revert OrderInvalid();
        }

        for (uint256 i; i < itemIdsLength; ) {
            _validateAmount(makerAsk.amounts[i], makerAsk.assetType);
            unchecked {
                ++i;
            }
        }

        uint256 startPrice = abi.decode(makerAsk.additionalParameters, (uint256));

        if (startPrice < makerAsk.minPrice) {
            revert OrderInvalid();
        }

        uint256 startTime = makerAsk.startTime;
        uint256 endTime = makerAsk.endTime;

        price =
            ((endTime - block.timestamp) * startPrice + (block.timestamp - startTime) * makerAsk.minPrice) /
            (endTime - startTime);

        if (takerBid.maxPrice < price) {
            revert BidTooLow();
        }

        isNonceInvalidated = true;

        itemIds = makerAsk.itemIds;
        amounts = makerAsk.amounts;
    }

    /**
     * @notice This function validates *only the maker* order under the context of the chosen strategy.
     *         It does not revert if the maker order is invalid.
     *         Instead it returns false and the error's 4 bytes selector.
     * @param makerAsk Maker ask struct (maker bid-specific parameters for the execution)
     * @param functionSelector Function selector for the strategy
     * @dev The client has to provide the seller's desired initial start price as the additionalParameters.
     * @return isValid Whether the maker struct is valid
     * @return errorSelector If isValid is false, it returns the error's 4 bytes selector
     */
    function isMakerAskValid(
        OrderStructs.MakerAsk calldata makerAsk,
        bytes4 functionSelector
    ) external pure returns (bool isValid, bytes4 errorSelector) {
        if (functionSelector != StrategyDutchAuction.executeStrategyWithTakerBid.selector) {
            return (isValid, FunctionSelectorInvalid.selector);
        }

        uint256 itemIdsLength = makerAsk.itemIds.length;

        if (itemIdsLength == 0 || itemIdsLength != makerAsk.amounts.length) {
            return (isValid, OrderInvalid.selector);
        }

        for (uint256 i; i < itemIdsLength; ) {
            _validateAmountNoRevert(makerAsk.amounts[i], makerAsk.assetType);
            unchecked {
                ++i;
            }
        }

        uint256 startPrice = abi.decode(makerAsk.additionalParameters, (uint256));

        if (startPrice < makerAsk.minPrice) {
            return (isValid, OrderInvalid.selector);
        }

        isValid = true;
    }
}
