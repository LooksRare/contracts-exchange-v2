// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Libraries and interfaces
import {OrderStructs} from "../../../../contracts/libraries/OrderStructs.sol";

// Errors and constants
import {AmountInvalid, BidTooLow, CurrencyInvalid, OrderInvalid} from "../../../../contracts/errors/SharedErrors.sol";
import {ChainlinkPriceInvalid, PriceFeedNotAvailable, PriceNotRecentEnough} from "../../../../contracts/errors/ChainlinkErrors.sol";
import {MAKER_ORDER_PERMANENTLY_INVALID_NON_STANDARD_SALE, MAKER_ORDER_TEMPORARILY_INVALID_NON_STANDARD_SALE} from "../../../../contracts/constants/ValidationCodeConstants.sol";

// Strategies
import {BaseStrategyChainlinkMultiplePriceFeeds} from "../../../../contracts/executionStrategies/Chainlink/BaseStrategyChainlinkMultiplePriceFeeds.sol";
import {StrategyChainlinkFloor} from "../../../../contracts/executionStrategies/Chainlink/StrategyChainlinkFloor.sol";

// Mock files and other tests
import {MockChainlinkAggregator} from "../../../mock/MockChainlinkAggregator.sol";
import {FloorFromChainlinkOrdersTest} from "./FloorFromChainlinkOrders.t.sol";

abstract contract FloorFromChainlinkPremiumOrdersTest is FloorFromChainlinkOrdersTest {
    uint256 internal premium;

    function setUp() public virtual override {
        super.setUp();
    }

    function testFloorFromChainlinkPremiumAdditionalParametersNotProvided() public {
        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.Taker memory takerBid) = _createMakerAskAndTakerBid({
            premium: premium
        });
        makerAsk.additionalParameters = new bytes(0);

        bytes memory signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.prank(_owner);
        strategyFloorFromChainlink.setPriceFeed(address(mockERC721), AZUKI_PRICE_FEED);

        bytes4 errorSelector = OrderInvalid.selector;

        _assertOrderIsInvalid(makerAsk, errorSelector);
        _doesMakerAskOrderReturnValidationCode(makerAsk, signature, MAKER_ORDER_PERMANENTLY_INVALID_NON_STANDARD_SALE);

        // EvmError: Revert
        vm.expectRevert();
        _executeTakerBid(takerBid, makerAsk, signature);
    }

    function testFloorFromChainlinkPremiumPriceFeedNotAvailable() public {
        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.Taker memory takerBid) = _createMakerAskAndTakerBid({
            premium: premium
        });

        bytes memory signature = _signMakerAsk(makerAsk, makerUserPK);

        bytes4 errorSelector = PriceFeedNotAvailable.selector;

        _assertOrderIsInvalid(makerAsk, errorSelector);
        _doesMakerAskOrderReturnValidationCode(makerAsk, signature, MAKER_ORDER_TEMPORARILY_INVALID_NON_STANDARD_SALE);

        vm.expectRevert(errorSelector);
        _executeTakerBid(takerBid, makerAsk, signature);
    }

    function testFloorFromChainlinkPremiumOraclePriceNotRecentEnough() public {
        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.Taker memory takerBid) = _createMakerAskAndTakerBid({
            premium: premium
        });

        makerAsk.startTime = CHAINLINK_PRICE_UPDATED_AT;
        uint256 latencyViolationTimestamp = CHAINLINK_PRICE_UPDATED_AT + MAXIMUM_LATENCY + 1 seconds;
        makerAsk.endTime = latencyViolationTimestamp;

        bytes memory signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.prank(_owner);
        strategyFloorFromChainlink.setPriceFeed(address(mockERC721), AZUKI_PRICE_FEED);

        vm.warp(latencyViolationTimestamp);

        bytes4 errorSelector = PriceNotRecentEnough.selector;

        _assertOrderIsInvalid(makerAsk, errorSelector);
        _doesMakerAskOrderReturnValidationCode(makerAsk, signature, MAKER_ORDER_TEMPORARILY_INVALID_NON_STANDARD_SALE);

        vm.expectRevert(errorSelector);
        _executeTakerBid(takerBid, makerAsk, signature);
    }

    function testFloorFromChainlinkPremiumChainlinkPriceLessThanOrEqualToZero() public {
        MockChainlinkAggregator aggregator = new MockChainlinkAggregator();

        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.Taker memory takerBid) = _createMakerAskAndTakerBid({
            premium: premium
        });

        bytes memory signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.prank(_owner);
        strategyFloorFromChainlink.setPriceFeed(address(mockERC721), address(aggregator));

        bytes4 errorSelector = ChainlinkPriceInvalid.selector;

        _assertOrderIsInvalid(makerAsk, errorSelector);
        _doesMakerAskOrderReturnValidationCode(makerAsk, signature, MAKER_ORDER_TEMPORARILY_INVALID_NON_STANDARD_SALE);

        vm.expectRevert(errorSelector);
        _executeTakerBid(takerBid, makerAsk, signature);

        aggregator.setAnswer(-1);
        vm.expectRevert(ChainlinkPriceInvalid.selector);
        _executeTakerBid(takerBid, makerAsk, signature);
    }

    function testFloorFromChainlinkPremiumMakerAskItemIdsLengthNotOne() public {
        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.Taker memory takerBid) = _createMakerAskAndTakerBid({
            premium: premium
        });

        makerAsk.itemIds = new uint256[](0);

        bytes memory signature = _signMakerAsk(makerAsk, makerUserPK);

        _setPriceFeed();

        bytes4 errorSelector = OrderInvalid.selector;

        _assertOrderIsInvalid(makerAsk, errorSelector);
        _doesMakerAskOrderReturnValidationCode(makerAsk, signature, MAKER_ORDER_PERMANENTLY_INVALID_NON_STANDARD_SALE);

        vm.expectRevert(errorSelector);
        _executeTakerBid(takerBid, makerAsk, signature);
    }

    function testFloorFromChainlinkPremiumMakerAskAmountsLengthNotOne() public {
        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.Taker memory takerBid) = _createMakerAskAndTakerBid({
            premium: premium
        });

        makerAsk.amounts = new uint256[](0);

        bytes memory signature = _signMakerAsk(makerAsk, makerUserPK);

        _setPriceFeed();

        bytes4 errorSelector = OrderInvalid.selector;

        _assertOrderIsInvalid(makerAsk, errorSelector);
        _doesMakerAskOrderReturnValidationCode(makerAsk, signature, MAKER_ORDER_PERMANENTLY_INVALID_NON_STANDARD_SALE);

        vm.expectRevert(errorSelector);
        _executeTakerBid(takerBid, makerAsk, signature);
    }

    function testFloorFromChainlinkPremiumMakerAskAmountNotOne() public {
        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.Taker memory takerBid) = _createMakerAskAndTakerBid({
            premium: premium
        });

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0;
        makerAsk.amounts = amounts;

        bytes memory signature = _signMakerAsk(makerAsk, makerUserPK);

        _setPriceFeed();

        _assertOrderIsInvalid(makerAsk, OrderInvalid.selector);
        _doesMakerAskOrderReturnValidationCode(makerAsk, signature, MAKER_ORDER_PERMANENTLY_INVALID_NON_STANDARD_SALE);

        vm.expectRevert(AmountInvalid.selector);
        _executeTakerBid(takerBid, makerAsk, signature);
    }

    function testFloorFromChainlinkPremiumBidTooLow() public {
        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.Taker memory takerBid) = _createMakerAskAndTakerBid({
            premium: premium
        });

        takerBid.additionalParameters = abi.encode(makerAsk.minPrice - 1 wei);

        bytes memory signature = _signMakerAsk(makerAsk, makerUserPK);

        _setPriceFeed();

        // Valid, taker struct validation only happens during execution
        _assertOrderIsValid(makerAsk);
        _assertValidMakerAskOrder(makerAsk, signature);

        vm.expectRevert(BidTooLow.selector);
        _executeTakerBid(takerBid, makerAsk, signature);
    }

    function testFloorFromChainlinkPremiumCurrencyInvalid() public {
        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.Taker memory takerBid) = _createMakerAskAndTakerBid({
            premium: premium
        });

        vm.prank(_owner);
        looksRareProtocol.updateCurrencyStatus(address(looksRareToken), true);
        makerAsk.currency = address(looksRareToken);

        bytes memory signature = _signMakerAsk(makerAsk, makerUserPK);

        _setPriceFeed();

        bytes4 errorSelector = CurrencyInvalid.selector;

        _assertOrderIsInvalid(makerAsk, errorSelector);
        _doesMakerAskOrderReturnValidationCode(makerAsk, signature, MAKER_ORDER_TEMPORARILY_INVALID_NON_STANDARD_SALE);

        vm.expectRevert(errorSelector);
        _executeTakerBid(takerBid, makerAsk, signature);
    }

    function _executeTakerBid(
        OrderStructs.Taker memory takerBid,
        OrderStructs.MakerAsk memory makerAsk,
        bytes memory signature
    ) internal {
        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerBid(takerBid, makerAsk, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function _setPremium(uint256 _premium) internal {
        premium = _premium;
    }

    function _assertOrderIsValid(OrderStructs.MakerAsk memory makerAsk) private {
        (bool isValid, bytes4 errorSelector) = strategyFloorFromChainlink.isMakerAskValid(makerAsk, selector);
        assertTrue(isValid);
        assertEq(errorSelector, _EMPTY_BYTES4);
    }

    function _assertOrderIsInvalid(OrderStructs.MakerAsk memory makerAsk, bytes4 expectedErrorSelector) private {
        (bool isValid, bytes4 errorSelector) = strategyFloorFromChainlink.isMakerAskValid(makerAsk, selector);
        assertFalse(isValid);
        assertEq(errorSelector, expectedErrorSelector);
    }
}
