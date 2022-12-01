// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IOwnableTwoSteps} from "@looksrare/contracts-libs/contracts/interfaces/IOwnableTwoSteps.sol";
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";
import {IExecutionStrategy} from "../../contracts/interfaces/IExecutionStrategy.sol";
import {StrategyChainlinkPriceLatency} from "../../contracts/executionStrategies/StrategyChainlinkPriceLatency.sol";
import {StrategyChainlinkMultiplePriceFeeds} from "../../contracts/executionStrategies/StrategyChainlinkMultiplePriceFeeds.sol";
import {StrategyFloorFromChainlink} from "../../contracts/executionStrategies/StrategyFloorFromChainlink.sol";
import {MockChainlinkAggregator} from "../mock/MockChainlinkAggregator.sol";
import {FloorFromChainlinkDiscountOrdersTest} from "./FloorFromChainlinkDiscountOrders.t.sol";

contract FloorFromChainlinkDiscountPercentageOrdersTest is FloorFromChainlinkDiscountOrdersTest {
    function setUp() public override {
        _setIsFixedAmount(0);
        _setDiscount(100);
        _setValidityFunctionSelector(StrategyFloorFromChainlink.isPercentageDiscountMakerBidValid.selector);
        _setSelectorTakerAsk(StrategyFloorFromChainlink.executePercentageDiscountStrategyWithTakerAsk.selector);
        super.setUp();
    }

    function testFloorFromChainlinkDiscountPercentageDesiredDiscountedPriceGreaterThanOrEqualToMaxPrice() public {
        // Floor price = 9.7 ETH, discount = 1%, desired price = 9.603 ETH
        // Max price = 9.5 ETH
        (makerBid, takerAsk) = _createMakerBidAndTakerAsk({discount: discount});

        makerBid.maxPrice = 9.5 ether;
        takerAsk.minPrice = 9.5 ether;

        signature = _signMakerBid(makerBid, makerUserPK);

        _setPriceFeed();

        (bool isValid, bytes4 errorSelector) = strategyFloorFromChainlink.isPercentageDiscountMakerBidValid(makerBid);
        assertTrue(isValid);
        assertEq(errorSelector, bytes4(0));

        _executeTakerAsk(takerAsk, makerBid, signature);

        // Maker user has received the asset
        assertEq(mockERC721.ownerOf(1), makerUser);

        // Maker bid user pays the whole price
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser - 9.5 ether);
        // Taker ask user receives 98% of the whole price (2% protocol)
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser + 9.31 ether);
    }

    function testFloorFromChainlinkDiscountPercentageDesiredDiscountedPriceLessThanMaxPrice() public {
        // Floor price = 9.7 ETH, discount = 3%, desired price = 9.409 ETH
        // Max price = 9.5 ETH
        (makerBid, takerAsk) = _createMakerBidAndTakerAsk({discount: 300});

        takerAsk.minPrice = 9.409 ether;

        signature = _signMakerBid(makerBid, makerUserPK);

        _setPriceFeed();

        (bool isValid, bytes4 errorSelector) = strategyFloorFromChainlink.isPercentageDiscountMakerBidValid(makerBid);
        assertTrue(isValid);
        assertEq(errorSelector, bytes4(0));

        _executeTakerAsk(takerAsk, makerBid, signature);

        // Maker user has received the asset
        assertEq(mockERC721.ownerOf(1), makerUser);

        // Maker bid user pays the whole price
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser - 9.409 ether);
        // Taker ask user receives 98% of the whole price (2% protocol)
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser + 9.22082 ether);
    }

    function testFloorFromChainlinkDiscountPercentageDesiredDiscountPercentageGreaterThan100() public {
        // Floor price = 9.7 ETH, discount = 101%, desired price = negative
        // Max price = negative
        (makerBid, takerAsk) = _createMakerBidAndTakerAsk({discount: 10_001});

        signature = _signMakerBid(makerBid, makerUserPK);

        _setPriceFeed();

        (bool isValid, bytes4 errorSelector) = strategyFloorFromChainlink.isPercentageDiscountMakerBidValid(makerBid);
        assertFalse(isValid);
        assertEq(errorSelector, IExecutionStrategy.OrderInvalid.selector);

        vm.expectRevert(IExecutionStrategy.OrderInvalid.selector);
        _executeTakerAsk(takerAsk, makerBid, signature);
    }
}
