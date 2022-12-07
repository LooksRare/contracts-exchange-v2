// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";
import {IExecutionStrategy} from "../../contracts/interfaces/IExecutionStrategy.sol";
import {IStrategyManager} from "../../contracts/interfaces/IStrategyManager.sol";
import {StrategyUSDDynamicAsk} from "../../contracts/executionStrategies/StrategyUSDDynamicAsk.sol";
import {StrategyChainlinkPriceLatency} from "../../contracts/executionStrategies/StrategyChainlinkPriceLatency.sol";
import {ProtocolBase} from "./ProtocolBase.t.sol";
import {ChainlinkMaximumLatencyTest} from "./ChainlinkMaximumLatency.t.sol";
import {MockChainlinkAggregator} from "../mock/MockChainlinkAggregator.sol";

contract USDDynamicAskOrdersTest is ProtocolBase, IStrategyManager, ChainlinkMaximumLatencyTest {
    StrategyUSDDynamicAsk public strategyUSDDynamicAsk;
    bytes4 public selectorTakerAsk = _emptyBytes4;
    bytes4 public selectorTakerBid = StrategyUSDDynamicAsk.executeStrategyWithTakerBid.selector;

    // At block 15740567
    // roundId         uint80  :  92233720368547793259
    // answer          int256  :  126533075631
    // startedAt       uint256 :  1665680123
    // updatedAt       uint256 :  1665680123
    // answeredInRound uint80  :  92233720368547793259
    uint256 private constant FORKED_BLOCK_NUMBER = 15740567;
    uint256 private constant LATEST_CHAINLINK_ANSWER_IN_WAD = 126533075631 * 1e10;

    function setUp() public override {
        vm.createSelectFork(vm.rpcUrl("mainnet"), FORKED_BLOCK_NUMBER);
        super.setUp();
        _setUpUsers();
        _setUpNewStrategy();
    }

    function _setUpNewStrategy() private asPrankedUser(_owner) {
        strategyUSDDynamicAsk = new StrategyUSDDynamicAsk(address(looksRareProtocol));
        looksRareProtocol.addStrategy(
            _standardProtocolFee,
            _minTotalFee,
            _maxProtocolFee,
            selectorTakerAsk,
            selectorTakerBid,
            address(strategyUSDDynamicAsk)
        );
    }

    function _createMakerAskAndTakerBid(
        uint256 numberOfItems,
        uint256 numberOfAmounts,
        uint256 desiredSalePriceInUSD
    ) private returns (OrderStructs.MakerAsk memory newMakerAsk, OrderStructs.TakerBid memory newTakerBid) {
        uint256[] memory itemIds = new uint256[](numberOfItems);
        for (uint256 i; i < numberOfItems; ) {
            mockERC721.mint(makerUser, i + 1);
            itemIds[i] = i + 1;
            unchecked {
                ++i;
            }
        }

        uint256[] memory amounts = new uint256[](numberOfAmounts);
        for (uint256 i; i < numberOfAmounts; ) {
            amounts[i] = 1;
            unchecked {
                ++i;
            }
        }

        // Prepare the order hash
        newMakerAsk = _createSingleItemMakerAskOrder({
            askNonce: 0,
            subsetNonce: 0,
            strategyId: 1,
            assetType: 0,
            orderNonce: 0,
            collection: address(mockERC721),
            currency: address(weth),
            signer: makerUser,
            minPrice: 0.99 ether,
            itemId: 1
        });

        newMakerAsk.itemIds = itemIds;
        newMakerAsk.amounts = amounts;
        newMakerAsk.additionalParameters = abi.encode(desiredSalePriceInUSD);

        newTakerBid = OrderStructs.TakerBid(takerUser, 1 ether, itemIds, amounts, abi.encode());
    }

    function testNewStrategy() public {
        (
            bool strategyIsActive,
            uint16 strategyStandardProtocolFee,
            uint16 strategyMinTotalFee,
            uint16 strategyMaxProtocolFee,
            bytes4 strategySelectorTakerAsk,
            bytes4 strategySelectorTakerBid,
            address strategyImplementation
        ) = looksRareProtocol.strategyInfo(1);

        assertTrue(strategyIsActive);
        assertEq(strategyStandardProtocolFee, _standardProtocolFee);
        assertEq(strategyMinTotalFee, _minTotalFee);
        assertEq(strategyMaxProtocolFee, _maxProtocolFee);
        assertEq(strategySelectorTakerAsk, selectorTakerAsk);
        assertEq(strategySelectorTakerBid, selectorTakerBid);
        assertEq(strategyImplementation, address(strategyUSDDynamicAsk));
    }

    function testSetMaximumLatency() public {
        _testSetMaximumLatency(address(strategyUSDDynamicAsk));
    }

    function testSetMaximumLatencyLatencyToleranceTooHigh() public {
        _testSetMaximumLatencyLatencyToleranceTooHigh(address(strategyUSDDynamicAsk));
    }

    function testSetMaximumLatencyNotOwner() public {
        _testSetMaximumLatencyNotOwner(address(strategyUSDDynamicAsk));
    }

    function testUSDDynamicAskInvalidChainlinkPrice() public {
        (makerAsk, takerBid) = _createMakerAskAndTakerBid({
            numberOfItems: 1,
            numberOfAmounts: 1,
            desiredSalePriceInUSD: LATEST_CHAINLINK_ANSWER_IN_WAD
        });

        signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.prank(_owner);
        strategyUSDDynamicAsk.setMaximumLatency(3600);

        MockChainlinkAggregator priceFeed = new MockChainlinkAggregator();
        vm.etch(CHAINLINK_ETH_USD_PRICE_FEED, address(priceFeed).code);

        MockChainlinkAggregator(CHAINLINK_ETH_USD_PRICE_FEED).setAnswer(-1);
        (bool isValid, bytes4 errorSelector) = strategyUSDDynamicAsk.isValid(makerAsk);
        assertFalse(isValid);
        assertEq(errorSelector, StrategyUSDDynamicAsk.InvalidChainlinkPrice.selector);

        vm.expectRevert(errorSelector);
        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerBid(takerBid, makerAsk, signature, _emptyMerkleTree, _emptyAffiliate);

        MockChainlinkAggregator(CHAINLINK_ETH_USD_PRICE_FEED).setAnswer(0);
        (isValid, errorSelector) = strategyUSDDynamicAsk.isValid(makerAsk);
        assertFalse(isValid);
        assertEq(errorSelector, StrategyUSDDynamicAsk.InvalidChainlinkPrice.selector);

        vm.expectRevert(errorSelector);
        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerBid(takerBid, makerAsk, signature, _emptyMerkleTree, _emptyAffiliate);
    }

    function testUSDDynamicAskUSDValueGreaterThanOrEqualToMinAcceptedEthValue() public {
        (makerAsk, takerBid) = _createMakerAskAndTakerBid({
            numberOfItems: 1,
            numberOfAmounts: 1,
            desiredSalePriceInUSD: LATEST_CHAINLINK_ANSWER_IN_WAD
        });

        signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.prank(_owner);
        strategyUSDDynamicAsk.setMaximumLatency(3600);

        (bool isValid, bytes4 errorSelector) = strategyUSDDynamicAsk.isValid(makerAsk);
        assertTrue(isValid);
        assertEq(errorSelector, bytes4(0));

        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerBid(takerBid, makerAsk, signature, _emptyMerkleTree, _emptyAffiliate);

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(1), takerUser);
        // Taker bid user pays the whole price
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser - 1 ether);
        // Maker ask user receives 98% of the whole price (2% protocol)
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser + 0.98 ether);
    }

    function testUSDDynamicAskUSDValueLessThanMinAcceptedEthValue() public {
        (makerAsk, takerBid) = _createMakerAskAndTakerBid({
            numberOfItems: 1,
            numberOfAmounts: 1,
            desiredSalePriceInUSD: (LATEST_CHAINLINK_ANSWER_IN_WAD * 98) / 100
        });

        signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.prank(_owner);
        strategyUSDDynamicAsk.setMaximumLatency(3600);

        (bool isValid, bytes4 errorSelector) = strategyUSDDynamicAsk.isValid(makerAsk);
        assertTrue(isValid);
        assertEq(errorSelector, bytes4(0));

        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerBid(takerBid, makerAsk, signature, _emptyMerkleTree, _emptyAffiliate);

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(1), takerUser);

        // Taker bid user pays the whole price
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser - 0.99 ether);
        // Maker ask user receives 98% of the whole price (2% protocol)
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser + 0.9702 ether);
    }

    // This tests that we can handle fractions
    function testUSDDynamicAskUSDValueLessThanOneETH() public {
        (makerAsk, takerBid) = _createMakerAskAndTakerBid({
            numberOfItems: 1,
            numberOfAmounts: 1,
            desiredSalePriceInUSD: LATEST_CHAINLINK_ANSWER_IN_WAD / 2
        });

        makerAsk.minPrice = 0.49 ether;

        signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.prank(_owner);
        strategyUSDDynamicAsk.setMaximumLatency(3600);

        (bool isValid, bytes4 errorSelector) = strategyUSDDynamicAsk.isValid(makerAsk);
        assertTrue(isValid);
        assertEq(errorSelector, bytes4(0));

        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerBid(takerBid, makerAsk, signature, _emptyMerkleTree, _emptyAffiliate);

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(1), takerUser);

        // Taker bid user pays the whole price
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser - 0.5 ether);
        // Maker ask user receives 98% of the whole price (2% protocol)
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser + 0.49 ether);
    }

    function testUSDDynamicAskBidderOverpaid() public {
        (makerAsk, takerBid) = _createMakerAskAndTakerBid({
            numberOfItems: 1,
            numberOfAmounts: 1,
            desiredSalePriceInUSD: LATEST_CHAINLINK_ANSWER_IN_WAD
        });

        // Make the order currency native ETH
        makerAsk.currency = address(0);
        // Bidder overpays by 0.1 ETH
        takerBid.maxPrice = 1.1 ether;

        signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.prank(_owner);
        strategyUSDDynamicAsk.setMaximumLatency(3600);

        uint256 initialETHBalanceTakerUser = address(takerUser).balance;
        uint256 initialETHBalanceMakerUser = address(makerUser).balance;

        (bool isValid, bytes4 errorSelector) = strategyUSDDynamicAsk.isValid(makerAsk);
        assertTrue(isValid);
        assertEq(errorSelector, bytes4(0));

        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerBid{value: takerBid.maxPrice}(
            takerBid,
            makerAsk,
            signature,
            _emptyMerkleTree,
            _emptyAffiliate
        );

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(1), takerUser);
        // Taker bid user pays the whole price, but without overpaying
        assertEq(address(takerUser).balance, initialETHBalanceTakerUser - 1 ether - 1);
        // Maker ask user receives 98% of the whole price (2% protocol)
        assertEq(address(makerUser).balance, initialETHBalanceMakerUser + 0.98 ether);
    }

    function testOraclePriceNotRecentEnough() public {
        (makerAsk, takerBid) = _createMakerAskAndTakerBid({
            numberOfItems: 1,
            numberOfAmounts: 1,
            desiredSalePriceInUSD: LATEST_CHAINLINK_ANSWER_IN_WAD
        });

        signature = _signMakerAsk(makerAsk, makerUserPK);

        (bool isValid, bytes4 errorSelector) = strategyUSDDynamicAsk.isValid(makerAsk);
        assertFalse(isValid);
        assertEq(errorSelector, StrategyChainlinkPriceLatency.PriceNotRecentEnough.selector);

        vm.expectRevert(errorSelector);
        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerBid(takerBid, makerAsk, signature, _emptyMerkleTree, _emptyAffiliate);
    }

    function testCallerNotLooksRareProtocol() public {
        (makerAsk, takerBid) = _createMakerAskAndTakerBid({
            numberOfItems: 1,
            numberOfAmounts: 1,
            desiredSalePriceInUSD: LATEST_CHAINLINK_ANSWER_IN_WAD
        });

        vm.prank(_owner);
        strategyUSDDynamicAsk.setMaximumLatency(3600);

        // Valid, but wrong caller
        (bool isValid, bytes4 errorSelector) = strategyUSDDynamicAsk.isValid(makerAsk);
        assertTrue(isValid);
        assertEq(errorSelector, bytes4(0));

        vm.expectRevert(IExecutionStrategy.WrongCaller.selector);
        // Call the function directly
        strategyUSDDynamicAsk.executeStrategyWithTakerBid(takerBid, makerAsk);
    }

    function testZeroItemIdsLength() public {
        (makerAsk, takerBid) = _createMakerAskAndTakerBid({
            numberOfItems: 0,
            numberOfAmounts: 0,
            desiredSalePriceInUSD: LATEST_CHAINLINK_ANSWER_IN_WAD
        });

        signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.prank(_owner);
        strategyUSDDynamicAsk.setMaximumLatency(3600);

        (bool isValid, bytes4 errorSelector) = strategyUSDDynamicAsk.isValid(makerAsk);
        assertFalse(isValid);
        assertEq(errorSelector, IExecutionStrategy.OrderInvalid.selector);

        vm.expectRevert(errorSelector);
        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerBid(takerBid, makerAsk, signature, _emptyMerkleTree, _emptyAffiliate);
    }

    function testItemIdsAndAmountsLengthMismatch() public {
        (makerAsk, takerBid) = _createMakerAskAndTakerBid({
            numberOfItems: 1,
            numberOfAmounts: 2,
            desiredSalePriceInUSD: LATEST_CHAINLINK_ANSWER_IN_WAD
        });

        signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.prank(_owner);
        strategyUSDDynamicAsk.setMaximumLatency(3600);

        (bool isValid, bytes4 errorSelector) = strategyUSDDynamicAsk.isValid(makerAsk);
        assertFalse(isValid);
        assertEq(errorSelector, IExecutionStrategy.OrderInvalid.selector);

        vm.expectRevert(errorSelector);
        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerBid(takerBid, makerAsk, signature, _emptyMerkleTree, _emptyAffiliate);
    }

    function testItemIdsMismatch() public {
        (makerAsk, takerBid) = _createMakerAskAndTakerBid({
            numberOfItems: 1,
            numberOfAmounts: 1,
            desiredSalePriceInUSD: LATEST_CHAINLINK_ANSWER_IN_WAD
        });

        uint256[] memory itemIds = new uint256[](1);
        itemIds[0] = 2;

        // Bidder bidding on something else
        takerBid.itemIds = itemIds;

        signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.prank(_owner);
        strategyUSDDynamicAsk.setMaximumLatency(3600);

        // Valid, taker struct validation only happens during execution
        (bool isValid, bytes4 errorSelector) = strategyUSDDynamicAsk.isValid(makerAsk);
        assertTrue(isValid);
        assertEq(errorSelector, bytes4(0));

        vm.expectRevert(IExecutionStrategy.OrderInvalid.selector);
        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerBid(takerBid, makerAsk, signature, _emptyMerkleTree, _emptyAffiliate);
    }

    function testZeroAmount() public {
        (makerAsk, takerBid) = _createMakerAskAndTakerBid({
            numberOfItems: 1,
            numberOfAmounts: 1,
            desiredSalePriceInUSD: LATEST_CHAINLINK_ANSWER_IN_WAD
        });

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0;
        makerAsk.amounts = amounts;

        signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.prank(_owner);
        strategyUSDDynamicAsk.setMaximumLatency(3600);

        // Valid, taker struct validation only happens during execution
        (bool isValid, bytes4 errorSelector) = strategyUSDDynamicAsk.isValid(makerAsk);
        assertTrue(isValid);
        assertEq(errorSelector, bytes4(0));

        vm.expectRevert(IExecutionStrategy.OrderInvalid.selector);
        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerBid(takerBid, makerAsk, signature, _emptyMerkleTree, _emptyAffiliate);
    }

    function testTakerBidTooLow() public {
        (makerAsk, takerBid) = _createMakerAskAndTakerBid({
            numberOfItems: 1,
            numberOfAmounts: 1,
            desiredSalePriceInUSD: LATEST_CHAINLINK_ANSWER_IN_WAD
        });

        takerBid.maxPrice = 0.99 ether;

        signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.prank(_owner);
        strategyUSDDynamicAsk.setMaximumLatency(3600);

        // Valid, taker struct validation only happens during execution
        (bool isValid, bytes4 errorSelector) = strategyUSDDynamicAsk.isValid(makerAsk);
        assertTrue(isValid);
        assertEq(errorSelector, bytes4(0));

        vm.expectRevert(IExecutionStrategy.BidTooLow.selector);
        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerBid(takerBid, makerAsk, signature, _emptyMerkleTree, _emptyAffiliate);
    }
}
