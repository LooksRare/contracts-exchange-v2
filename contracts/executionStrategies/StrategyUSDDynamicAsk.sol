// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {OwnableTwoSteps} from "@looksrare/contracts-libs/contracts/OwnableTwoSteps.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {IExecutionStrategy} from "../interfaces/IExecutionStrategy.sol";
import {OrderStructs} from "../libraries/OrderStructs.sol";

/**
 * @title StrategyUSDDynamicAsk
 * @notice This contract allows a seller to sell an NFT priced in USD and the receivable amount in ETH.
 * @author LooksRare protocol team (👀,💎)
 */
contract StrategyUSDDynamicAsk is IExecutionStrategy, OwnableTwoSteps {
    // Address of the protocol
    address public immutable LOOKSRARE_PROTOCOL;
    /**
     * @dev Chainlink ETH/USD Price Feed
     */
    AggregatorV3Interface public priceFeed = AggregatorV3Interface(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
    uint256 public maximumLatency;

    error InvalidChainlinkPrice();
    error LatencyToleranceTooHigh();
    error PriceNotRecentEnough();

    /**
     * @notice Emitted when the maximum Chainlink price latency is updated
     * @param maximumLatency Maximum Chainlink price latency
     */
    event MaximumLatencyUpdated(uint256 maximumLatency);

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
    function executeStrategyWithTakerBid(
        OrderStructs.TakerBid calldata takerBid,
        OrderStructs.MakerAsk calldata makerAsk
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

        uint256 itemIdsLength = makerAsk.itemIds.length;

        if (itemIdsLength == 0 || itemIdsLength != makerAsk.amounts.length) revert OrderInvalid();
        for (uint256 i; i < itemIdsLength; ) {
            if (makerAsk.itemIds[i] != takerBid.itemIds[i] || makerAsk.amounts[i] != takerBid.amounts[i])
                revert OrderInvalid();

            unchecked {
                ++i;
            }
        }

        (, int256 answer, , uint256 updatedAt, ) = priceFeed.latestRoundData();
        if (answer < 0) revert InvalidChainlinkPrice();
        if (block.timestamp - updatedAt > maximumLatency) revert PriceNotRecentEnough();

        // The client has to provide a USD value that is augmented by 1e18.
        uint256 desiredSalePriceInUSD = abi.decode(makerAsk.additionalParameters, (uint256));

        uint256 ethPriceInUSD = uint256(answer);
        uint256 minPriceInETH = makerAsk.minPrice;
        uint256 desiredSalePriceInETH = (desiredSalePriceInUSD * 1e8) / ethPriceInUSD;

        if (minPriceInETH > desiredSalePriceInETH) {
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
     * @inheritdoc IExecutionStrategy
     */
    function executeStrategyWithTakerAsk(OrderStructs.TakerAsk calldata, OrderStructs.MakerBid calldata)
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
     * @notice Set maximum Chainlink price latency. It cannot be higher than 3,600
     *         as Chainlink will at least update the price every 3,600 seconds, provided
     *         ETH's price does not deviate more than 0.5%.
     * @dev Function only callable by contract owner
     * @param _maximumLatency Maximum Chainlink price latency
     */
    function setMaximumLatency(uint256 _maximumLatency) external onlyOwner {
        if (_maximumLatency > 3600) revert LatencyToleranceTooHigh();
        maximumLatency = _maximumLatency;
        emit MaximumLatencyUpdated(_maximumLatency);
    }
}
