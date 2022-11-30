// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FloorOrdersTest} from "./FloorOrders.t.sol";
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";
import {StrategyChainlinkMultiplePriceFeeds} from "../../contracts/executionStrategies/StrategyChainlinkMultiplePriceFeeds.sol";
import {StrategyChainlinkPriceLatency} from "../../contracts/executionStrategies/StrategyChainlinkPriceLatency.sol";
import {MockChainlinkAggregator} from "../mock/MockChainlinkAggregator.sol";
import {IExecutionStrategy} from "../../contracts/interfaces/IExecutionStrategy.sol";
import {StrategyFloor} from "../../contracts/executionStrategies/StrategyFloor.sol";

abstract contract FloorPremiumOrdersTest is FloorOrdersTest {
    uint256 internal premium;

    function _setPremium(uint256 _premium) internal {
        premium = _premium;
    }

    function testPriceFeedNotAvailable() public {
        (makerAsk, takerBid) = _createMakerAskAndTakerBid({premium: premium});

        signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.startPrank(_owner);
        strategyFloor.setMaximumLatency(MAXIMUM_LATENCY);
        vm.stopPrank();

        (bool isValid, bytes4 errorSelector) = strategyFloor.isMakerAskValid(makerAsk);
        assertFalse(isValid);
        assertEq(errorSelector, StrategyChainlinkMultiplePriceFeeds.PriceFeedNotAvailable.selector);

        vm.expectRevert(errorSelector);
        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerBid(
            takerBid,
            makerAsk,
            signature,
            _emptyMerkleRoot,
            _emptyMerkleProof,
            _emptyAffiliate
        );
    }

    function testOraclePriceNotRecentEnough() public {
        (makerAsk, takerBid) = _createMakerAskAndTakerBid({premium: premium});

        signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.startPrank(_owner);
        strategyFloor.setPriceFeed(address(mockERC721), AZUKI_PRICE_FEED);
        vm.stopPrank();

        (bool isValid, bytes4 errorSelector) = strategyFloor.isMakerAskValid(makerAsk);
        assertFalse(isValid);
        assertEq(errorSelector, StrategyChainlinkPriceLatency.PriceNotRecentEnough.selector);

        vm.expectRevert(errorSelector);
        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerBid(
            takerBid,
            makerAsk,
            signature,
            _emptyMerkleRoot,
            _emptyMerkleProof,
            _emptyAffiliate
        );
    }

    function testChainlinkPriceLessThanOrEqualToZero() public {
        MockChainlinkAggregator aggregator = new MockChainlinkAggregator();

        (makerAsk, takerBid) = _createMakerAskAndTakerBid({premium: premium});

        signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.startPrank(_owner);
        strategyFloor.setMaximumLatency(MAXIMUM_LATENCY);
        strategyFloor.setPriceFeed(address(mockERC721), address(aggregator));
        vm.stopPrank();

        (bool isValid, bytes4 errorSelector) = strategyFloor.isMakerAskValid(makerAsk);
        assertFalse(isValid);
        assertEq(errorSelector, StrategyFloor.InvalidChainlinkPrice.selector);

        vm.expectRevert(errorSelector);
        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerBid(
            takerBid,
            makerAsk,
            signature,
            _emptyMerkleRoot,
            _emptyMerkleProof,
            _emptyAffiliate
        );

        aggregator.setAnswer(-1);
        vm.expectRevert(StrategyFloor.InvalidChainlinkPrice.selector);
        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerBid(
            takerBid,
            makerAsk,
            signature,
            _emptyMerkleRoot,
            _emptyMerkleProof,
            _emptyAffiliate
        );
    }

    function testMakerAskItemIdsLengthNotOne() public {
        (makerAsk, takerBid) = _createMakerAskAndTakerBid({premium: premium});

        uint256[] memory itemIds = new uint256[](0);
        makerAsk.itemIds = itemIds;

        signature = _signMakerAsk(makerAsk, makerUserPK);

        _setPriceFeed();

        bytes4 errorSelector = _assertOrderInvalid(makerAsk);

        vm.expectRevert(errorSelector);
        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerBid(
            takerBid,
            makerAsk,
            signature,
            _emptyMerkleRoot,
            _emptyMerkleProof,
            _emptyAffiliate
        );
    }

    function testMakerAskAmountsLengthNotOne() public {
        (makerAsk, takerBid) = _createMakerAskAndTakerBid({premium: premium});

        uint256[] memory amounts = new uint256[](0);
        makerAsk.amounts = amounts;

        signature = _signMakerAsk(makerAsk, makerUserPK);

        _setPriceFeed();

        bytes4 errorSelector = _assertOrderInvalid(makerAsk);

        vm.expectRevert(errorSelector);
        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerBid(
            takerBid,
            makerAsk,
            signature,
            _emptyMerkleRoot,
            _emptyMerkleProof,
            _emptyAffiliate
        );
    }

    function testMakerAskAmountNotOne() public {
        (makerAsk, takerBid) = _createMakerAskAndTakerBid({premium: premium});

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0;
        makerAsk.amounts = amounts;

        signature = _signMakerAsk(makerAsk, makerUserPK);

        _setPriceFeed();

        bytes4 errorSelector = _assertOrderInvalid(makerAsk);

        vm.expectRevert(errorSelector);
        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerBid(
            takerBid,
            makerAsk,
            signature,
            _emptyMerkleRoot,
            _emptyMerkleProof,
            _emptyAffiliate
        );
    }

    function testTakerBidAmountNotOne() public {
        (makerAsk, takerBid) = _createMakerAskAndTakerBid({premium: premium});

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0;
        takerBid.amounts = amounts;

        signature = _signMakerAsk(makerAsk, makerUserPK);

        _setPriceFeed();

        // Valid, taker struct validation only happens during execution
        bytes4 errorSelector = _assertOrderValid(makerAsk);

        vm.expectRevert(IExecutionStrategy.OrderInvalid.selector);
        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerBid(
            takerBid,
            makerAsk,
            signature,
            _emptyMerkleRoot,
            _emptyMerkleProof,
            _emptyAffiliate
        );
    }

    function testMakerAskTakerBidItemIdsMismatch() public {
        (makerAsk, takerBid) = _createMakerAskAndTakerBid({premium: premium});

        uint256[] memory itemIds = new uint256[](1);
        itemIds[0] = 2;
        takerBid.itemIds = itemIds;

        signature = _signMakerAsk(makerAsk, makerUserPK);

        _setPriceFeed();

        // Valid, taker struct validation only happens during execution
        bytes4 errorSelector = _assertOrderValid(makerAsk);

        vm.expectRevert(IExecutionStrategy.OrderInvalid.selector);
        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerBid(
            takerBid,
            makerAsk,
            signature,
            _emptyMerkleRoot,
            _emptyMerkleProof,
            _emptyAffiliate
        );
    }

    function testBidTooLow() public {
        (makerAsk, takerBid) = _createMakerAskAndTakerBid({premium: premium});

        takerBid.maxPrice = makerAsk.minPrice - premium;

        signature = _signMakerAsk(makerAsk, makerUserPK);

        _setPriceFeed();

        // Valid, taker struct validation only happens during execution
        bytes4 errorSelector = _assertOrderValid(makerAsk);

        vm.expectRevert(IExecutionStrategy.BidTooLow.selector);
        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerBid(
            takerBid,
            makerAsk,
            signature,
            _emptyMerkleRoot,
            _emptyMerkleProof,
            _emptyAffiliate
        );
    }

    function testCallerNotLooksRareProtocol() public {
        (makerAsk, takerBid) = _createMakerAskAndTakerBid({premium: premium});

        signature = _signMakerAsk(makerAsk, makerUserPK);

        _setPriceFeed();

        // Valid, but wrong caller
        bytes4 errorSelector = _assertOrderValid(makerAsk);

        vm.prank(takerUser);
        vm.expectRevert(IExecutionStrategy.WrongCaller.selector);
        // Call the function directly
        address(strategyFloor).call(abi.encodeWithSelector(selectorTakerBid, takerBid, makerAsk));
    }

    function _assertOrderValid(OrderStructs.MakerAsk memory makerAsk) private returns (bytes4) {
        (bool isValid, bytes4 errorSelector) = strategyFloor.isMakerAskValid(makerAsk);
        assertTrue(isValid);
        assertEq(errorSelector, bytes4(0));

        return errorSelector;
    }

    function _assertOrderInvalid(OrderStructs.MakerAsk memory makerAsk) private returns (bytes4) {
        (bool isValid, bytes4 errorSelector) = strategyFloor.isMakerAskValid(makerAsk);
        assertFalse(isValid);
        assertEq(errorSelector, IExecutionStrategy.OrderInvalid.selector);

        return errorSelector;
    }
}
