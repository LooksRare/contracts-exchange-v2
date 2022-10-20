// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {OwnableTwoSteps} from "@looksrare/contracts-libs/contracts/OwnableTwoSteps.sol";
import {StrategyBase} from "./StrategyBase.sol";
import {StrategyChainlinkMultiplePriceFeeds} from "./StrategyChainlinkMultiplePriceFeeds.sol";
import {StrategyChainlinkPriceLatency} from "./StrategyChainlinkPriceLatency.sol";
import {IExecutionStrategy} from "../interfaces/IExecutionStrategy.sol";
import {OrderStructs} from "../libraries/OrderStructs.sol";

/**
 * @title StrategyFloorBasedCollectionOffer
 * @notice This contract allows a bidder to place a discounted floor price bid
 * @author LooksRare protocol team (👀,💎)
 */
contract StrategyFloorBasedCollectionOffer is StrategyChainlinkMultiplePriceFeeds, StrategyChainlinkPriceLatency {
    // Address of the protocol
    address public immutable LOOKSRARE_PROTOCOL;

    error InvalidChainlinkPrice();

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
     * @notice This strategy looks at the bidder's desired execution price in ETH (floor - discount)
     *         and maximum execution price and chooses the lower price
     * @dev The client has to provide the bidder's desired discount amount in ETH from the floor price
     *      as the additionalParameters
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

        if (takerAsk.itemIds.length != 1 || takerAsk.amounts.length != 1 || takerAsk.amounts[0] != 1)
            revert OrderInvalid();

        address priceFeed = priceFeeds[makerBid.collection];
        if (priceFeed == address(0)) revert PriceFeedNotAvailable();

        (, int256 answer, , uint256 updatedAt, ) = AggregatorV3Interface(priceFeed).latestRoundData();
        if (answer <= 0) revert InvalidChainlinkPrice();
        if (block.timestamp > maximumLatency + updatedAt) revert PriceNotRecentEnough();

        uint256 discountAmount = abi.decode(makerBid.additionalParameters, (uint256));
        uint256 floorPrice = uint256(answer);
        uint256 desiredPrice = floorPrice - discountAmount;

        if (desiredPrice > makerBid.maxPrice) {
            price = makerBid.maxPrice;
        } else {
            price = desiredPrice;
        }

        if (price < takerAsk.minPrice) revert BidTooLow();

        itemIds = takerAsk.itemIds;
        amounts = takerAsk.amounts;
        isNonceInvalidated = true;
    }
}
