// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IOwnableTwoSteps} from "@looksrare/contracts-libs/contracts/interfaces/IOwnableTwoSteps.sol";
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";
import {IExecutionStrategy} from "../../contracts/interfaces/IExecutionStrategy.sol";
import {IStrategyManager} from "../../contracts/interfaces/IStrategyManager.sol";
import {StrategyChainlinkPriceLatency} from "../../contracts/executionStrategies/StrategyChainlinkPriceLatency.sol";
import {StrategyChainlinkMultiplePriceFeeds} from "../../contracts/executionStrategies/StrategyChainlinkMultiplePriceFeeds.sol";
import {StrategyFloorPremium} from "../../contracts/executionStrategies/StrategyFloorPremium.sol";
import {ProtocolBase} from "./ProtocolBase.t.sol";
import {ChainlinkMaximumLatencyTest} from "./ChainlinkMaximumLatency.t.sol";
import {MockChainlinkAggregator} from "../mock/MockChainlinkAggregator.sol";

contract FloorPremiumOrdersTest is ProtocolBase, IStrategyManager, ChainlinkMaximumLatencyTest {
    string private constant GOERLI_RPC_URL = "https://goerli.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161";
    StrategyFloorPremium public strategyFloorPremium;
    bytes4 public selectorTakerAsk = _emptyBytes4;
    bytes4 public selectorTakerBid = StrategyFloorPremium.executeStrategyWithTakerBid.selector;

    // At block 15740567
    // roundId         uint80  : 18446744073709552305
    // answer          int256  : 9700000000000000000
    // startedAt       uint256 : 1666100016
    // updatedAt       uint256 : 1666100016
    // answeredInRound uint80  : 18446744073709552305
    uint256 private constant FORKED_BLOCK_NUMBER = 7791270;
    uint256 private constant LATEST_CHAINLINK_ANSWER_IN_WAD = 9.7 ether;
    address private constant AZUKI_PRICE_FEED = 0x9F6d70CDf08d893f0063742b51d3E9D1e18b7f74;

    function setUp() public override {
        vm.createSelectFork(GOERLI_RPC_URL, FORKED_BLOCK_NUMBER);
        super.setUp();
        _setUpUsers();
        _setUpNewStrategy();
    }

    function _setUpNewStrategy() private asPrankedUser(_owner) {
        strategyFloorPremium = new StrategyFloorPremium(address(looksRareProtocol));
        looksRareProtocol.addStrategy(
            _standardProtocolFee,
            _minTotalFee,
            _maxProtocolFee,
            selectorTakerAsk,
            selectorTakerBid,
            address(strategyFloorPremium)
        );
    }

    function _createMakerAskAndTakerBid(uint256 premium)
        private
        returns (OrderStructs.MakerAsk memory newMakerAsk, OrderStructs.TakerBid memory newTakerBid)
    {
        mockERC721.mint(makerUser, 1);

        // Prepare the order hash
        newMakerAsk = _createSingleItemMakerAskOrder({
            askNonce: 0,
            subsetNonce: 0,
            strategyId: 2,
            assetType: 0,
            orderNonce: 0,
            collection: address(mockERC721),
            currency: address(weth),
            signer: makerUser,
            minPrice: LATEST_CHAINLINK_ANSWER_IN_WAD,
            itemId: 1
        });

        newMakerAsk.additionalParameters = abi.encode(premium);

        uint256[] memory itemIds = new uint256[](1);
        itemIds[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        newTakerBid = OrderStructs.TakerBid(
            takerUser,
            LATEST_CHAINLINK_ANSWER_IN_WAD + premium,
            itemIds,
            amounts,
            abi.encode()
        );
    }

    function testNewStrategy() public {
        Strategy memory newStrategy = looksRareProtocol.strategyInfo(2);
        assertTrue(newStrategy.isActive);
        assertEq(newStrategy.standardProtocolFee, _standardProtocolFee);
        assertEq(newStrategy.maxProtocolFee, uint16(300));
        assertEq(newStrategy.implementation, address(strategyFloorPremium));
    }

    function testSetMaximumLatency() public {
        _testSetMaximumLatency(looksRareProtocol.strategyInfo(2).implementation);
    }

    function testSetMaximumLatencyLatencyToleranceTooHigh() public {
        _testSetMaximumLatencyLatencyToleranceTooHigh(looksRareProtocol.strategyInfo(2).implementation);
    }

    function testSetMaximumLatencyNotOwner() public {
        _testSetMaximumLatencyNotOwner(looksRareProtocol.strategyInfo(2).implementation);
    }

    event PriceFeedUpdated(address indexed collection, address indexed priceFeed);

    function testSetPriceFeed() public asPrankedUser(_owner) {
        vm.expectEmit(true, true, true, false);
        emit PriceFeedUpdated(address(mockERC721), AZUKI_PRICE_FEED);
        strategyFloorPremium.setPriceFeed(address(mockERC721), AZUKI_PRICE_FEED);
        assertEq(strategyFloorPremium.priceFeeds(address(mockERC721)), AZUKI_PRICE_FEED);
    }

    function testSetPriceFeedNotOwner() public {
        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        strategyFloorPremium.setPriceFeed(address(mockERC721), AZUKI_PRICE_FEED);
    }

    function testFloorOPremiumDesiredSalePriceGreaterThanOrEqualToMinPrice() public {
        strategyFloorPremium = StrategyFloorPremium(looksRareProtocol.strategyInfo(2).implementation);

        // Floor price = 9.7 ETH, premium = 0.1 ETH, desired price = 9.8 ETH
        // Min price = 9.7 ETH
        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _createMakerAskAndTakerBid({
            premium: 0.1 ether
        });

        signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.startPrank(_owner);
        strategyFloorPremium.setMaximumLatency(3600);
        strategyFloorPremium.setPriceFeed(address(mockERC721), AZUKI_PRICE_FEED);
        vm.stopPrank();

        (bool isValid, bytes4 errorSelector) = strategyFloorPremium.isValid(takerBid, makerAsk);
        assertTrue(isValid);
        assertEq(errorSelector, bytes4(0));

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

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(1), takerUser);
        // Taker bid user pays the whole price
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser - 9.8 ether);
        // Maker ask user receives 98% of the whole price (2% protocol)
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser + 9.604 ether);
    }

    function testFloorOPremiumDesiredSalePriceLessThanMinPrice() public {
        strategyFloorPremium = StrategyFloorPremium(looksRareProtocol.strategyInfo(2).implementation);

        // Floor price = 9.7 ETH, premium = 0.1 ETH, desired price = 9.8 ETH
        // Min price = 9.9 ETH
        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _createMakerAskAndTakerBid({
            premium: 0.1 ether
        });

        makerAsk.minPrice = 9.9 ether;
        takerBid.maxPrice = makerAsk.minPrice;

        signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.startPrank(_owner);
        strategyFloorPremium.setMaximumLatency(3600);
        strategyFloorPremium.setPriceFeed(address(mockERC721), AZUKI_PRICE_FEED);
        vm.stopPrank();

        (bool isValid, bytes4 errorSelector) = strategyFloorPremium.isValid(takerBid, makerAsk);
        assertTrue(isValid);
        assertEq(errorSelector, bytes4(0));

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

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(1), takerUser);

        // Taker bid user pays the whole price
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser - 9.9 ether);
        // Maker ask user receives 98% of the whole price (2% protocol)
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser + 9.702 ether);
    }

    function testPriceFeedNotAvailable() public {
        strategyFloorPremium = StrategyFloorPremium(looksRareProtocol.strategyInfo(2).implementation);

        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _createMakerAskAndTakerBid({
            premium: 0.1 ether
        });

        signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.startPrank(_owner);
        strategyFloorPremium.setMaximumLatency(3600);
        vm.stopPrank();

        (bool isValid, bytes4 errorSelector) = strategyFloorPremium.isValid(takerBid, makerAsk);
        assertTrue(!isValid);
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
        strategyFloorPremium = StrategyFloorPremium(looksRareProtocol.strategyInfo(2).implementation);

        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _createMakerAskAndTakerBid({
            premium: 0.1 ether
        });

        signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.startPrank(_owner);
        strategyFloorPremium.setPriceFeed(address(mockERC721), AZUKI_PRICE_FEED);
        vm.stopPrank();

        (bool isValid, bytes4 errorSelector) = strategyFloorPremium.isValid(takerBid, makerAsk);
        assertTrue(!isValid);
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
        strategyFloorPremium = StrategyFloorPremium(looksRareProtocol.strategyInfo(2).implementation);

        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _createMakerAskAndTakerBid({
            premium: 0.1 ether
        });

        signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.startPrank(_owner);
        strategyFloorPremium.setMaximumLatency(3600);
        strategyFloorPremium.setPriceFeed(address(mockERC721), address(aggregator));
        vm.stopPrank();

        (bool isValid, bytes4 errorSelector) = strategyFloorPremium.isValid(takerBid, makerAsk);
        assertTrue(!isValid);
        assertEq(errorSelector, StrategyFloorPremium.InvalidChainlinkPrice.selector);

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
        vm.expectRevert(StrategyFloorPremium.InvalidChainlinkPrice.selector);
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
        strategyFloorPremium = StrategyFloorPremium(looksRareProtocol.strategyInfo(2).implementation);

        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _createMakerAskAndTakerBid({
            premium: 0.1 ether
        });

        signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.startPrank(_owner);
        strategyFloorPremium.setPriceFeed(address(mockERC721), AZUKI_PRICE_FEED);
        strategyFloorPremium.setMaximumLatency(3600);
        vm.stopPrank();

        // Valid, but wrong caller
        (bool isValid, bytes4 errorSelector) = strategyFloorPremium.isValid(takerBid, makerAsk);
        assertTrue(isValid);
        assertEq(errorSelector, bytes4(0));

        vm.prank(takerUser);
        vm.expectRevert(IExecutionStrategy.WrongCaller.selector);
        // Call the function directly
        strategyFloorPremium.executeStrategyWithTakerBid(takerBid, makerAsk);
    }

    function testMakerAskItemIdsLengthNotOne() public {
        strategyFloorPremium = StrategyFloorPremium(looksRareProtocol.strategyInfo(2).implementation);

        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _createMakerAskAndTakerBid({
            premium: 0.1 ether
        });

        uint256[] memory itemIds = new uint256[](0);
        makerAsk.itemIds = itemIds;

        signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.startPrank(_owner);
        strategyFloorPremium.setMaximumLatency(3600);
        strategyFloorPremium.setPriceFeed(address(mockERC721), AZUKI_PRICE_FEED);
        vm.stopPrank();

        (bool isValid, bytes4 errorSelector) = strategyFloorPremium.isValid(takerBid, makerAsk);
        assertTrue(!isValid);
        assertEq(errorSelector, IExecutionStrategy.OrderInvalid.selector);

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
        strategyFloorPremium = StrategyFloorPremium(looksRareProtocol.strategyInfo(2).implementation);

        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _createMakerAskAndTakerBid({
            premium: 0.1 ether
        });

        uint256[] memory amounts = new uint256[](0);
        makerAsk.amounts = amounts;

        signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.startPrank(_owner);
        strategyFloorPremium.setMaximumLatency(3600);
        strategyFloorPremium.setPriceFeed(address(mockERC721), AZUKI_PRICE_FEED);
        vm.stopPrank();

        (bool isValid, bytes4 errorSelector) = strategyFloorPremium.isValid(takerBid, makerAsk);
        assertTrue(!isValid);
        assertEq(errorSelector, IExecutionStrategy.OrderInvalid.selector);

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
        strategyFloorPremium = StrategyFloorPremium(looksRareProtocol.strategyInfo(2).implementation);

        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _createMakerAskAndTakerBid({
            premium: 0.1 ether
        });

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0;
        makerAsk.amounts = amounts;

        signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.startPrank(_owner);
        strategyFloorPremium.setMaximumLatency(3600);
        strategyFloorPremium.setPriceFeed(address(mockERC721), AZUKI_PRICE_FEED);
        vm.stopPrank();

        (bool isValid, bytes4 errorSelector) = strategyFloorPremium.isValid(takerBid, makerAsk);
        assertTrue(!isValid);
        assertEq(errorSelector, IExecutionStrategy.OrderInvalid.selector);

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
        strategyFloorPremium = StrategyFloorPremium(looksRareProtocol.strategyInfo(2).implementation);

        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _createMakerAskAndTakerBid({
            premium: 0.1 ether
        });

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0;
        takerBid.amounts = amounts;

        signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.startPrank(_owner);
        strategyFloorPremium.setMaximumLatency(3600);
        strategyFloorPremium.setPriceFeed(address(mockERC721), AZUKI_PRICE_FEED);
        vm.stopPrank();

        (bool isValid, bytes4 errorSelector) = strategyFloorPremium.isValid(takerBid, makerAsk);
        assertTrue(!isValid);
        assertEq(errorSelector, IExecutionStrategy.OrderInvalid.selector);

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

    function testMakerAskTakerBidItemIdsMismatch() public {
        strategyFloorPremium = StrategyFloorPremium(looksRareProtocol.strategyInfo(2).implementation);

        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _createMakerAskAndTakerBid({
            premium: 0.1 ether
        });

        uint256[] memory itemIds = new uint256[](1);
        itemIds[0] = 2;
        takerBid.itemIds = itemIds;

        signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.startPrank(_owner);
        strategyFloorPremium.setMaximumLatency(3600);
        strategyFloorPremium.setPriceFeed(address(mockERC721), AZUKI_PRICE_FEED);
        vm.stopPrank();

        (bool isValid, bytes4 errorSelector) = strategyFloorPremium.isValid(takerBid, makerAsk);
        assertTrue(!isValid);
        assertEq(errorSelector, IExecutionStrategy.OrderInvalid.selector);

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

    function testBidTooLow() public {
        strategyFloorPremium = StrategyFloorPremium(looksRareProtocol.strategyInfo(2).implementation);

        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _createMakerAskAndTakerBid({
            premium: 0.1 ether
        });

        takerBid.maxPrice = makerAsk.minPrice - 0.1 ether;

        signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.startPrank(_owner);
        strategyFloorPremium.setMaximumLatency(3600);
        strategyFloorPremium.setPriceFeed(address(mockERC721), AZUKI_PRICE_FEED);
        vm.stopPrank();

        (bool isValid, bytes4 errorSelector) = strategyFloorPremium.isValid(takerBid, makerAsk);
        assertTrue(!isValid);
        assertEq(errorSelector, IExecutionStrategy.BidTooLow.selector);

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
}
