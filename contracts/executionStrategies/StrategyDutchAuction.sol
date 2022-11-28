// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {StrategyBase} from "./StrategyBase.sol";
import {IExecutionStrategy} from "../interfaces/IExecutionStrategy.sol";
import {OrderStructs} from "../libraries/OrderStructs.sol";

/**
 * @title StrategyDutchAuction
 * @author LooksRare protocol team (👀,💎)
 */
contract StrategyDutchAuction is StrategyBase {
    // Address of the protocol
    address public immutable LOOKSRARE_PROTOCOL;

    /**
     * @notice Constructor
     * @param _looksRareProtocol Address of the LooksRare protocol.
     */
    constructor(address _looksRareProtocol) {
        LOOKSRARE_PROTOCOL = _looksRareProtocol;
    }

    /**
     * @notice Validate the order under the context of the chosen strategy and return the fulfillable items/amounts/price/nonce invalidation status
     *         The execution price set by the seller decreases linearly within the defined period.
     * @param takerBid Taker bid struct (contains the taker ask-specific parameters for the execution of the transaction)
     * @param makerAsk Maker ask struct (contains the maker bid-specific parameters for the execution of the transaction)
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
        if (msg.sender != LOOKSRARE_PROTOCOL) revert WrongCaller();

        uint256 itemIdsLength = makerAsk.itemIds.length;

        if (itemIdsLength == 0 || itemIdsLength != makerAsk.amounts.length) revert OrderInvalid();
        for (uint256 i; i < itemIdsLength; ) {
            uint256 amount = makerAsk.amounts[i];
            if (amount == 0) revert OrderInvalid();
            if (makerAsk.itemIds[i] != takerBid.itemIds[i] || amount != takerBid.amounts[i]) revert OrderInvalid();

            unchecked {
                ++i;
            }
        }

        uint256 startPrice = abi.decode(makerAsk.additionalParameters, (uint256));

        if (startPrice < makerAsk.minPrice) revert OrderInvalid();

        uint256 duration = makerAsk.endTime - makerAsk.startTime;
        uint256 decayPerSecond = (startPrice - makerAsk.minPrice) / duration;

        uint256 elapsedTime = block.timestamp - makerAsk.startTime;
        price = startPrice - elapsedTime * decayPerSecond;

        if (takerBid.maxPrice < price) revert BidTooLow();

        isNonceInvalidated = true;

        itemIds = makerAsk.itemIds;
        amounts = makerAsk.amounts;
    }

    function isValid(OrderStructs.TakerBid calldata takerBid, OrderStructs.MakerAsk calldata makerAsk)
        external
        view
        returns (bool, bytes4)
    {
        uint256 itemIdsLength = makerAsk.itemIds.length;

        if (itemIdsLength == 0 || itemIdsLength != makerAsk.amounts.length) {
            return (false, OrderInvalid.selector);
        }
        for (uint256 i; i < itemIdsLength; ) {
            uint256 amount = makerAsk.amounts[i];
            if (amount == 0) {
                return (false, OrderInvalid.selector);
            }
            if (makerAsk.itemIds[i] != takerBid.itemIds[i] || amount != takerBid.amounts[i]) {
                return (false, OrderInvalid.selector);
            }

            unchecked {
                ++i;
            }
        }

        uint256 startPrice = abi.decode(makerAsk.additionalParameters, (uint256));

        if (startPrice < makerAsk.minPrice) {
            return (false, OrderInvalid.selector);
        }

        uint256 duration = makerAsk.endTime - makerAsk.startTime;
        uint256 decayPerSecond = (startPrice - makerAsk.minPrice) / duration;

        uint256 elapsedTime = block.timestamp - makerAsk.startTime;
        uint256 price = startPrice - elapsedTime * decayPerSecond;

        if (takerBid.maxPrice < price) {
            return (false, BidTooLow.selector);
        }

        return (true, bytes4(0));
    }
}
