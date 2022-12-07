// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FloorFromChainlinkOrdersTest} from "./FloorFromChainlinkOrders.t.sol";
import {WrongCurrency} from "../../contracts/Errors.sol";
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";
import {StrategyChainlinkMultiplePriceFeeds} from "../../contracts/executionStrategies/StrategyChainlinkMultiplePriceFeeds.sol";
import {StrategyChainlinkPriceLatency} from "../../contracts/executionStrategies/StrategyChainlinkPriceLatency.sol";
import {StrategyFloorFromChainlink} from "../../contracts/executionStrategies/StrategyFloorFromChainlink.sol";
import {IExecutionStrategy} from "../../contracts/interfaces/IExecutionStrategy.sol";
import {MockChainlinkAggregator} from "../mock/MockChainlinkAggregator.sol";

abstract contract FloorFromChainlinkPremiumOrdersTest is FloorFromChainlinkOrdersTest {
    uint256 internal premium;

    function testFloorFromChainlinkPremiumPriceFeedNotAvailable() public {
        (makerAsk, takerBid) = _createMakerAskAndTakerBid({premium: premium});

        signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.startPrank(_owner);
        strategyFloorFromChainlink.setMaximumLatency(MAXIMUM_LATENCY);
        vm.stopPrank();

        bytes4 errorSelector = _assertOrderInvalid(
            makerAsk,
            StrategyChainlinkMultiplePriceFeeds.PriceFeedNotAvailable.selector
        );

        vm.expectRevert(errorSelector);
        _executeTakerBid(takerBid, makerAsk, signature);
    }

    function testFloorFromChainlinkPremiumOraclePriceNotRecentEnough() public {
        (makerAsk, takerBid) = _createMakerAskAndTakerBid({premium: premium});

        signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.startPrank(_owner);
        strategyFloorFromChainlink.setPriceFeed(address(mockERC721), AZUKI_PRICE_FEED);
        vm.stopPrank();

        bytes4 errorSelector = _assertOrderInvalid(
            makerAsk,
            StrategyChainlinkPriceLatency.PriceNotRecentEnough.selector
        );

        vm.expectRevert(errorSelector);
        _executeTakerBid(takerBid, makerAsk, signature);
    }

    function testFloorFromChainlinkPremiumChainlinkPriceLessThanOrEqualToZero() public {
        MockChainlinkAggregator aggregator = new MockChainlinkAggregator();

        (makerAsk, takerBid) = _createMakerAskAndTakerBid({premium: premium});

        signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.startPrank(_owner);
        strategyFloorFromChainlink.setMaximumLatency(MAXIMUM_LATENCY);
        strategyFloorFromChainlink.setPriceFeed(address(mockERC721), address(aggregator));
        vm.stopPrank();

        bytes4 errorSelector = _assertOrderInvalid(makerAsk, StrategyFloorFromChainlink.InvalidChainlinkPrice.selector);

        vm.expectRevert(errorSelector);
        _executeTakerBid(takerBid, makerAsk, signature);

        aggregator.setAnswer(-1);
        vm.expectRevert(StrategyFloorFromChainlink.InvalidChainlinkPrice.selector);
        _executeTakerBid(takerBid, makerAsk, signature);
    }

    function testFloorFromChainlinkPremiumMakerAskItemIdsLengthNotOne() public {
        (makerAsk, takerBid) = _createMakerAskAndTakerBid({premium: premium});

        makerAsk.itemIds = new uint256[](0);

        signature = _signMakerAsk(makerAsk, makerUserPK);

        _setPriceFeed();

        bytes4 errorSelector = _assertOrderInvalid(makerAsk);

        vm.expectRevert(errorSelector);
        _executeTakerBid(takerBid, makerAsk, signature);
    }

    function testFloorFromChainlinkPremiumMakerAskAmountsLengthNotOne() public {
        (makerAsk, takerBid) = _createMakerAskAndTakerBid({premium: premium});

        makerAsk.amounts = new uint256[](0);

        signature = _signMakerAsk(makerAsk, makerUserPK);

        _setPriceFeed();

        bytes4 errorSelector = _assertOrderInvalid(makerAsk);

        vm.expectRevert(errorSelector);
        _executeTakerBid(takerBid, makerAsk, signature);
    }

    function testFloorFromChainlinkPremiumMakerAskAmountNotOne() public {
        (makerAsk, takerBid) = _createMakerAskAndTakerBid({premium: premium});

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0;
        makerAsk.amounts = amounts;

        signature = _signMakerAsk(makerAsk, makerUserPK);

        _setPriceFeed();

        bytes4 errorSelector = _assertOrderInvalid(makerAsk);

        vm.expectRevert(errorSelector);
        _executeTakerBid(takerBid, makerAsk, signature);
    }

    function testFloorFromChainlinkPremiumTakerBidAmountNotOne() public {
        (makerAsk, takerBid) = _createMakerAskAndTakerBid({premium: premium});

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0;
        takerBid.amounts = amounts;

        signature = _signMakerAsk(makerAsk, makerUserPK);

        _setPriceFeed();

        // Valid, taker struct validation only happens during execution
        _assertOrderValid(makerAsk);

        vm.expectRevert(IExecutionStrategy.OrderInvalid.selector);
        _executeTakerBid(takerBid, makerAsk, signature);
    }

    function testFloorFromChainlinkPremiumMakerAskTakerBidItemIdsMismatch() public {
        (makerAsk, takerBid) = _createMakerAskAndTakerBid({premium: premium});

        uint256[] memory itemIds = new uint256[](1);
        itemIds[0] = 2;
        takerBid.itemIds = itemIds;

        signature = _signMakerAsk(makerAsk, makerUserPK);

        _setPriceFeed();

        // Valid, taker struct validation only happens during execution
        _assertOrderValid(makerAsk);

        vm.expectRevert(IExecutionStrategy.OrderInvalid.selector);
        _executeTakerBid(takerBid, makerAsk, signature);
    }

    function testFloorFromChainlinkPremiumBidTooLow() public {
        (makerAsk, takerBid) = _createMakerAskAndTakerBid({premium: premium});

        takerBid.maxPrice = makerAsk.minPrice - 1 wei;

        signature = _signMakerAsk(makerAsk, makerUserPK);

        _setPriceFeed();

        // Valid, taker struct validation only happens during execution
        _assertOrderValid(makerAsk);

        vm.expectRevert(IExecutionStrategy.BidTooLow.selector);
        _executeTakerBid(takerBid, makerAsk, signature);
    }

    function testFloorFromChainlinkPremiumCallerNotLooksRareProtocol() public {
        (makerAsk, takerBid) = _createMakerAskAndTakerBid({premium: premium});

        signature = _signMakerAsk(makerAsk, makerUserPK);

        _setPriceFeed();

        // Valid, but wrong caller
        _assertOrderValid(makerAsk);

        vm.prank(takerUser);
        vm.expectRevert(IExecutionStrategy.WrongCaller.selector);
        // Call the function directly
        address(strategyFloorFromChainlink).call(abi.encodeWithSelector(selectorTakerBid, takerBid, makerAsk));
    }

    function testFloorFromChainlinkPremiumWrongCurrency() public {
        (makerAsk, takerBid) = _createMakerAskAndTakerBid({premium: premium});

        vm.prank(_owner);
        looksRareProtocol.addCurrency(address(looksRareToken));
        makerAsk.currency = address(looksRareToken);

        signature = _signMakerAsk(makerAsk, makerUserPK);

        _setPriceFeed();

        bytes4 errorSelector = _assertOrderInvalid(makerAsk, WrongCurrency.selector);

        vm.expectRevert(errorSelector);
        _executeTakerBid(takerBid, makerAsk, signature);
    }

    function _assertOrderValid(OrderStructs.MakerAsk memory makerAsk) internal {
        (bool isValid, bytes4 errorSelector) = strategyFloorFromChainlink.isMakerAskValid(makerAsk);
        assertTrue(isValid);
        assertEq(errorSelector, bytes4(0));
    }

    function _assertOrderInvalid(OrderStructs.MakerAsk memory makerAsk) internal returns (bytes4) {
        return _assertOrderInvalid(makerAsk, IExecutionStrategy.OrderInvalid.selector);
    }

    function _assertOrderInvalid(
        OrderStructs.MakerAsk memory makerAsk,
        bytes4 expectedError
    ) internal returns (bytes4) {
        (bool isValid, bytes4 errorSelector) = strategyFloorFromChainlink.isMakerAskValid(makerAsk);
        assertFalse(isValid);
        assertEq(errorSelector, expectedError);

        return errorSelector;
    }

    function _executeTakerBid(
        OrderStructs.TakerBid memory takerBid,
        OrderStructs.MakerAsk memory makerAsk,
        bytes memory signature
    ) internal {
        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerBid(takerBid, makerAsk, signature, _emptyMerkleRoot, _emptyAffiliate);
    }

    function _setPremium(uint256 _premium) internal {
        premium = _premium;
    }
}
