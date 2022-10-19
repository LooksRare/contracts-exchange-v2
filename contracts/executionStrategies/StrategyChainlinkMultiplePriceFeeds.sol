// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {StrategyBase} from "./StrategyBase.sol";

/**
 * @title StrategyChainlinkMultiplePriceFeeds
 * @notice This contract allows a strategy to store Chainlink price feeds for price retrieval
 * @author LooksRare protocol team (👀,💎)
 */
abstract contract StrategyChainlinkMultiplePriceFeeds is StrategyBase {
    mapping(address => address) public priceFeeds;

    error PriceFeedNotAvailable();
    error PriceNotRecentEnough();

    /**
     * @notice Emitted when a collection's price feed address is updated
     * @param collection NFT collection address
     * @param priceFeed Chainlink price feed address
     */
    event PriceFeedUpdated(address indexed collection, address indexed priceFeed);

    /**
     * @notice Set an NFT collection's Chainlink price feed address.
     * @dev Function only callable by contract owner
     * @param _collection NFT collection address
     * @param _priceFeed Chainlink price feed address
     */
    function setPriceFeed(address _collection, address _priceFeed) external onlyOwner {
        priceFeeds[_collection] = _priceFeed;
        emit PriceFeedUpdated(_collection, _priceFeed);
    }
}
