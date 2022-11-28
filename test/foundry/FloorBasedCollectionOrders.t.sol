// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IOwnableTwoSteps} from "@looksrare/contracts-libs/contracts/interfaces/IOwnableTwoSteps.sol";
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";
import {IExecutionStrategy} from "../../contracts/interfaces/IExecutionStrategy.sol";
import {IStrategyManager} from "../../contracts/interfaces/IStrategyManager.sol";
import {StrategyChainlinkPriceLatency} from "../../contracts/executionStrategies/StrategyChainlinkPriceLatency.sol";
import {StrategyChainlinkMultiplePriceFeeds} from "../../contracts/executionStrategies/StrategyChainlinkMultiplePriceFeeds.sol";
import {StrategyFloorBasedCollectionOffer} from "../../contracts/executionStrategies/StrategyFloorBasedCollectionOffer.sol";
import {ProtocolBase} from "./ProtocolBase.t.sol";
import {ChainlinkMaximumLatencyTest} from "./ChainlinkMaximumLatency.t.sol";
import {MockChainlinkAggregator} from "../mock/MockChainlinkAggregator.sol";

contract FloorBasedCollectionOrdersTest is ProtocolBase, IStrategyManager, ChainlinkMaximumLatencyTest {
    StrategyFloorBasedCollectionOffer public strategyFloorBasedCollectionOffer;
    bytes4 public selectorTakerAsk = StrategyFloorBasedCollectionOffer.executeStrategyWithTakerAsk.selector;
    bytes4 public selectorTakerBid = _emptyBytes4;

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
        vm.createSelectFork(vm.rpcUrl("goerli"), FORKED_BLOCK_NUMBER);
        super.setUp();
        _setUpUsers();
        _setUpNewStrategy();
    }

    function _setUpNewStrategy() private asPrankedUser(_owner) {
        strategyFloorBasedCollectionOffer = new StrategyFloorBasedCollectionOffer(address(looksRareProtocol));
        looksRareProtocol.addStrategy(
            _standardProtocolFee,
            _minTotalFee,
            _maxProtocolFee,
            selectorTakerAsk,
            selectorTakerBid,
            address(strategyFloorBasedCollectionOffer)
        );
    }

    function _createMakerBidAndTakerAsk(
        uint256 discount
    ) private returns (OrderStructs.MakerBid memory newMakerBid, OrderStructs.TakerAsk memory newTakerAsk) {
        mockERC721.mint(takerUser, 1);

        // Prepare the order hash
        newMakerBid = _createSingleItemMakerBidOrder({
            bidNonce: 0,
            subsetNonce: 0,
            strategyId: 2,
            assetType: 0,
            orderNonce: 0,
            collection: address(mockERC721),
            currency: address(weth),
            signer: makerUser,
            maxPrice: 9.5 ether,
            itemId: 0 // Doesn't matter, not used
        });

        newMakerBid.additionalParameters = abi.encode(discount);

        uint256[] memory itemIds = new uint256[](1);
        itemIds[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        newTakerAsk = OrderStructs.TakerAsk({
            recipient: takerUser,
            minPrice: 9.5 ether,
            itemIds: itemIds,
            amounts: amounts,
            additionalParameters: abi.encode()
        });
    }

    function testNewStrategyAndMaximumLatency() public {
        (
            bool strategyIsActive,
            uint16 strategyStandardProtocolFee,
            uint16 strategyMinTotalFee,
            uint16 strategyMaxProtocolFee,
            bytes4 strategySelectorTakerAsk,
            bytes4 strategySelectorTakerBid,
            address strategyImplementation
        ) = looksRareProtocol.strategyInfo(2);

        assertTrue(strategyIsActive);
        assertEq(strategyStandardProtocolFee, _standardProtocolFee);
        assertEq(strategyMinTotalFee, _minTotalFee);
        assertEq(strategyMaxProtocolFee, _maxProtocolFee);
        assertEq(strategySelectorTakerAsk, selectorTakerAsk);
        assertEq(strategySelectorTakerBid, selectorTakerBid);
        assertEq(strategyImplementation, address(strategyFloorBasedCollectionOffer));
    }

    function testSetMaximumLatency() public {
        _testSetMaximumLatency(address(strategyFloorBasedCollectionOffer));
    }

    function testSetMaximumLatencyLatencyToleranceTooHigh() public {
        _testSetMaximumLatencyLatencyToleranceTooHigh(address(strategyFloorBasedCollectionOffer));
    }

    function testSetMaximumLatencyNotOwner() public {
        _testSetMaximumLatencyNotOwner(address(strategyFloorBasedCollectionOffer));
    }

    event PriceFeedUpdated(address indexed collection, address indexed priceFeed);

    function testSetPriceFeed() public asPrankedUser(_owner) {
        vm.expectEmit(true, true, true, false);
        emit PriceFeedUpdated(address(mockERC721), AZUKI_PRICE_FEED);
        strategyFloorBasedCollectionOffer.setPriceFeed(address(mockERC721), AZUKI_PRICE_FEED);
        assertEq(strategyFloorBasedCollectionOffer.priceFeeds(address(mockERC721)), AZUKI_PRICE_FEED);
    }

    function testSetPriceFeedNotOwner() public {
        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        strategyFloorBasedCollectionOffer.setPriceFeed(address(mockERC721), AZUKI_PRICE_FEED);
    }

    function testFloorBasedCollectionOfferDesiredDiscountedPriceGreaterThanOrEqualToMaxPrice() public {
        // Floor price = 9.7 ETH, discount = 0.1 ETH, desired price = 9.6 ETH
        // Max price = 9.5 ETH
        (makerBid, takerAsk) = _createMakerBidAndTakerAsk({discount: 0.1 ether});

        signature = _signMakerBid(makerBid, makerUserPK);

        vm.startPrank(_owner);
        strategyFloorBasedCollectionOffer.setMaximumLatency(3600);
        strategyFloorBasedCollectionOffer.setPriceFeed(address(mockERC721), AZUKI_PRICE_FEED);
        vm.stopPrank();

        (bool isValid, bytes4 error) = strategyFloorBasedCollectionOffer.isValid(takerAsk, makerBid);
        assertTrue(isValid);
        assertEq(error, bytes4(0));

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

        // Maker user has received the asset
        assertEq(mockERC721.ownerOf(1), makerUser);

        // Maker bid user pays the whole price
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser - 9.5 ether);
        // Taker ask user receives 98% of the whole price (2% protocol)
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser + 9.31 ether);
    }

    function testFloorBasedCollectionOfferDesiredDiscountedPriceLessThanMaxPrice() public {
        // Floor price = 9.7 ETH, discount = 0.3 ETH, desired price = 9.4 ETH
        // Max price = 9.5 ETH
        (makerBid, takerAsk) = _createMakerBidAndTakerAsk({discount: 0.3 ether});

        takerAsk.minPrice = 9.4 ether;

        signature = _signMakerBid(makerBid, makerUserPK);

        vm.startPrank(_owner);
        strategyFloorBasedCollectionOffer.setMaximumLatency(3600);
        strategyFloorBasedCollectionOffer.setPriceFeed(address(mockERC721), AZUKI_PRICE_FEED);
        vm.stopPrank();

        (bool isValid, bytes4 error) = strategyFloorBasedCollectionOffer.isValid(takerAsk, makerBid);
        assertTrue(isValid);
        assertEq(error, bytes4(0));

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

        // Maker user has received the asset
        assertEq(mockERC721.ownerOf(1), makerUser);

        // Maker bid user pays the whole price
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser - 9.4 ether);
        // Taker ask user receives 97% of the whole price (2% protocol)
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser + 9.212 ether);
    }

    function testFloorBasedCollectionOfferDesiredDiscountedAmountGreaterThanOrEqualToFloorPrice() public {
        // Floor price = 9.7 ETH, discount = 9.7 ETH, desired price = 0 ETH
        // Max price = 0 ETH
        (makerBid, takerAsk) = _createMakerBidAndTakerAsk({discount: 9.7 ether});

        signature = _signMakerBid(makerBid, makerUserPK);

        vm.startPrank(_owner);
        strategyFloorBasedCollectionOffer.setMaximumLatency(3600);
        strategyFloorBasedCollectionOffer.setPriceFeed(address(mockERC721), AZUKI_PRICE_FEED);
        vm.stopPrank();

        (bool isValid, bytes4 error) = strategyFloorBasedCollectionOffer.isValid(takerAsk, makerBid);
        assertTrue(!isValid);
        assertEq(error, IExecutionStrategy.OrderInvalid.selector);

        vm.expectRevert(error);
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

        // Floor price = 9.7 ETH, discount = 9.8 ETH, desired price = -0.1 ETH
        // Max price = -0.1 ETH
        makerBid.additionalParameters = abi.encode(9.8 ether);
        signature = _signMakerBid(makerBid, makerUserPK);

        vm.expectRevert(IExecutionStrategy.OrderInvalid.selector);
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

    function testPriceFeedNotAvailable() public {
        (makerBid, takerAsk) = _createMakerBidAndTakerAsk({discount: 0.1 ether});

        signature = _signMakerBid(makerBid, makerUserPK);

        vm.startPrank(_owner);
        strategyFloorBasedCollectionOffer.setMaximumLatency(3600);
        vm.stopPrank();

        (bool isValid, bytes4 error) = strategyFloorBasedCollectionOffer.isValid(takerAsk, makerBid);
        assertTrue(!isValid);
        assertEq(error, StrategyChainlinkMultiplePriceFeeds.PriceFeedNotAvailable.selector);

        vm.expectRevert(error);
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

    function testOraclePriceNotRecentEnough() public {
        (makerBid, takerAsk) = _createMakerBidAndTakerAsk({discount: 0.1 ether});

        signature = _signMakerBid(makerBid, makerUserPK);

        vm.startPrank(_owner);
        strategyFloorBasedCollectionOffer.setPriceFeed(address(mockERC721), AZUKI_PRICE_FEED);
        vm.stopPrank();

        (bool isValid, bytes4 error) = strategyFloorBasedCollectionOffer.isValid(takerAsk, makerBid);
        assertTrue(!isValid);
        assertEq(error, StrategyChainlinkPriceLatency.PriceNotRecentEnough.selector);

        vm.expectRevert(error);
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

    function testChainlinkPriceLessThanOrEqualToZero() public {
        MockChainlinkAggregator aggregator = new MockChainlinkAggregator();

        (makerBid, takerAsk) = _createMakerBidAndTakerAsk({discount: 0.1 ether});

        signature = _signMakerBid(makerBid, makerUserPK);

        vm.startPrank(_owner);
        strategyFloorBasedCollectionOffer.setMaximumLatency(3600);
        strategyFloorBasedCollectionOffer.setPriceFeed(address(mockERC721), address(aggregator));
        vm.stopPrank();

        (bool isValid, bytes4 error) = strategyFloorBasedCollectionOffer.isValid(takerAsk, makerBid);
        assertTrue(!isValid);
        assertEq(error, StrategyFloorBasedCollectionOffer.InvalidChainlinkPrice.selector);

        vm.expectRevert(error);
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
        vm.expectRevert(StrategyFloorBasedCollectionOffer.InvalidChainlinkPrice.selector);
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

    function testCallerNotLooksRareProtocol() public {
        (makerBid, takerAsk) = _createMakerBidAndTakerAsk({discount: 0.1 ether});

        vm.startPrank(_owner);
        strategyFloorBasedCollectionOffer.setMaximumLatency(3600);
        strategyFloorBasedCollectionOffer.setPriceFeed(address(mockERC721), AZUKI_PRICE_FEED);
        vm.stopPrank();

        // Valid, but wrong caller
        (bool isValid, bytes4 error) = strategyFloorBasedCollectionOffer.isValid(takerAsk, makerBid);
        assertTrue(isValid);
        assertEq(error, bytes4(0));

        vm.prank(takerUser);
        vm.expectRevert(IExecutionStrategy.WrongCaller.selector);
        // Call the function directly
        strategyFloorBasedCollectionOffer.executeStrategyWithTakerAsk(takerAsk, makerBid);
    }

    function testTakerAskItemIdsLengthNotOne() public {
        (makerBid, takerAsk) = _createMakerBidAndTakerAsk({discount: 0.1 ether});

        uint256[] memory itemIds = new uint256[](0);
        takerAsk.itemIds = itemIds;

        signature = _signMakerBid(makerBid, makerUserPK);

        vm.startPrank(_owner);
        strategyFloorBasedCollectionOffer.setMaximumLatency(3600);
        strategyFloorBasedCollectionOffer.setPriceFeed(address(mockERC721), AZUKI_PRICE_FEED);
        vm.stopPrank();

        (bool isValid, bytes4 error) = strategyFloorBasedCollectionOffer.isValid(takerAsk, makerBid);
        assertTrue(!isValid);
        assertEq(error, IExecutionStrategy.OrderInvalid.selector);

        vm.prank(takerUser);
        vm.expectRevert(error);
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

    function testTakerAskAmountsLengthNotOne() public {
        (makerBid, takerAsk) = _createMakerBidAndTakerAsk({discount: 0.1 ether});

        uint256[] memory amounts = new uint256[](0);
        takerAsk.amounts = amounts;

        signature = _signMakerBid(makerBid, makerUserPK);

        vm.startPrank(_owner);
        strategyFloorBasedCollectionOffer.setMaximumLatency(3600);
        strategyFloorBasedCollectionOffer.setPriceFeed(address(mockERC721), AZUKI_PRICE_FEED);
        vm.stopPrank();

        (bool isValid, bytes4 error) = strategyFloorBasedCollectionOffer.isValid(takerAsk, makerBid);
        assertTrue(!isValid);
        assertEq(error, IExecutionStrategy.OrderInvalid.selector);

        vm.prank(takerUser);
        vm.expectRevert(error);
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

    function testMakerBidAmountsLengthNotOne() public {
        (makerBid, takerAsk) = _createMakerBidAndTakerAsk({discount: 0.1 ether});

        uint256[] memory amounts = new uint256[](0);
        makerBid.amounts = amounts;

        signature = _signMakerBid(makerBid, makerUserPK);

        vm.startPrank(_owner);
        strategyFloorBasedCollectionOffer.setMaximumLatency(3600);
        strategyFloorBasedCollectionOffer.setPriceFeed(address(mockERC721), AZUKI_PRICE_FEED);
        vm.stopPrank();

        (bool isValid, bytes4 error) = strategyFloorBasedCollectionOffer.isValid(takerAsk, makerBid);
        assertTrue(!isValid);
        assertEq(error, IExecutionStrategy.OrderInvalid.selector);

        vm.prank(takerUser);
        vm.expectRevert(error);
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

    function testTakerAskZeroAmount() public {
        (makerBid, takerAsk) = _createMakerBidAndTakerAsk({discount: 0.1 ether});

        uint256[] memory amounts = new uint256[](1);
        // Seller will probably try 0
        amounts[0] = 0;
        takerAsk.amounts = amounts;

        signature = _signMakerBid(makerBid, makerUserPK);

        vm.startPrank(_owner);
        strategyFloorBasedCollectionOffer.setMaximumLatency(3600);
        strategyFloorBasedCollectionOffer.setPriceFeed(address(mockERC721), AZUKI_PRICE_FEED);
        vm.stopPrank();

        (bool isValid, bytes4 error) = strategyFloorBasedCollectionOffer.isValid(takerAsk, makerBid);
        assertTrue(!isValid);
        assertEq(error, IExecutionStrategy.OrderInvalid.selector);

        vm.prank(takerUser);
        vm.expectRevert(error);
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

    function testMakerBidAmountNotOne() public {
        (makerBid, takerAsk) = _createMakerBidAndTakerAsk({discount: 0.1 ether});

        uint256[] memory amounts = new uint256[](1);
        // Bidder will probably try a higher number
        amounts[0] = 2;
        makerBid.amounts = amounts;

        signature = _signMakerBid(makerBid, makerUserPK);

        vm.startPrank(_owner);
        strategyFloorBasedCollectionOffer.setMaximumLatency(3600);
        strategyFloorBasedCollectionOffer.setPriceFeed(address(mockERC721), AZUKI_PRICE_FEED);
        vm.stopPrank();

        (bool isValid, bytes4 error) = strategyFloorBasedCollectionOffer.isValid(takerAsk, makerBid);
        assertTrue(!isValid);
        assertEq(error, IExecutionStrategy.OrderInvalid.selector);

        vm.prank(takerUser);
        vm.expectRevert(error);
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

    function testMakerBidTooLow() public {
        // Floor price = 9.7 ETH, discount = 0.3 ETH, desired price = 9.4 ETH
        // Maker bid max price = 9.4 ETH
        // Taker ask min price = 9.5 ETH
        (makerBid, takerAsk) = _createMakerBidAndTakerAsk({discount: 0.3 ether});
        makerBid.maxPrice = 9.4 ether;

        signature = _signMakerBid(makerBid, makerUserPK);

        vm.startPrank(_owner);
        strategyFloorBasedCollectionOffer.setMaximumLatency(3600);
        strategyFloorBasedCollectionOffer.setPriceFeed(address(mockERC721), AZUKI_PRICE_FEED);
        vm.stopPrank();

        (bool isValid, bytes4 error) = strategyFloorBasedCollectionOffer.isValid(takerAsk, makerBid);
        assertTrue(!isValid);
        assertEq(error, IExecutionStrategy.BidTooLow.selector);

        vm.expectRevert(error);
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
}
