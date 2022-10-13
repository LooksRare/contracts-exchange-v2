// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {OrderStructs} from "../libraries/OrderStructs.sol";

/**
 * @title IExecutionStrategy
 * @author LooksRare protocol team (👀,💎)
 */
interface IExecutionStrategy {
    // Custom errors
    error BidTooLow();
    error OrderInvalid();
    error WrongCaller();

    /**
     * @notice Validate the order under the context of the chosen strategy and return the fulfillable items/amounts/price
     * @param takerBid Taker bid struct (contains the taker bid-specific parameters for the execution of the transaction)
     * @param makerAsk Maker ask struct (contains the maker ask-specific parameters for the execution of the transaction)
     */
    function executeStrategyWithTakerBid(
        OrderStructs.TakerBid calldata takerBid,
        OrderStructs.MakerAsk calldata makerAsk
    )
        external
        returns (
            uint256 price,
            uint256[] memory itemIds,
            uint256[] memory amounts,
            bool isNonceInvalidated
        );

    /**
     * @notice Validate the order under the context of the chosen strategy and return the fulfillable items/amounts/price
     * @param takerAsk Taker ask struct (contains the taker ask-specific parameters for the execution of the transaction)
     * @param makerBid Maker bid struct (contains the maker bid-specific parameters for the execution of the transaction)
     */
    function executeStrategyWithTakerAsk(
        OrderStructs.TakerAsk calldata takerAsk,
        OrderStructs.MakerBid calldata makerBid
    )
        external
        returns (
            uint256 price,
            uint256[] memory itemIds,
            uint256[] memory amounts,
            bool isNonceInvalidated
        );
}
