// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";
import {IExecutionStrategy} from "../../contracts/interfaces/IExecutionStrategy.sol";
import {StrategyChainlinkPriceLatency} from "../../contracts/executionStrategies/StrategyChainlinkPriceLatency.sol";
import {StrategyChainlinkMultiplePriceFeeds} from "../../contracts/executionStrategies/StrategyChainlinkMultiplePriceFeeds.sol";
import {StrategyFloor} from "../../contracts/executionStrategies/StrategyFloor.sol";
import {MockChainlinkAggregator} from "../mock/MockChainlinkAggregator.sol";
import {FloorOrdersTest} from "./FloorOrders.t.sol";

abstract contract FloorDiscountOrdersTest is FloorOrdersTest {
    uint256 internal discount;
    bytes4 private validityFunctionSelector;

    function testFloorDiscountPriceFeedNotAvailable() public {
        (makerBid, takerAsk) = _createMakerBidAndTakerAsk({discount: discount});

        signature = _signMakerBid(makerBid, makerUserPK);

        vm.startPrank(_owner);
        strategyFloor.setMaximumLatency(MAXIMUM_LATENCY);
        vm.stopPrank();

        (, bytes memory data) = address(strategyFloor).call(abi.encodeWithSelector(validityFunctionSelector, makerBid));
        (bool isValid, bytes4 errorSelector) = abi.decode(data, (bool, bytes4));
        assertFalse(isValid);
        assertEq(errorSelector, StrategyChainlinkMultiplePriceFeeds.PriceFeedNotAvailable.selector);

        vm.expectRevert(errorSelector);
        vm.prank(takerUser);
        // Execute taker ask transaction
        looksRareProtocol.executeTakerAsk(
            takerAsk,
            makerBid,
            signature,
            _emptyMerkleRoot,
            _emptyMerkleProof,
            _emptyAffiliate
        );
    }

    function testFloorDiscountOraclePriceNotRecentEnough() public {
        (makerBid, takerAsk) = _createMakerBidAndTakerAsk({discount: discount});

        signature = _signMakerBid(makerBid, makerUserPK);

        vm.startPrank(_owner);
        strategyFloor.setPriceFeed(address(mockERC721), AZUKI_PRICE_FEED);
        vm.stopPrank();

        (, bytes memory data) = address(strategyFloor).call(abi.encodeWithSelector(validityFunctionSelector, makerBid));
        (bool isValid, bytes4 errorSelector) = abi.decode(data, (bool, bytes4));
        assertFalse(isValid);
        assertEq(errorSelector, StrategyChainlinkPriceLatency.PriceNotRecentEnough.selector);

        vm.expectRevert(errorSelector);
        vm.prank(takerUser);
        // Execute taker ask transaction
        looksRareProtocol.executeTakerAsk(
            takerAsk,
            makerBid,
            signature,
            _emptyMerkleRoot,
            _emptyMerkleProof,
            _emptyAffiliate
        );
    }

    function testFloorDiscountChainlinkPriceLessThanOrEqualToZero() public {
        MockChainlinkAggregator aggregator = new MockChainlinkAggregator();

        (makerBid, takerAsk) = _createMakerBidAndTakerAsk({discount: discount});

        signature = _signMakerBid(makerBid, makerUserPK);

        vm.startPrank(_owner);
        strategyFloor.setMaximumLatency(MAXIMUM_LATENCY);
        strategyFloor.setPriceFeed(address(mockERC721), address(aggregator));
        vm.stopPrank();

        (, bytes memory data) = address(strategyFloor).call(abi.encodeWithSelector(validityFunctionSelector, makerBid));
        (bool isValid, bytes4 errorSelector) = abi.decode(data, (bool, bytes4));
        assertFalse(isValid);
        assertEq(errorSelector, StrategyFloor.InvalidChainlinkPrice.selector);

        vm.expectRevert(errorSelector);
        vm.prank(takerUser);
        // Execute taker ask transaction
        looksRareProtocol.executeTakerAsk(
            takerAsk,
            makerBid,
            signature,
            _emptyMerkleRoot,
            _emptyMerkleProof,
            _emptyAffiliate
        );

        aggregator.setAnswer(-1);
        vm.expectRevert(StrategyFloor.InvalidChainlinkPrice.selector);
        vm.prank(takerUser);
        // Execute taker ask transaction
        looksRareProtocol.executeTakerAsk(
            takerAsk,
            makerBid,
            signature,
            _emptyMerkleRoot,
            _emptyMerkleProof,
            _emptyAffiliate
        );
    }

    function testFloorDiscountCallerNotLooksRareProtocol() public {
        (makerBid, takerAsk) = _createMakerBidAndTakerAsk({discount: discount});

        _setPriceFeed();

        // Valid, but wrong caller
        _assertOrderValid(makerBid);

        vm.prank(takerUser);
        vm.expectRevert(IExecutionStrategy.WrongCaller.selector);
        // Call the function directly
        address(strategyFloor).call(abi.encodeWithSelector(selectorTakerAsk, takerAsk, makerBid));
    }

    function testFloorDiscountTakerAskItemIdsLengthNotOne() public {
        (makerBid, takerAsk) = _createMakerBidAndTakerAsk({discount: discount});

        takerAsk.itemIds = new uint256[](0);

        signature = _signMakerBid(makerBid, makerUserPK);

        _setPriceFeed();

        // Valid, taker struct validation only happens during execution
        _assertOrderValid(makerBid);

        vm.prank(takerUser);
        vm.expectRevert(IExecutionStrategy.OrderInvalid.selector);
        // Execute taker ask transaction
        looksRareProtocol.executeTakerAsk(
            takerAsk,
            makerBid,
            signature,
            _emptyMerkleRoot,
            _emptyMerkleProof,
            _emptyAffiliate
        );
    }

    function testFloorDiscountTakerAskAmountsLengthNotOne() public {
        (makerBid, takerAsk) = _createMakerBidAndTakerAsk({discount: discount});

        takerAsk.amounts = new uint256[](0);

        signature = _signMakerBid(makerBid, makerUserPK);

        _setPriceFeed();

        // Valid, taker struct validation only happens during execution
        _assertOrderValid(makerBid);

        vm.prank(takerUser);
        vm.expectRevert(IExecutionStrategy.OrderInvalid.selector);
        // Execute taker ask transaction
        looksRareProtocol.executeTakerAsk(
            takerAsk,
            makerBid,
            signature,
            _emptyMerkleRoot,
            _emptyMerkleProof,
            _emptyAffiliate
        );
    }

    function testFloorDiscountMakerBidAmountsLengthNotOne() public {
        (makerBid, takerAsk) = _createMakerBidAndTakerAsk({discount: discount});

        makerBid.amounts = new uint256[](0);

        signature = _signMakerBid(makerBid, makerUserPK);

        _setPriceFeed();

        bytes4 errorSelector = _assertOrderInvalid(makerBid);

        vm.prank(takerUser);
        vm.expectRevert(errorSelector);
        // Execute taker ask transaction
        looksRareProtocol.executeTakerAsk(
            takerAsk,
            makerBid,
            signature,
            _emptyMerkleRoot,
            _emptyMerkleProof,
            _emptyAffiliate
        );
    }

    function testFloorDiscountTakerAskZeroAmount() public {
        (makerBid, takerAsk) = _createMakerBidAndTakerAsk({discount: discount});

        uint256[] memory amounts = new uint256[](1);
        // Seller will probably try 0
        amounts[0] = 0;
        takerAsk.amounts = amounts;

        signature = _signMakerBid(makerBid, makerUserPK);

        _setPriceFeed();

        // Valid, taker struct validation only happens during execution
        _assertOrderValid(makerBid);

        vm.prank(takerUser);
        vm.expectRevert(IExecutionStrategy.OrderInvalid.selector);
        // Execute taker ask transaction
        looksRareProtocol.executeTakerAsk(
            takerAsk,
            makerBid,
            signature,
            _emptyMerkleRoot,
            _emptyMerkleProof,
            _emptyAffiliate
        );
    }

    function testFloorDiscountMakerBidAmountNotOne() public {
        (makerBid, takerAsk) = _createMakerBidAndTakerAsk({discount: discount});

        uint256[] memory amounts = new uint256[](1);
        // Bidder will probably try a higher number
        amounts[0] = 2;
        makerBid.amounts = amounts;

        signature = _signMakerBid(makerBid, makerUserPK);

        _setPriceFeed();

        bytes4 errorSelector = _assertOrderInvalid(makerBid);

        vm.prank(takerUser);
        vm.expectRevert(errorSelector);
        // Execute taker ask transaction
        looksRareProtocol.executeTakerAsk(
            takerAsk,
            makerBid,
            signature,
            _emptyMerkleRoot,
            _emptyMerkleProof,
            _emptyAffiliate
        );
    }

    function testFloorDiscountBidTooLow() public {
        (makerBid, takerAsk) = _createMakerBidAndTakerAsk({discount: discount});
        makerBid.maxPrice = takerAsk.minPrice - 1 wei;

        signature = _signMakerBid(makerBid, makerUserPK);

        _setPriceFeed();

        // Valid, taker struct validation only happens during execution
        _assertOrderValid(makerBid);

        vm.expectRevert(IExecutionStrategy.BidTooLow.selector);
        vm.prank(takerUser);
        // Execute taker ask transaction
        looksRareProtocol.executeTakerAsk(
            takerAsk,
            makerBid,
            signature,
            _emptyMerkleRoot,
            _emptyMerkleProof,
            _emptyAffiliate
        );
    }

    function _setDiscount(uint256 _discount) internal {
        discount = _discount;
    }

    function _setValidityFunctionSelector(bytes4 _validityFunctionSelector) internal {
        validityFunctionSelector = _validityFunctionSelector;
    }

    function _assertOrderValid(OrderStructs.MakerBid memory makerBid) internal {
        (, bytes memory data) = address(strategyFloor).call(abi.encodeWithSelector(validityFunctionSelector, makerBid));
        (bool isValid, bytes4 errorSelector) = abi.decode(data, (bool, bytes4));
        assertTrue(isValid);
        assertEq(errorSelector, bytes4(0));
    }

    function _assertOrderInvalid(OrderStructs.MakerBid memory makerBid) internal returns (bytes4) {
        (, bytes memory data) = address(strategyFloor).call(abi.encodeWithSelector(validityFunctionSelector, makerBid));
        (bool isValid, bytes4 errorSelector) = abi.decode(data, (bool, bytes4));
        assertFalse(isValid);
        assertEq(errorSelector, IExecutionStrategy.OrderInvalid.selector);

        return errorSelector;
    }
}
