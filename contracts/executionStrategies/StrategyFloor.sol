// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {OwnableTwoSteps} from "@looksrare/contracts-libs/contracts/OwnableTwoSteps.sol";
import {StrategyChainlinkMultiplePriceFeeds} from "./StrategyChainlinkMultiplePriceFeeds.sol";
import {StrategyChainlinkPriceLatency} from "./StrategyChainlinkPriceLatency.sol";
import {IExecutionStrategy} from "../interfaces/IExecutionStrategy.sol";
import {OrderStructs} from "../libraries/OrderStructs.sol";

/**
 * @title StrategyFloor
 * @notice This contract allows a seller to make a floor price + premium ask
 *         and a buyer to maker a floor price - discount collection bid
 * @author LooksRare protocol team (👀,💎)
 */
contract StrategyFloor is StrategyChainlinkMultiplePriceFeeds, StrategyChainlinkPriceLatency {
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
     * @notice Validate the order under the context of the chosen strategy and return the fulfillable items/amounts/price/nonce invalidation status
     *         This strategy looks at the seller's desired execution price in ETH (floor + premium) and minimum execution price and chooses the higher price
     * @param takerBid Taker bid struct (contains the taker bid-specific parameters for the execution of the transaction)
     * @param makerAsk Maker ask struct (contains the maker ask-specific parameters for the execution of the transaction)
     * @dev The client has to provide the bidder's desired premium amount in ETH from the floor price as the additionalParameters.
     */
    function executeFixedPremiumStrategyWithTakerBid(
        OrderStructs.TakerBid calldata takerBid,
        OrderStructs.MakerAsk calldata makerAsk
    )
        external
        view
        returns (uint256 price, uint256[] memory itemIds, uint256[] memory amounts, bool isNonceInvalidated)
    {
        if (msg.sender != LOOKSRARE_PROTOCOL) revert WrongCaller();

        if (
            makerAsk.itemIds.length != 1 ||
            makerAsk.amounts.length != 1 ||
            makerAsk.amounts[0] != 1 ||
            makerAsk.itemIds[0] != takerBid.itemIds[0] ||
            takerBid.amounts[0] != 1
        ) revert OrderInvalid();

        address priceFeed = priceFeeds[makerAsk.collection];
        if (priceFeed == address(0)) revert PriceFeedNotAvailable();

        (, int256 answer, , uint256 updatedAt, ) = AggregatorV3Interface(priceFeed).latestRoundData();
        if (answer <= 0) revert InvalidChainlinkPrice();
        if (block.timestamp > maximumLatency + updatedAt) revert PriceNotRecentEnough();

        uint256 premium = abi.decode(makerAsk.additionalParameters, (uint256));
        uint256 floorPrice = uint256(answer);
        uint256 desiredPrice = floorPrice + premium;

        if (desiredPrice >= makerAsk.minPrice) {
            price = desiredPrice;
        } else {
            price = makerAsk.minPrice;
        }

        if (takerBid.maxPrice < desiredPrice) revert BidTooLow();

        itemIds = makerAsk.itemIds;
        amounts = makerAsk.amounts;
        isNonceInvalidated = true;
    }

    /**
     * @notice Validate the order under the context of the chosen strategy and return the fulfillable items/amounts/price/nonce invalidation status
     *         This strategy looks at the seller's desired execution price in ETH (floor * (1 + premium)) and minimum execution price and chooses the higher price
     * @param takerBid Taker bid struct (contains the taker bid-specific parameters for the execution of the transaction)
     * @param makerAsk Maker ask struct (contains the maker ask-specific parameters for the execution of the transaction)
     * @dev The client has to provide the bidder's desired premium amount in ETH from the floor price as the additionalParameters.
     */
    function executePercentagePremiumStrategyWithTakerBid(
        OrderStructs.TakerBid calldata takerBid,
        OrderStructs.MakerAsk calldata makerAsk
    )
        external
        view
        returns (uint256 price, uint256[] memory itemIds, uint256[] memory amounts, bool isNonceInvalidated)
    {
        if (msg.sender != LOOKSRARE_PROTOCOL) revert WrongCaller();

        if (
            makerAsk.itemIds.length != 1 ||
            makerAsk.amounts.length != 1 ||
            makerAsk.amounts[0] != 1 ||
            makerAsk.itemIds[0] != takerBid.itemIds[0] ||
            takerBid.amounts[0] != 1
        ) revert OrderInvalid();

        address priceFeed = priceFeeds[makerAsk.collection];
        if (priceFeed == address(0)) revert PriceFeedNotAvailable();

        (, int256 answer, , uint256 updatedAt, ) = AggregatorV3Interface(priceFeed).latestRoundData();
        if (answer <= 0) revert InvalidChainlinkPrice();
        if (block.timestamp > maximumLatency + updatedAt) revert PriceNotRecentEnough();

        uint256 premium = abi.decode(makerAsk.additionalParameters, (uint256));
        uint256 floorPrice = uint256(answer);
        uint256 desiredPrice = (floorPrice * (10_000 + premium)) / 10_000;

        if (desiredPrice >= makerAsk.minPrice) {
            price = desiredPrice;
        } else {
            price = makerAsk.minPrice;
        }

        if (takerBid.maxPrice < desiredPrice) revert BidTooLow();

        itemIds = makerAsk.itemIds;
        amounts = makerAsk.amounts;
        isNonceInvalidated = true;
    }

    /**
     * @notice Validate the *only the maker* order under the context of the chosen strategy. It does not revert if
     *         the maker order is invalid. Instead it returns false and the error's 4 bytes selector.
     * @param makerAsk Maker ask struct (contains the maker ask-specific parameters for the execution of the transaction)
     */
    function isValid(OrderStructs.MakerAsk calldata makerAsk) external view returns (bool, bytes4) {
        if (makerAsk.itemIds.length != 1 || makerAsk.amounts.length != 1 || makerAsk.amounts[0] != 1) {
            return (false, OrderInvalid.selector);
        }

        address priceFeed = priceFeeds[makerAsk.collection];
        if (priceFeed == address(0)) {
            return (false, PriceFeedNotAvailable.selector);
        }

        (, int256 answer, , uint256 updatedAt, ) = AggregatorV3Interface(priceFeed).latestRoundData();
        if (answer <= 0) {
            return (false, InvalidChainlinkPrice.selector);
        }
        if (block.timestamp > maximumLatency + updatedAt) {
            return (false, PriceNotRecentEnough.selector);
        }

        return (true, bytes4(0));
    }
}
