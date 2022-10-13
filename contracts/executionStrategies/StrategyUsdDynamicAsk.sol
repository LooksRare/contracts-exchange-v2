// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {OwnableTwoSteps} from "@looksrare/contracts-libs/contracts/OwnableTwoSteps.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {IExecutionStrategy} from "../interfaces/IExecutionStrategy.sol";
import {OrderStructs} from "../libraries/OrderStructs.sol";

/**
 * @title StrategyUSDDynamicAsk
 * @author LooksRare protocol team (👀,💎)
 */
contract StrategyUSDDynamicAsk is IExecutionStrategy, OwnableTwoSteps {
    // Address of the protocol
    address public immutable LOOKSRARE_PROTOCOL;
    AggregatorV3Interface public priceFeed = AggregatorV3Interface(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
    uint256 public maximumLatency;

    error InvalidChainlinkPrice();
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

        uint256 ethPriceInUSD = uint256(answer) * 1e10;
        uint256 minPriceInETH = makerAsk.minPrice;
        uint256 desiredSalePriceInETH = (desiredSalePriceInUSD * 1e18) / ethPriceInUSD;

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
        revert OrderInvalid();
    }

    /**
     * @notice Set maximum Chainlink price latency
     * @dev Function only callable by contract owner
     * @param _maximumLatency Maximum Chainlink price latency
     */
    function setMaximumLatency(uint256 _maximumLatency) external onlyOwner {
        maximumLatency = _maximumLatency;
    }
}
