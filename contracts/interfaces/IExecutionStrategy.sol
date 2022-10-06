// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import {OrderStructs} from "../libraries/OrderStructs.sol";

/**
 * @title IExecutionStrategy
 * @author LooksRare protocol team (👀,💎)
 */
interface IExecutionStrategy {
    // Custom errors
    error OrderInvalid();

    function executeStrategyWithTakerBid(
        OrderStructs.TakerBid calldata takerBid,
        OrderStructs.MakerAsk calldata makerAsk
    )
        external
        returns (
            uint256 price,
            uint256[] calldata itemIds,
            uint256[] calldata amounts
        );

    function executeStrategyWithTakerAsk(
        OrderStructs.TakerAsk calldata takerAsk,
        OrderStructs.MakerBid calldata makerBid
    )
        external
        returns (
            uint256 price,
            uint256[] calldata itemIds,
            uint256[] calldata amounts
        );
}
