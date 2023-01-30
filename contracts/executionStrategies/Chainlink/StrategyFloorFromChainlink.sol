// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Chainlink aggregator interface
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

// Libraries
import {OrderStructs} from "../../libraries/OrderStructs.sol";
import {CurrencyValidator} from "../../libraries/CurrencyValidator.sol";

// Shared errors
import {AskTooHigh, BidTooLow, OrderInvalid, WrongCurrency, WrongFunctionSelector} from "../../interfaces/SharedErrors.sol";

// Base strategy contracts
import {BaseStrategy} from "../BaseStrategy.sol";
import {BaseStrategyChainlinkMultiplePriceFeeds} from "./BaseStrategyChainlinkMultiplePriceFeeds.sol";

// Constants
import {ONE_HUNDRED_PERCENT_IN_BP} from "../../constants/NumericConstants.sol";

/**
 * @title StrategyFloorFromChainlink
 * @notice These strategies allow a seller to make a floor price + premium ask
 *         and a buyer to make a floor price - discount collection bid.
 *         Currently Chainlink only has price feeds for ERC721 tokens, but these
 *         strategies can also support ERC1155 tokens as long as the trade amount
 *         is 1.
 * @author LooksRare protocol team (👀,💎)
 */
contract StrategyFloorFromChainlink is BaseStrategy, BaseStrategyChainlinkMultiplePriceFeeds {
    /**
     * @notice It is returned if the fixed discount for a maker bid is greater than floor price.
     */
    error DiscountGreaterThanFloorPrice();

    /**
     * @notice Wrapped ether (WETH) address.
     */
    address public immutable WETH;

    /**
     * @notice Constructor
     * @param _owner Owner address
     * @param _weth Address of WETH
     */
    constructor(address _owner, address _weth) BaseStrategyChainlinkMultiplePriceFeeds(_owner) {
        WETH = _weth;
    }

    /**
     * @notice This function validates the order under the context of the chosen strategy
     *         and returns the fulfillable items/amounts/price/nonce invalidation status
     *         This strategy looks at the seller's desired execution price in ETH (floor + premium)
     *         and minimum execution price and chooses the higher price.
     * @param takerBid Taker bid struct (taker bid-specific parameters for the execution)
     * @param makerAsk Maker ask struct (maker ask-specific parameters for the execution)
     * @return price The final execution price
     * @return itemIds The final item ids to be traded
     * @return amounts The corresponding amounts for each item id. It should always be 1 for any asset type.
     * @return isNonceInvalidated Whether the order's nonce will be invalidated after executing the order
     * @dev The client has to provide the bidder's desired premium amount in ETH
     *      from the floor price as the additionalParameters.
     */
    function executeFixedPremiumStrategyWithTakerBid(
        OrderStructs.TakerBid calldata takerBid,
        OrderStructs.MakerAsk calldata makerAsk
    )
        external
        view
        returns (uint256 price, uint256[] memory itemIds, uint256[] memory amounts, bool isNonceInvalidated)
    {
        return _executePremiumStrategyWithTakerBid(takerBid, makerAsk, _calculateFixedPremium);
    }

    /**
     * @notice This function validates the order under the context of the chosen strategy
     *         and returns the fulfillable items/amounts/price/nonce invalidation status.
     *         This strategy looks at the seller's desired execution price in ETH (floor * (1 + premium))
     *         and minimum execution price and chooses the higher price.
     * @param takerBid Taker bid struct (taker bid-specific parameters for the execution)
     * @param makerAsk Maker ask struct (maker ask-specific parameters for the execution)
     * @return price The final execution price
     * @return itemIds The final item ids to be traded
     * @return amounts The corresponding amounts for each item id. It should always be 1 for any asset type.
     * @return isNonceInvalidated Whether the order's nonce will be invalidated after executing the order
     * @dev The client has to provide the bidder's desired premium basis points
     *      from the floor price as the additionalParameters.
     */
    function executeBasisPointsPremiumStrategyWithTakerBid(
        OrderStructs.TakerBid calldata takerBid,
        OrderStructs.MakerAsk calldata makerAsk
    )
        external
        view
        returns (uint256 price, uint256[] memory itemIds, uint256[] memory amounts, bool isNonceInvalidated)
    {
        return _executePremiumStrategyWithTakerBid(takerBid, makerAsk, _calculateBasisPointsPremium);
    }

    /**
     * @notice This function validates the order under the context of the chosen strategy
     *         and returns the fulfillable items/amounts/price/nonce invalidation status.
     *         This strategy looks at the bidder's desired execution price in ETH (floor - discount)
     *         and maximum execution price and chooses the lower price.
     * @param takerAsk Taker ask struct (taker ask-specific parameters for the execution)
     * @param makerBid Maker bid struct (maker bid-specific parameters for the execution)
     * @return price The final execution price
     * @return itemIds The final item ids to be traded
     * @return amounts The corresponding amounts for each item id. It should always be 1 for any asset type.
     * @return isNonceInvalidated Whether the order's nonce will be invalidated after executing the order
     * @dev The client has to provide the bidder's desired discount amount in ETH
     *      from the floor price as the additionalParameters.
     */
    function executeFixedDiscountCollectionOfferStrategyWithTakerAsk(
        OrderStructs.TakerAsk calldata takerAsk,
        OrderStructs.MakerBid calldata makerBid
    )
        external
        view
        returns (uint256 price, uint256[] memory itemIds, uint256[] memory amounts, bool isNonceInvalidated)
    {
        return _executeDiscountCollectionOfferStrategyWithTakerAsk(takerAsk, makerBid, _calculateFixedDiscount);
    }

    /**
     * @notice This function validates the order under the context of the chosen strategy
     *         and returns the fulfillable items/amounts/price/nonce invalidation status.
     *         This strategy looks at the bidder's desired execution price in ETH (floor * (1 - discount))
     *         and maximum execution price and chooses the lower price.
     * @param takerAsk Taker ask struct (taker ask-specific parameters for the execution)
     * @param makerBid Maker bid struct (maker bid-specific parameters for the execution)
     * @return price The final execution price
     * @return itemIds The final item ids to be traded
     * @return amounts The corresponding amounts for each item id. It should always be 1 for any asset type.
     * @return isNonceInvalidated Whether the order's nonce will be invalidated after executing the order
     * @dev The client has to provide the bidder's desired discount basis points
     *      from the floor price as the additionalParameters.
     */
    function executeBasisPointsDiscountCollectionOfferStrategyWithTakerAsk(
        OrderStructs.TakerAsk calldata takerAsk,
        OrderStructs.MakerBid calldata makerBid
    )
        external
        view
        returns (uint256 price, uint256[] memory itemIds, uint256[] memory amounts, bool isNonceInvalidated)
    {
        return _executeDiscountCollectionOfferStrategyWithTakerAsk(takerAsk, makerBid, _calculateBasisPointsDiscount);
    }

    /**
     * @notice This function validates *only the maker* order under the context of the chosen strategy.
     *         It does not revert if the maker order is invalid.
     *         Instead it returns false and the error's 4 bytes selector.
     * @param makerAsk Maker ask struct (maker ask-specific parameters for the execution)
     * @param functionSelector Function selector for the strategy
     * @return isValid Whether the maker struct is valid
     * @return errorSelector If isValid is false, it returns the error's 4 bytes selector
     */
    function isMakerAskValid(
        OrderStructs.MakerAsk calldata makerAsk,
        bytes4 functionSelector
    ) external view returns (bool isValid, bytes4 errorSelector) {
        if (
            functionSelector != StrategyFloorFromChainlink.executeBasisPointsPremiumStrategyWithTakerBid.selector &&
            functionSelector != StrategyFloorFromChainlink.executeFixedPremiumStrategyWithTakerBid.selector
        ) {
            return (isValid, WrongFunctionSelector.selector);
        }

        if (makerAsk.currency != address(0)) {
            if (makerAsk.currency != WETH) {
                return (isValid, WrongCurrency.selector);
            }
        }

        if (makerAsk.additionalParameters.length != 32) {
            return (isValid, OrderInvalid.selector);
        }

        if (makerAsk.itemIds.length != 1 || makerAsk.amounts.length != 1 || makerAsk.amounts[0] != 1) {
            return (isValid, OrderInvalid.selector);
        }

        (, bytes4 priceFeedErrorSelector) = _getFloorPriceNoRevert(makerAsk.collection);

        if (priceFeedErrorSelector == bytes4(0)) {
            isValid = true;
        } else {
            errorSelector = priceFeedErrorSelector;
        }
    }

    /**
     * @notice This function validates *only the maker* order under the context of the chosen strategy.
     *         It does not revert if the maker order is invalid.
     *         Instead it returns false and the error's 4 bytes selector.
     * @param makerBid Maker bid struct (maker bid-specific parameters for the execution)
     * @param functionSelector Function selector for the strategy
     * @return isValid Whether the maker struct is valid
     * @return errorSelector If isValid is false, it returns the error's 4 bytes selector
     * @dev The client has to provide the bidder's desired discount amount in ETH
     *      from the floor price as the additionalParameters.
     */
    function isMakerBidValid(
        OrderStructs.MakerBid calldata makerBid,
        bytes4 functionSelector
    ) external view returns (bool isValid, bytes4 errorSelector) {
        if (
            functionSelector !=
            StrategyFloorFromChainlink.executeBasisPointsDiscountCollectionOfferStrategyWithTakerAsk.selector &&
            functionSelector !=
            StrategyFloorFromChainlink.executeFixedDiscountCollectionOfferStrategyWithTakerAsk.selector
        ) {
            return (isValid, WrongFunctionSelector.selector);
        }

        if (makerBid.currency != WETH) {
            return (isValid, WrongCurrency.selector);
        }

        if (makerBid.amounts.length != 1 || makerBid.amounts[0] != 1) {
            return (isValid, OrderInvalid.selector);
        }

        (uint256 floorPrice, bytes4 priceFeedErrorSelector) = _getFloorPriceNoRevert(makerBid.collection);
        uint256 discount = abi.decode(makerBid.additionalParameters, (uint256));

        if (
            functionSelector ==
            StrategyFloorFromChainlink.executeBasisPointsDiscountCollectionOfferStrategyWithTakerAsk.selector
        ) {
            if (discount >= ONE_HUNDRED_PERCENT_IN_BP) {
                return (isValid, OrderInvalid.selector);
            }
        }

        if (priceFeedErrorSelector != bytes4(0)) {
            return (isValid, priceFeedErrorSelector);
        }

        if (
            functionSelector ==
            StrategyFloorFromChainlink.executeFixedDiscountCollectionOfferStrategyWithTakerAsk.selector
        ) {
            if (floorPrice <= discount) {
                // A special selector is returned to differentiate with OrderInvalid
                // since the maker can potentially become valid again
                return (isValid, DiscountGreaterThanFloorPrice.selector);
            }
        }

        isValid = true;
    }

    /**
     * @param _calculateDesiredPrice _calculateFixedPremium or _calculateBasisPointsPremium
     */
    function _executePremiumStrategyWithTakerBid(
        OrderStructs.TakerBid calldata takerBid,
        OrderStructs.MakerAsk calldata makerAsk,
        function(uint256 /* floorPrice */, uint256 /* premium */)
            internal
            pure
            returns (uint256 /* desiredPrice */) _calculateDesiredPrice
    )
        private
        view
        returns (uint256 price, uint256[] memory itemIds, uint256[] memory amounts, bool isNonceInvalidated)
    {
        CurrencyValidator.allowNativeOrAllowedCurrency(makerAsk.currency, WETH);

        if (
            makerAsk.itemIds.length != 1 ||
            makerAsk.amounts.length != 1 ||
            makerAsk.amounts[0] != 1 ||
            makerAsk.itemIds[0] != takerBid.itemIds[0] ||
            takerBid.amounts[0] != 1
        ) {
            revert OrderInvalid();
        }

        uint256 floorPrice = _getFloorPrice(makerAsk.collection);
        uint256 premium = abi.decode(makerAsk.additionalParameters, (uint256));
        uint256 desiredPrice = _calculateDesiredPrice(floorPrice, premium);

        if (desiredPrice >= makerAsk.minPrice) {
            price = desiredPrice;
        } else {
            price = makerAsk.minPrice;
        }

        if (takerBid.maxPrice < price) {
            revert BidTooLow();
        }

        itemIds = makerAsk.itemIds;
        amounts = makerAsk.amounts;
        isNonceInvalidated = true;
    }

    function _calculateFixedPremium(uint256 floorPrice, uint256 premium) internal pure returns (uint256 desiredPrice) {
        desiredPrice = floorPrice + premium;
    }

    function _calculateBasisPointsPremium(
        uint256 floorPrice,
        uint256 premium
    ) internal pure returns (uint256 desiredPrice) {
        desiredPrice = (floorPrice * (ONE_HUNDRED_PERCENT_IN_BP + premium)) / ONE_HUNDRED_PERCENT_IN_BP;
    }

    /**
     * @param _calculateDesiredPrice _calculateFixedDiscount or _calculateBasisPointsDiscount
     */
    function _executeDiscountCollectionOfferStrategyWithTakerAsk(
        OrderStructs.TakerAsk calldata takerAsk,
        OrderStructs.MakerBid calldata makerBid,
        function(uint256 /* floorPrice */, uint256 /* discount */)
            internal
            pure
            returns (uint256 /* desiredPrice */) _calculateDesiredPrice
    )
        private
        view
        returns (uint256 price, uint256[] memory itemIds, uint256[] memory amounts, bool isNonceInvalidated)
    {
        if (makerBid.currency != WETH) {
            revert WrongCurrency();
        }

        if (
            takerAsk.itemIds.length != 1 ||
            takerAsk.amounts.length != 1 ||
            takerAsk.amounts[0] != 1 ||
            makerBid.amounts.length != 1 ||
            makerBid.amounts[0] != 1
        ) {
            revert OrderInvalid();
        }

        uint256 floorPrice = _getFloorPrice(makerBid.collection);
        uint256 discount = abi.decode(makerBid.additionalParameters, (uint256));

        uint256 desiredPrice = _calculateDesiredPrice(floorPrice, discount);

        if (desiredPrice >= makerBid.maxPrice) {
            price = makerBid.maxPrice;
        } else {
            price = desiredPrice;
        }

        if (takerAsk.minPrice > price) {
            revert AskTooHigh();
        }

        itemIds = takerAsk.itemIds;
        amounts = takerAsk.amounts;
        isNonceInvalidated = true;
    }

    function _calculateFixedDiscount(
        uint256 floorPrice,
        uint256 discount
    ) internal pure returns (uint256 desiredPrice) {
        if (floorPrice <= discount) {
            revert DiscountGreaterThanFloorPrice();
        }
        unchecked {
            desiredPrice = floorPrice - discount;
        }
    }

    /**
     * @dev Discount cannot be 100%
     */
    function _calculateBasisPointsDiscount(
        uint256 floorPrice,
        uint256 discount
    ) internal pure returns (uint256 desiredPrice) {
        if (discount >= ONE_HUNDRED_PERCENT_IN_BP) {
            revert OrderInvalid();
        }
        desiredPrice = (floorPrice * (ONE_HUNDRED_PERCENT_IN_BP - discount)) / ONE_HUNDRED_PERCENT_IN_BP;
    }

    function _getFloorPrice(address collection) private view returns (uint256 price) {
        address priceFeed = priceFeeds[collection];

        if (priceFeed == address(0)) {
            revert PriceFeedNotAvailable();
        }

        (, int256 answer, , uint256 updatedAt, ) = AggregatorV3Interface(priceFeed).latestRoundData();

        // Verify the answer is not null or negative
        if (answer <= 0) {
            revert InvalidChainlinkPrice();
        }

        // Verify the latency
        if (block.timestamp - updatedAt > maxLatency) {
            revert PriceNotRecentEnough();
        }

        price = uint256(answer);
    }

    function _getFloorPriceNoRevert(
        address collection
    ) private view returns (uint256 floorPrice, bytes4 errorSelector) {
        address priceFeed = priceFeeds[collection];
        if (priceFeed == address(0)) {
            return (floorPrice, PriceFeedNotAvailable.selector);
        }

        (, int256 answer, , uint256 updatedAt, ) = AggregatorV3Interface(priceFeed).latestRoundData();
        if (answer <= 0) {
            return (floorPrice, InvalidChainlinkPrice.selector);
        }
        if (block.timestamp - updatedAt > maxLatency) {
            return (floorPrice, PriceNotRecentEnough.selector);
        }

        return (uint256(answer), bytes4(0));
    }
}
