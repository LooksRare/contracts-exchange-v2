// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IOwnableTwoSteps} from "@looksrare/contracts-libs/contracts/interfaces/IOwnableTwoSteps.sol";
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";
import {IExecutionStrategy} from "../../contracts/interfaces/IExecutionStrategy.sol";
import {IStrategyManager} from "../../contracts/interfaces/IStrategyManager.sol";
import {StrategyFloorBasedCollectionOffer} from "../../contracts/executionStrategies/StrategyFloorBasedCollectionOffer.sol";
import {ProtocolBase} from "./ProtocolBase.t.sol";
import {ChainlinkMaximumLatencyTest} from "./ChainlinkMaximumLatency.t.sol";

contract FloorBasedCollectionOrdersTest is ProtocolBase, IStrategyManager, ChainlinkMaximumLatencyTest {
    string private constant GOERLI_RPC_URL = "https://goerli.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161";
    StrategyFloorBasedCollectionOffer public strategy;
    // At block 15740567
    // roundId         uint80  : 18446744073709552305
    // answer          int256  : 9700000000000000000
    // startedAt       uint256 : 1666100016
    // updatedAt       uint256 : 1666100016
    // answeredInRound uint80  : 18446744073709552305
    uint256 private constant FORKED_BLOCK_NUMBER = 7791270;
    uint256 private constant LATEST_CHAINLINK_ANSWER_IN_WAD = 9700000000000000000;
    address private constant AZUKI_PRICE_FEED = 0x9F6d70CDf08d893f0063742b51d3E9D1e18b7f74;

    function setUp() public override {
        vm.createSelectFork(GOERLI_RPC_URL, FORKED_BLOCK_NUMBER);
        super.setUp();

        _setUpUsers();
        _setUpNewStrategy();
        _setUpRoyalties(address(mockERC721), _standardRoyaltyFee);
    }

    function _setUpNewStrategy() private asPrankedUser(_owner) {
        strategy = new StrategyFloorBasedCollectionOffer(address(looksRareProtocol));
        looksRareProtocol.addStrategy(true, _standardProtocolFee, 300, address(strategy));
    }

    function _createMakerBidAndTakerAsk(uint256 discount)
        private
        returns (OrderStructs.MakerBid memory makerBid, OrderStructs.TakerAsk memory takerAsk)
    {
        mockERC721.mint(takerUser, 1);

        uint16 minNetRatio = 10000 - (_standardRoyaltyFee + _standardProtocolFee); // 3% slippage protection

        // Prepare the order hash
        makerBid = _createSingleItemMakerBidOrder({
            bidNonce: 0,
            subsetNonce: 0,
            strategyId: 2,
            assetType: 0,
            orderNonce: 0,
            minNetRatio: minNetRatio,
            collection: address(mockERC721),
            currency: address(weth),
            signer: makerUser,
            maxPrice: 9.5 ether,
            itemId: 0 // Doesn't matter, not used
        });

        // makerBid.itemIds = itemIds;
        // makerBid.amounts = amounts;
        makerBid.additionalParameters = abi.encode(discount);

        uint256[] memory itemIds = new uint256[](1);
        itemIds[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        takerAsk = OrderStructs.TakerAsk({
            recipient: takerUser,
            minNetRatio: makerAsk.minNetRatio,
            minPrice: 9.5 ether,
            itemIds: itemIds,
            amounts: amounts,
            additionalParameters: abi.encode()
        });
    }

    function testNewStrategy() public {
        Strategy memory newStrategy = looksRareProtocol.strategyInfo(2);
        assertTrue(newStrategy.isActive);
        assertTrue(newStrategy.hasRoyalties);
        assertEq(newStrategy.protocolFee, _standardProtocolFee);
        assertEq(newStrategy.maxProtocolFee, uint16(300));
        assertEq(newStrategy.implementation, address(strategy));
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
        strategy.setPriceFeed(address(mockERC721), AZUKI_PRICE_FEED);
        assertEq(strategy.priceFeeds(address(mockERC721)), AZUKI_PRICE_FEED);
    }

    function testSetPriceFeedNotOwner() public {
        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        strategy.setPriceFeed(address(mockERC721), AZUKI_PRICE_FEED);
    }

    function testFloorBasedCollectionOfferDesiredDiscountedPriceGreaterThanOrEqualToMaxPrice() public {
        strategy = StrategyFloorBasedCollectionOffer(looksRareProtocol.strategyInfo(2).implementation);

        // Floor price = 9.7 ETH, discount = 0.3 ETH, desired price = 9.6 ETH
        // Max price = 9.5 ETH
        (OrderStructs.MakerBid memory makerBid, OrderStructs.TakerAsk memory takerAsk) = _createMakerBidAndTakerAsk({
            discount: 0.1 ether
        });

        signature = _signMakerBid(makerBid, makerUserPK);

        vm.startPrank(_owner);
        strategy.setMaximumLatency(3600);
        strategy.setPriceFeed(address(mockERC721), AZUKI_PRICE_FEED);
        vm.stopPrank();

        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerAsk(
            takerAsk,
            makerBid,
            signature,
            _emptyMerkleRoot,
            _emptyMerkleProof,
            _emptyReferrer
        );

        // Maker user has received the asset
        assertEq(mockERC721.ownerOf(1), makerUser);

        // Maker bid user pays the whole price
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser - 9.5 ether);
        // Taker ask user receives 97% of the whole price (2% protocol + 1% royalties)
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser + 9.215 ether);
    }

    function testFloorBasedCollectionOfferDesiredDiscountedPriceLessThanMaxPrice() public {
        strategy = StrategyFloorBasedCollectionOffer(looksRareProtocol.strategyInfo(2).implementation);

        // Floor price = 9.7 ETH, discount = 0.3 ETH, desired price = 9.4 ETH
        // Max price = 9.5 ETH
        (OrderStructs.MakerBid memory makerBid, OrderStructs.TakerAsk memory takerAsk) = _createMakerBidAndTakerAsk({
            discount: 0.3 ether
        });

        takerAsk.minPrice = 9.4 ether;

        signature = _signMakerBid(makerBid, makerUserPK);

        vm.startPrank(_owner);
        strategy.setMaximumLatency(3600);
        strategy.setPriceFeed(address(mockERC721), AZUKI_PRICE_FEED);
        vm.stopPrank();

        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerAsk(
            takerAsk,
            makerBid,
            signature,
            _emptyMerkleRoot,
            _emptyMerkleProof,
            _emptyReferrer
        );

        // Maker user has received the asset
        assertEq(mockERC721.ownerOf(1), makerUser);

        // Maker bid user pays the whole price
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser - 9.4 ether);
        // Taker ask user receives 97% of the whole price (2% protocol + 1% royalties)
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser + 9.118 ether);
    }

    function testPriceFeedNotAvailable() public {
        strategy = StrategyFloorBasedCollectionOffer(looksRareProtocol.strategyInfo(2).implementation);

        (OrderStructs.MakerBid memory makerBid, OrderStructs.TakerAsk memory takerAsk) = _createMakerBidAndTakerAsk({
            discount: 0.1 ether
        });

        signature = _signMakerBid(makerBid, makerUserPK);

        vm.startPrank(_owner);
        strategy.setMaximumLatency(3600);
        vm.stopPrank();

        vm.expectRevert(StrategyFloorBasedCollectionOffer.PriceFeedNotAvailable.selector);
        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerAsk(
            takerAsk,
            makerBid,
            signature,
            _emptyMerkleRoot,
            _emptyMerkleProof,
            _emptyReferrer
        );
    }

    function testOraclePriceNotRecentEnough() public {
        strategy = StrategyFloorBasedCollectionOffer(looksRareProtocol.strategyInfo(2).implementation);

        (OrderStructs.MakerBid memory makerBid, OrderStructs.TakerAsk memory takerAsk) = _createMakerBidAndTakerAsk({
            discount: 0.1 ether
        });

        signature = _signMakerBid(makerBid, makerUserPK);

        vm.startPrank(_owner);
        strategy.setPriceFeed(address(mockERC721), AZUKI_PRICE_FEED);
        vm.stopPrank();

        vm.expectRevert(StrategyFloorBasedCollectionOffer.PriceNotRecentEnough.selector);
        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerAsk(
            takerAsk,
            makerBid,
            signature,
            _emptyMerkleRoot,
            _emptyMerkleProof,
            _emptyReferrer
        );
    }

    function testCallerNotLooksRareProtocol() public {
        strategy = StrategyFloorBasedCollectionOffer(looksRareProtocol.strategyInfo(2).implementation);

        (OrderStructs.MakerBid memory makerBid, OrderStructs.TakerAsk memory takerAsk) = _createMakerBidAndTakerAsk({
            discount: 0.1 ether
        });

        vm.startPrank(_owner);
        strategy.setMaximumLatency(3600);
        strategy.setPriceFeed(address(mockERC721), AZUKI_PRICE_FEED);
        vm.stopPrank();

        vm.prank(takerUser);
        vm.expectRevert(IExecutionStrategy.WrongCaller.selector);
        // Call the function directly
        strategy.executeStrategyWithTakerAsk(takerAsk, makerBid);
    }

    function testTakerAskItemIdsLengthNotOne() public {
        strategy = StrategyFloorBasedCollectionOffer(looksRareProtocol.strategyInfo(2).implementation);

        (OrderStructs.MakerBid memory makerBid, OrderStructs.TakerAsk memory takerAsk) = _createMakerBidAndTakerAsk({
            discount: 0.1 ether
        });

        uint256[] memory itemIds = new uint256[](0);
        takerAsk.itemIds = itemIds;

        signature = _signMakerBid(makerBid, makerUserPK);

        vm.startPrank(_owner);
        strategy.setMaximumLatency(3600);
        strategy.setPriceFeed(address(mockERC721), AZUKI_PRICE_FEED);
        vm.stopPrank();

        vm.prank(takerUser);
        vm.expectRevert(IExecutionStrategy.OrderInvalid.selector);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerAsk(
            takerAsk,
            makerBid,
            signature,
            _emptyMerkleRoot,
            _emptyMerkleProof,
            _emptyReferrer
        );
    }

    function testTakerAskAmountsLengthNotOne() public {
        strategy = StrategyFloorBasedCollectionOffer(looksRareProtocol.strategyInfo(2).implementation);

        (OrderStructs.MakerBid memory makerBid, OrderStructs.TakerAsk memory takerAsk) = _createMakerBidAndTakerAsk({
            discount: 0.1 ether
        });

        uint256[] memory amounts = new uint256[](0);
        takerAsk.amounts = amounts;

        signature = _signMakerBid(makerBid, makerUserPK);

        vm.startPrank(_owner);
        strategy.setMaximumLatency(3600);
        strategy.setPriceFeed(address(mockERC721), AZUKI_PRICE_FEED);
        vm.stopPrank();

        vm.prank(takerUser);
        vm.expectRevert(IExecutionStrategy.OrderInvalid.selector);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerAsk(
            takerAsk,
            makerBid,
            signature,
            _emptyMerkleRoot,
            _emptyMerkleProof,
            _emptyReferrer
        );
    }

    function testTakerAskZeroAmount() public {
        strategy = StrategyFloorBasedCollectionOffer(looksRareProtocol.strategyInfo(2).implementation);

        (OrderStructs.MakerBid memory makerBid, OrderStructs.TakerAsk memory takerAsk) = _createMakerBidAndTakerAsk({
            discount: 0.1 ether
        });

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0;
        takerAsk.amounts = amounts;

        signature = _signMakerBid(makerBid, makerUserPK);

        vm.startPrank(_owner);
        strategy.setMaximumLatency(3600);
        strategy.setPriceFeed(address(mockERC721), AZUKI_PRICE_FEED);
        vm.stopPrank();

        vm.prank(takerUser);
        vm.expectRevert(IExecutionStrategy.OrderInvalid.selector);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerAsk(
            takerAsk,
            makerBid,
            signature,
            _emptyMerkleRoot,
            _emptyMerkleProof,
            _emptyReferrer
        );
    }

    function testMakerBidTooLow() public {
        strategy = StrategyFloorBasedCollectionOffer(looksRareProtocol.strategyInfo(2).implementation);

        // Floor price = 9.7 ETH, discount = 0.3 ETH, desired price = 9.4 ETH
        // Maker bid max price = 9.4 ETH
        // Taker ask min price = 9.5 ETH
        (OrderStructs.MakerBid memory makerBid, OrderStructs.TakerAsk memory takerAsk) = _createMakerBidAndTakerAsk({
            discount: 0.3 ether
        });
        makerBid.maxPrice = 9.4 ether;

        signature = _signMakerBid(makerBid, makerUserPK);

        vm.startPrank(_owner);
        strategy.setMaximumLatency(3600);
        strategy.setPriceFeed(address(mockERC721), AZUKI_PRICE_FEED);
        vm.stopPrank();

        vm.expectRevert(IExecutionStrategy.BidTooLow.selector);
        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerAsk(
            takerAsk,
            makerBid,
            signature,
            _emptyMerkleRoot,
            _emptyMerkleProof,
            _emptyReferrer
        );
    }
}
