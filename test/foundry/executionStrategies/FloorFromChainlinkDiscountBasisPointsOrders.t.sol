// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// LooksRare libraries
import {IOwnableTwoSteps} from "@looksrare/contracts-libs/contracts/interfaces/IOwnableTwoSteps.sol";

// Libraries and interfaces
import {OrderStructs} from "../../../contracts/libraries/OrderStructs.sol";
import {IExecutionManager} from "../../../contracts/interfaces/IExecutionManager.sol";

// Shared errors
import "../../../contracts/interfaces/SharedErrors.sol";

// Strategies
import {StrategyChainlinkPriceLatency} from "../../../contracts/executionStrategies/Chainlink/StrategyChainlinkPriceLatency.sol";
import {StrategyChainlinkMultiplePriceFeeds} from "../../../contracts/executionStrategies/Chainlink/StrategyChainlinkMultiplePriceFeeds.sol";
import {StrategyFloorFromChainlink} from "../../../contracts/executionStrategies/Chainlink/StrategyFloorFromChainlink.sol";

// Mocks and other tests
import {MockChainlinkAggregator} from "../../mock/MockChainlinkAggregator.sol";
import {FloorFromChainlinkDiscountOrdersTest} from "./FloorFromChainlinkDiscountOrders.t.sol";

contract FloorFromChainlinkDiscountBasisPointsOrdersTest is FloorFromChainlinkDiscountOrdersTest {
    function setUp() public override {
        _setIsFixedAmount(0);
        _setDiscount(100);
        _setValidityFunctionSelector(StrategyFloorFromChainlink.isBasisPointsDiscountMakerBidValid.selector);
        _setSelector(StrategyFloorFromChainlink.executeBasisPointsDiscountStrategyWithTakerAsk.selector, true);
        super.setUp();
    }

    function testInactiveStrategy() public {
        (OrderStructs.MakerBid memory makerBid, OrderStructs.TakerAsk memory takerAsk) = _createMakerBidAndTakerAsk({
            discount: discount
        });

        makerBid.maxPrice = 9.5 ether;
        takerAsk.minPrice = 9.5 ether;

        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        _setPriceFeed();

        (bool isValid, bytes4 errorSelector) = strategyFloorFromChainlink.isBasisPointsDiscountMakerBidValid(makerBid);
        assertTrue(isValid);
        assertEq(errorSelector, bytes4(0));

        vm.prank(_owner);
        looksRareProtocol.updateStrategy(1, _standardProtocolFeeBp, _minTotalFeeBp, false);

        vm.expectRevert(abi.encodeWithSelector(IExecutionManager.StrategyNotAvailable.selector, 1));
        _executeTakerAsk(takerAsk, makerBid, signature);
    }

    function testFloorFromChainlinkDiscountBasisPointsDesiredDiscountedPriceGreaterThanOrEqualToMaxPrice() public {
        // Floor price = 9.7 ETH, discount = 1%, desired price = 9.603 ETH
        // Max price = 9.5 ETH
        (OrderStructs.MakerBid memory makerBid, OrderStructs.TakerAsk memory takerAsk) = _createMakerBidAndTakerAsk({
            discount: discount
        });

        makerBid.maxPrice = 9.5 ether;
        takerAsk.minPrice = 9.5 ether;

        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        _setPriceFeed();

        (bool isValid, bytes4 errorSelector) = strategyFloorFromChainlink.isBasisPointsDiscountMakerBidValid(makerBid);
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

    function testFloorFromChainlinkDiscountBasisPointsDesiredDiscountedPriceLessThanMaxPrice() public {
        // Floor price = 9.7 ETH, discount = 3%, desired price = 9.409 ETH
        // Max price = 9.5 ETH
        (OrderStructs.MakerBid memory makerBid, OrderStructs.TakerAsk memory takerAsk) = _createMakerBidAndTakerAsk({
            discount: 300
        });

        makerBid.maxPrice = 9.41 ether;

        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        _setPriceFeed();

        (bool isValid, bytes4 errorSelector) = strategyFloorFromChainlink.isBasisPointsDiscountMakerBidValid(makerBid);
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

    function testFloorFromChainlinkDiscountBasisPointsDesiredDiscountBasisPointsGreaterThan10000() public {
        // Floor price = 9.7 ETH, discount = 101%, desired price = negative
        // Max price = negative
        (OrderStructs.MakerBid memory makerBid, OrderStructs.TakerAsk memory takerAsk) = _createMakerBidAndTakerAsk({
            discount: 10_001
        });

        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        _setPriceFeed();

        (bool isValid, bytes4 errorSelector) = strategyFloorFromChainlink.isBasisPointsDiscountMakerBidValid(makerBid);
        assertFalse(isValid);
        assertEq(errorSelector, OrderInvalid.selector);

        vm.expectRevert(OrderInvalid.selector);
        _executeTakerAsk(takerAsk, makerBid, signature);
    }
}
