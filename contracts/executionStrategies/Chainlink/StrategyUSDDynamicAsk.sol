// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Libraries
import {OrderStructs} from "../../libraries/OrderStructs.sol";

// Interfaces
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

// Shared errors
import {BidTooLow, OrderInvalid, WrongCurrency} from "../../interfaces/SharedErrors.sol";

// Base strategy
import {StrategyChainlinkPriceLatency} from "./StrategyChainlinkPriceLatency.sol";

/**
 * @title StrategyUSDDynamicAsk
 * @notice This contract allows a seller to sell an NFT priced in USD and the receivable amount in ETH.
 * @author LooksRare protocol team (👀,💎)
 */
contract StrategyUSDDynamicAsk is StrategyChainlinkPriceLatency {
    // WETH
    address public immutable WETH;

    /**
     * @dev Chainlink ETH/USD Price Feed
     */
    AggregatorV3Interface public priceFeed = AggregatorV3Interface(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);

    /**
     * @notice Constructor
     * @param _weth Wrapped ether address
     * @param _owner Owner address
     */
    constructor(address _weth, address _owner) StrategyChainlinkPriceLatency(_owner) {
        WETH = _weth;
    }

    /**
     * @notice Validate the order under the context of the chosen strategy and return the fulfillable items/amounts/price/nonce invalidation status
     *         This strategy looks at the seller's desired sale price in USD and minimum sale price in ETH, converts the USD value into ETH using Chainlink's price feed and chooses the higher price.
     * @param takerBid Taker bid struct (contains the taker bid-specific parameters for the execution of the transaction)
     * @param makerAsk Maker ask struct (contains the maker ask-specific parameters for the execution of the transaction)
     * @dev The client has to provide the seller's desired sale price in USD as the additionalParameters
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

        if (itemIdsLength == 0 || itemIdsLength != makerAsk.amounts.length) revert OrderInvalid();
        for (uint256 i; i < itemIdsLength; ) {
            if (makerAsk.itemIds[i] != takerBid.itemIds[i] || makerAsk.amounts[i] != takerBid.amounts[i])
                revert OrderInvalid();

            unchecked {
                ++i;
            }
        }

        if (makerAsk.currency != address(0)) {
            if (makerAsk.currency != WETH) {
                revert WrongCurrency();
            }
        }

        (, int256 answer, , uint256 updatedAt, ) = priceFeed.latestRoundData();
        if (answer <= 0) revert InvalidChainlinkPrice();
        if (block.timestamp - updatedAt > maxLatency) revert PriceNotRecentEnough();

        // The client has to provide a USD value that is augmented by 1e18.
        uint256 desiredSalePriceInUSD = abi.decode(makerAsk.additionalParameters, (uint256));

        uint256 ethPriceInUSD = uint256(answer);
        uint256 minPriceInETH = makerAsk.minPrice;
        uint256 desiredSalePriceInETH = (desiredSalePriceInUSD * 1e8) / ethPriceInUSD;

        if (minPriceInETH >= desiredSalePriceInETH) {
            price = minPriceInETH;
        } else {
            price = desiredSalePriceInETH;
        }

        if (takerBid.maxPrice < price) revert BidTooLow();

        itemIds = makerAsk.itemIds;
        amounts = makerAsk.amounts;
        isNonceInvalidated = true;
    }

    /**
     * @notice Validate *only the maker* order under the context of the chosen strategy. It does not revert if
     *         the maker order is invalid. Instead it returns false and the error's 4 bytes selector.
     * @param makerAsk Maker ask struct (contains the maker ask-specific parameters for the execution of the transaction)
     * @return orderIsValid Whether the maker struct is valid
     * @return errorSelector If isValid is false, return the error's 4 bytes selector
     */
    function isValid(
        OrderStructs.MakerAsk calldata makerAsk
    ) external view returns (bool orderIsValid, bytes4 errorSelector) {
        uint256 itemIdsLength = makerAsk.itemIds.length;

        if (itemIdsLength == 0 || itemIdsLength != makerAsk.amounts.length) {
            return (orderIsValid, OrderInvalid.selector);
        }

        if (makerAsk.currency != address(0)) {
            if (makerAsk.currency != WETH) {
                return (orderIsValid, WrongCurrency.selector);
            }
        }

        (, int256 answer, , uint256 updatedAt, ) = priceFeed.latestRoundData();

        if (answer <= 0) {
            return (orderIsValid, InvalidChainlinkPrice.selector);
        }

        if (block.timestamp - updatedAt > maxLatency) {
            return (orderIsValid, PriceNotRecentEnough.selector);
        }

        orderIsValid = true;
    }
}
