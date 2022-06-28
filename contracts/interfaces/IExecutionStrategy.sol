// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import {OrderStructs} from "../libraries/OrderStructs.sol";

/**
 * @title IExecutionStrategy
 * @notice Contains functions for execution strategies (v2)
 * @author LooksRare protocol team (👀,💎)
 */
interface IExecutionStrategy {
    function executeStrategyWithTakerBid(
        OrderStructs.TakerBidOrder calldata takerBid,
        OrderStructs.SingleMakerAskOrder calldata makerAsk,
        address collection,
        uint256 startTime,
        uint256 endTime
    )
        external
        returns (
            uint256 price,
            uint256[] calldata itemIds,
            uint256[] calldata amounts
        );

    function executeStrategyWithTakerAsk(
        OrderStructs.TakerAskOrder calldata takerAsk,
        OrderStructs.SingleMakerBidOrder calldata makerBid,
        address collection,
        uint256 startTime,
        uint256 endTime
    )
        external
        returns (
            uint256 price,
            uint256[] calldata itemIds,
            uint256[] calldata amounts
        );
}
