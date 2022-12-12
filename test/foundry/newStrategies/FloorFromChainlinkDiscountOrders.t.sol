// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Libraries and interfaces
import {OrderStructs} from "../../../contracts/libraries/OrderStructs.sol";
import {IExecutionStrategy} from "../../../contracts/interfaces/IExecutionStrategy.sol";
import {StrategyChainlinkPriceLatency} from "../../../contracts/executionStrategies/StrategyChainlinkPriceLatency.sol";
import {StrategyChainlinkMultiplePriceFeeds} from "../../../contracts/executionStrategies/StrategyChainlinkMultiplePriceFeeds.sol";
import {StrategyFloorFromChainlink} from "../../../contracts/executionStrategies/StrategyFloorFromChainlink.sol";
import {WrongCurrency} from "../../../contracts/interfaces/SharedErrors.sol";

// Mocks and other tests
import {MockChainlinkAggregator} from "../../mock/MockChainlinkAggregator.sol";
import {FloorFromChainlinkOrdersTest} from "./FloorFromChainlinkOrders.t.sol";

abstract contract FloorFromChainlinkDiscountOrdersTest is FloorFromChainlinkOrdersTest {
    uint256 internal discount;
    bytes4 private validityFunctionSelector;

    function testFloorFromChainlinkDiscountPriceFeedNotAvailable() public {
        (makerBid, takerAsk) = _createMakerBidAndTakerAsk({discount: discount});

        signature = _signMakerBid(makerBid, makerUserPK);

        vm.startPrank(_owner);
        strategyFloorFromChainlink.setMaximumLatency(MAXIMUM_LATENCY);
        vm.stopPrank();

        bytes4 errorSelector = _assertOrderInvalid(
            makerBid,
            StrategyChainlinkMultiplePriceFeeds.PriceFeedNotAvailable.selector
        );

        vm.expectRevert(errorSelector);
        _executeTakerAsk(takerAsk, makerBid, signature);
    }

    function testFloorFromChainlinkDiscountOraclePriceNotRecentEnough() public {
        (makerBid, takerAsk) = _createMakerBidAndTakerAsk({discount: discount});

        signature = _signMakerBid(makerBid, makerUserPK);

        vm.startPrank(_owner);
        strategyFloorFromChainlink.setPriceFeed(address(mockERC721), AZUKI_PRICE_FEED);
        vm.stopPrank();

        bytes4 errorSelector = _assertOrderInvalid(
            makerBid,
            StrategyChainlinkPriceLatency.PriceNotRecentEnough.selector
        );

        vm.expectRevert(errorSelector);
        _executeTakerAsk(takerAsk, makerBid, signature);
    }

    function testFloorFromChainlinkDiscountChainlinkPriceLessThanOrEqualToZero() public {
        MockChainlinkAggregator aggregator = new MockChainlinkAggregator();

        (makerBid, takerAsk) = _createMakerBidAndTakerAsk({discount: discount});

        signature = _signMakerBid(makerBid, makerUserPK);

        vm.startPrank(_owner);
        strategyFloorFromChainlink.setMaximumLatency(MAXIMUM_LATENCY);
        strategyFloorFromChainlink.setPriceFeed(address(mockERC721), address(aggregator));
        vm.stopPrank();

        bytes4 errorSelector = _assertOrderInvalid(makerBid, StrategyFloorFromChainlink.InvalidChainlinkPrice.selector);

        vm.expectRevert(errorSelector);
        _executeTakerAsk(takerAsk, makerBid, signature);

        aggregator.setAnswer(-1);
        errorSelector = _assertOrderInvalid(makerBid, StrategyFloorFromChainlink.InvalidChainlinkPrice.selector);

        vm.expectRevert(errorSelector);
        _executeTakerAsk(takerAsk, makerBid, signature);
    }

    function testFloorFromChainlinkDiscountCallerNotLooksRareProtocol() public {
        (makerBid, takerAsk) = _createMakerBidAndTakerAsk({discount: discount});

        _setPriceFeed();

        // Valid, but wrong caller
        _assertOrderValid(makerBid);

        vm.prank(takerUser);
        vm.expectRevert(IExecutionStrategy.WrongCaller.selector);
        // Call the function directly
        (bool success, ) = address(strategyFloorFromChainlink).call(
            abi.encodeWithSelector(selectorTakerAsk, takerAsk, makerBid)
        );
        assertTrue(success);
    }

    function testFloorFromChainlinkDiscountTakerAskItemIdsLengthNotOne() public {
        (makerBid, takerAsk) = _createMakerBidAndTakerAsk({discount: discount});

        takerAsk.itemIds = new uint256[](0);

        signature = _signMakerBid(makerBid, makerUserPK);

        _setPriceFeed();

        // Valid, taker struct validation only happens during execution
        _assertOrderValid(makerBid);

        vm.expectRevert(IExecutionStrategy.OrderInvalid.selector);
        _executeTakerAsk(takerAsk, makerBid, signature);
    }

    function testFloorFromChainlinkDiscountTakerAskAmountsLengthNotOne() public {
        (makerBid, takerAsk) = _createMakerBidAndTakerAsk({discount: discount});

        takerAsk.amounts = new uint256[](0);

        signature = _signMakerBid(makerBid, makerUserPK);

        _setPriceFeed();

        // Valid, taker struct validation only happens during execution
        _assertOrderValid(makerBid);

        vm.expectRevert(IExecutionStrategy.OrderInvalid.selector);
        _executeTakerAsk(takerAsk, makerBid, signature);
    }

    function testFloorFromChainlinkDiscountMakerBidAmountsLengthNotOne() public {
        (makerBid, takerAsk) = _createMakerBidAndTakerAsk({discount: discount});

        makerBid.amounts = new uint256[](0);

        signature = _signMakerBid(makerBid, makerUserPK);

        _setPriceFeed();

        bytes4 errorSelector = _assertOrderInvalid(makerBid);

        vm.expectRevert(errorSelector);
        _executeTakerAsk(takerAsk, makerBid, signature);
    }

    function testFloorFromChainlinkDiscountTakerAskZeroAmount() public {
        (makerBid, takerAsk) = _createMakerBidAndTakerAsk({discount: discount});

        uint256[] memory amounts = new uint256[](1);
        // Seller will probably try 0
        amounts[0] = 0;
        takerAsk.amounts = amounts;

        signature = _signMakerBid(makerBid, makerUserPK);

        _setPriceFeed();

        // Valid, taker struct validation only happens during execution
        _assertOrderValid(makerBid);

        vm.expectRevert(IExecutionStrategy.OrderInvalid.selector);
        _executeTakerAsk(takerAsk, makerBid, signature);
    }

    function testFloorFromChainlinkDiscountMakerBidAmountNotOne() public {
        (makerBid, takerAsk) = _createMakerBidAndTakerAsk({discount: discount});

        uint256[] memory amounts = new uint256[](1);
        // Bidder will probably try a higher number
        amounts[0] = 2;
        makerBid.amounts = amounts;

        signature = _signMakerBid(makerBid, makerUserPK);

        _setPriceFeed();

        bytes4 errorSelector = _assertOrderInvalid(makerBid);

        vm.expectRevert(errorSelector);
        _executeTakerAsk(takerAsk, makerBid, signature);
    }

    function testFloorFromChainlinkDiscountAskTooHigh() public {
        (makerBid, takerAsk) = _createMakerBidAndTakerAsk({discount: discount});
        makerBid.maxPrice = takerAsk.minPrice - 1 wei;

        signature = _signMakerBid(makerBid, makerUserPK);

        _setPriceFeed();

        // Valid, taker struct validation only happens during execution
        _assertOrderValid(makerBid);

        vm.expectRevert(IExecutionStrategy.AskTooHigh.selector);
        _executeTakerAsk(takerAsk, makerBid, signature);
    }

    function testFloorFromChainlinkDiscountWrongCurrency() public {
        (makerBid, takerAsk) = _createMakerBidAndTakerAsk({discount: discount});

        vm.prank(_owner);
        looksRareProtocol.updateCurrencyWhitelistStatus(address(looksRareToken), true);
        makerBid.currency = address(looksRareToken);

        signature = _signMakerBid(makerBid, makerUserPK);

        _setPriceFeed();

        bytes4 errorSelector = _assertOrderInvalid(makerBid, WrongCurrency.selector);

        vm.expectRevert(errorSelector);
        _executeTakerAsk(takerAsk, makerBid, signature);
    }

    function _setDiscount(uint256 _discount) internal {
        discount = _discount;
    }

    function _setValidityFunctionSelector(bytes4 _validityFunctionSelector) internal {
        validityFunctionSelector = _validityFunctionSelector;
    }

    function _assertOrderValid(OrderStructs.MakerBid memory makerBid) internal {
        (, bytes memory data) = address(strategyFloorFromChainlink).call(
            abi.encodeWithSelector(validityFunctionSelector, makerBid)
        );
        (bool isValid, bytes4 errorSelector) = abi.decode(data, (bool, bytes4));
        assertTrue(isValid);
        assertEq(errorSelector, bytes4(0));
    }

    function _assertOrderInvalid(OrderStructs.MakerBid memory makerBid) internal returns (bytes4) {
        return _assertOrderInvalid(makerBid, IExecutionStrategy.OrderInvalid.selector);
    }

    function _assertOrderInvalid(
        OrderStructs.MakerBid memory makerBid,
        bytes4 expectedError
    ) internal returns (bytes4) {
        (, bytes memory data) = address(strategyFloorFromChainlink).call(
            abi.encodeWithSelector(validityFunctionSelector, makerBid)
        );
        (bool isValid, bytes4 errorSelector) = abi.decode(data, (bool, bytes4));
        assertFalse(isValid);
        assertEq(errorSelector, expectedError);

        return errorSelector;
    }

    function _executeTakerAsk(
        OrderStructs.TakerAsk memory takerAsk,
        OrderStructs.MakerBid memory makerBid,
        bytes memory signature
    ) internal {
        vm.prank(takerUser);
        // Execute taker ask transaction
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _emptyMerkleTree, _emptyAffiliate);
    }
}
