// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IExecutionStrategy} from "../interfaces/IExecutionStrategy.sol";
import {OrderStructs} from "../libraries/OrderStructs.sol";

/**
 * @title StrategyTokenIdsRange
 * @author LooksRare protocol team (👀,💎)
 */
contract StrategyTokenIdsRange is IExecutionStrategy {
    // Address of the protocol
    address public immutable LOOKSRARE_PROTOCOL;

    /**
     * @notice Constructor
     * @param _looksRareProtocol Address of the LooksRare protocol
     */
    constructor(address _looksRareProtocol) {
        LOOKSRARE_PROTOCOL = _looksRareProtocol;
    }

    /**
     * @inheritdoc IExecutionStrategy
     */
    function executeStrategyWithTakerBid(OrderStructs.TakerBid calldata, OrderStructs.MakerAsk calldata)
        external
        pure
        override
        returns (
            uint256,
            uint256[] memory,
            uint256[] memory,
            bool
        )
    {
        revert OrderInvalid();
    }

    /**
     * @inheritdoc IExecutionStrategy
     */
    function executeStrategyWithTakerAsk(
        OrderStructs.TakerAsk calldata takerAsk,
        OrderStructs.MakerBid calldata makerBid
    )
        external
        view
        override
        returns (
            uint256 price,
            uint256[] memory itemIds,
            uint256[] memory amounts,
            bool isNonceInvalidated
        )
    {
        if (msg.sender != LOOKSRARE_PROTOCOL) revert WrongCaller();

        uint256 minTokenId = makerBid.itemIds[0];
        uint256 maxTokenId = makerBid.itemIds[1];
        if (minTokenId > maxTokenId) revert OrderInvalid();

        uint256 desiredAmount = makerBid.amounts[0];
        uint256 totalOfferedAmount;
        uint256 lastTokenId;

        for (uint256 i; i < takerAsk.itemIds.length; ) {
            uint256 offeredTokenId = takerAsk.itemIds[i];
            // Force the client to sort the token IDs in ascending order,
            // in order to prevent taker ask from providing duplicated
            // token IDs
            if (offeredTokenId <= lastTokenId) revert OrderInvalid();

            if (offeredTokenId >= minTokenId) {
                if (offeredTokenId <= maxTokenId) {
                    uint256 offeredAmount = takerAsk.amounts[i];
                    if (offeredAmount == 0) revert OrderInvalid();

                    totalOfferedAmount += offeredAmount;
                }
            }

            lastTokenId = offeredTokenId;

            unchecked {
                ++i;
            }
        }

        if (totalOfferedAmount != desiredAmount) revert OrderInvalid();
        if (makerBid.maxPrice != takerAsk.minPrice) revert OrderInvalid();

        price = makerBid.maxPrice;
        itemIds = takerAsk.itemIds;
        amounts = takerAsk.amounts;
        isNonceInvalidated = true;
    }
}
