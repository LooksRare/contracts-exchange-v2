// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Libraries and interfaces
import {OrderStructs} from "../../../../contracts/libraries/OrderStructs.sol";
import {IExecutionManager} from "../../../../contracts/interfaces/IExecutionManager.sol";
import {IStrategyManager} from "../../../../contracts/interfaces/IStrategyManager.sol";

// Errors and constants
import {AmountInvalid, BidTooLow, OrderInvalid, CurrencyInvalid, FunctionSelectorInvalid, QuoteTypeInvalid} from "../../../../contracts/errors/SharedErrors.sol";
import {ChainlinkPriceInvalid, PriceNotRecentEnough} from "../../../../contracts/errors/ChainlinkErrors.sol";
import {MAKER_ORDER_PERMANENTLY_INVALID_NON_STANDARD_SALE, MAKER_ORDER_TEMPORARILY_INVALID_NON_STANDARD_SALE, STRATEGY_NOT_ACTIVE} from "../../../../contracts/constants/ValidationCodeConstants.sol";

// Strategies
import {StrategyChainlinkUSDDynamicAsk} from "../../../../contracts/executionStrategies/Chainlink/StrategyChainlinkUSDDynamicAsk.sol";

// Mocks and other tests
import {MockChainlinkAggregator} from "../../../mock/MockChainlinkAggregator.sol";
import {MockERC20} from "../../../mock/MockERC20.sol";
import {ProtocolBase} from "../../ProtocolBase.t.sol";

// Enums
import {AssetType} from "../../../../contracts/enums/AssetType.sol";
import {QuoteType} from "../../../../contracts/enums/QuoteType.sol";

contract USDDynamicAskOrdersTest is ProtocolBase, IStrategyManager {
    StrategyChainlinkUSDDynamicAsk public strategyUSDDynamicAsk;
    bytes4 public selector = StrategyChainlinkUSDDynamicAsk.executeStrategyWithTakerBid.selector;

    // At block 15740567
    // roundId         uint80  :  92233720368547793259
    // answer          int256  :  126533075631
    // startedAt       uint256 :  1665680123
    // updatedAt       uint256 :  1665680123
    // answeredInRound uint80  :  92233720368547793259
    uint256 private constant CHAINLINK_PRICE_UPDATED_AT = 1665680123;
    uint256 private constant FORKED_BLOCK_NUMBER = 15740567;
    uint256 private constant LATEST_CHAINLINK_ANSWER_IN_WAD = 126533075631 * 1e10;
    uint256 private constant MAXIMUM_LATENCY = 3_600 seconds;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("mainnet"), FORKED_BLOCK_NUMBER);
        _setUp();
        _setUpUsers();
        _setUpNewStrategy();
    }

    function _setUpNewStrategy() private asPrankedUser(_owner) {
        strategyUSDDynamicAsk = new StrategyChainlinkUSDDynamicAsk(
            _owner,
            address(weth),
            0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419 // Mainnet address of the Chainlink price feed
        );

        looksRareProtocol.addStrategy(
            _standardProtocolFeeBp,
            _minTotalFeeBp,
            _maxProtocolFeeBp,
            selector,
            false,
            address(strategyUSDDynamicAsk)
        );
    }

    function _createMakerAskAndTakerBid(
        uint256 numberOfItems,
        uint256 numberOfAmounts,
        uint256 desiredSalePriceInUSD
    ) private returns (OrderStructs.Maker memory newMakerAsk, OrderStructs.Taker memory newTakerBid) {
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
        newMakerAsk = _createSingleItemMakerOrder({
            quoteType: QuoteType.Ask,
            globalNonce: 0,
            subsetNonce: 0,
            strategyId: 1,
            assetType: AssetType.ERC721,
            orderNonce: 0,
            collection: address(mockERC721),
            currency: address(weth),
            signer: makerUser,
            price: 0.99 ether,
            itemId: 1
        });

        newMakerAsk.itemIds = itemIds;
        newMakerAsk.amounts = amounts;
        newMakerAsk.additionalParameters = abi.encode(desiredSalePriceInUSD);

        newTakerBid = OrderStructs.Taker(takerUser, abi.encode(1 ether));
    }

    function testNewStrategy() public {
        (
            bool strategyIsActive,
            uint16 strategyStandardProtocolFee,
            uint16 strategyMinTotalFee,
            uint16 strategyMaxProtocolFee,
            bytes4 strategySelector,
            bool strategyIsMakerBid,
            address strategyImplementation
        ) = looksRareProtocol.strategyInfo(1);

        assertTrue(strategyIsActive);
        assertEq(strategyStandardProtocolFee, _standardProtocolFeeBp);
        assertEq(strategyMinTotalFee, _minTotalFeeBp);
        assertEq(strategyMaxProtocolFee, _maxProtocolFeeBp);
        assertEq(strategySelector, selector);
        assertFalse(strategyIsMakerBid);
        assertEq(strategyImplementation, address(strategyUSDDynamicAsk));
    }

    function testMaxLatency() public {
        assertEq(strategyUSDDynamicAsk.maxLatency(), 3_600);
    }

    function testUSDDynamicAskChainlinkPriceInvalid() public {
        (OrderStructs.Maker memory makerAsk, OrderStructs.Taker memory takerBid) = _createMakerAskAndTakerBid({
            numberOfItems: 1,
            numberOfAmounts: 1,
            desiredSalePriceInUSD: LATEST_CHAINLINK_ANSWER_IN_WAD
        });

        bytes memory signature = _signMakerOrder(makerAsk, makerUserPK);

        MockChainlinkAggregator priceFeed = new MockChainlinkAggregator();
        vm.etch(CHAINLINK_ETH_USD_PRICE_FEED, address(priceFeed).code);

        MockChainlinkAggregator(CHAINLINK_ETH_USD_PRICE_FEED).setAnswer(-1);
        (bool isValid, bytes4 errorSelector) = strategyUSDDynamicAsk.isMakerOrderValid(makerAsk, selector);
        assertFalse(isValid);
        assertEq(errorSelector, ChainlinkPriceInvalid.selector);

        vm.expectRevert(errorSelector);
        vm.prank(takerUser);
        looksRareProtocol.executeTakerBid(takerBid, makerAsk, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);

        MockChainlinkAggregator(CHAINLINK_ETH_USD_PRICE_FEED).setAnswer(0);
        (isValid, errorSelector) = strategyUSDDynamicAsk.isMakerOrderValid(makerAsk, selector);
        assertFalse(isValid);
        assertEq(errorSelector, ChainlinkPriceInvalid.selector);

        vm.expectRevert(errorSelector);
        vm.prank(takerUser);
        looksRareProtocol.executeTakerBid(takerBid, makerAsk, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function testUSDDynamicAskUSDValueGreaterThanOrEqualToMinAcceptedEthValue() public {
        (OrderStructs.Maker memory makerAsk, OrderStructs.Taker memory takerBid) = _createMakerAskAndTakerBid({
            numberOfItems: 1,
            numberOfAmounts: 1,
            desiredSalePriceInUSD: LATEST_CHAINLINK_ANSWER_IN_WAD
        });

        bytes memory signature = _signMakerOrder(makerAsk, makerUserPK);

        (bool isValid, bytes4 errorSelector) = strategyUSDDynamicAsk.isMakerOrderValid(makerAsk, selector);
        assertTrue(isValid);
        assertEq(errorSelector, _EMPTY_BYTES4);

        // Execute taker bid transaction
        vm.prank(takerUser);
        looksRareProtocol.executeTakerBid(takerBid, makerAsk, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(1), takerUser);
        // Taker bid user pays the whole price
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser - 1 ether);
        // Maker ask user receives 98% of the whole price (2% protocol)
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser + 0.98 ether);
    }

    function testUSDDynamicAskUSDValueLessThanMinAcceptedEthValue() public {
        (OrderStructs.Maker memory makerAsk, OrderStructs.Taker memory takerBid) = _createMakerAskAndTakerBid({
            numberOfItems: 1,
            numberOfAmounts: 1,
            desiredSalePriceInUSD: (LATEST_CHAINLINK_ANSWER_IN_WAD * 98) / 100
        });

        bytes memory signature = _signMakerOrder(makerAsk, makerUserPK);

        (bool isValid, bytes4 errorSelector) = strategyUSDDynamicAsk.isMakerOrderValid(makerAsk, selector);
        assertTrue(isValid);
        assertEq(errorSelector, _EMPTY_BYTES4);

        // Execute taker bid transaction
        vm.prank(takerUser);
        looksRareProtocol.executeTakerBid(takerBid, makerAsk, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(1), takerUser);

        // Taker bid user pays the whole price
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser - 0.99 ether);
        // Maker ask user receives 98% of the whole price (2% protocol)
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser + 0.9702 ether);
    }

    // This tests that we can handle fractions
    function testUSDDynamicAskUSDValueLessThanOneETH() public {
        (OrderStructs.Maker memory makerAsk, OrderStructs.Taker memory takerBid) = _createMakerAskAndTakerBid({
            numberOfItems: 1,
            numberOfAmounts: 1,
            desiredSalePriceInUSD: LATEST_CHAINLINK_ANSWER_IN_WAD / 2
        });

        makerAsk.price = 0.49 ether;

        bytes memory signature = _signMakerOrder(makerAsk, makerUserPK);

        (bool isValid, bytes4 errorSelector) = strategyUSDDynamicAsk.isMakerOrderValid(makerAsk, selector);
        assertTrue(isValid);
        assertEq(errorSelector, _EMPTY_BYTES4);

        // Execute taker bid transaction
        vm.prank(takerUser);
        looksRareProtocol.executeTakerBid(takerBid, makerAsk, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(1), takerUser);

        // Taker bid user pays the whole price
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser - 0.5 ether);
        // Maker ask user receives 98% of the whole price (2% protocol)
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser + 0.49 ether);
    }

    function testUSDDynamicAskBidderOverpaid() public {
        (OrderStructs.Maker memory makerAsk, OrderStructs.Taker memory takerBid) = _createMakerAskAndTakerBid({
            numberOfItems: 1,
            numberOfAmounts: 1,
            desiredSalePriceInUSD: LATEST_CHAINLINK_ANSWER_IN_WAD
        });

        makerAsk.currency = ETH;
        // Bidder overpays by 0.1 ETH
        uint256 maxPrice = 1.1 ether;
        takerBid.additionalParameters = abi.encode(maxPrice);

        bytes memory signature = _signMakerOrder(makerAsk, makerUserPK);

        uint256 initialETHBalanceTakerUser = address(takerUser).balance;
        uint256 initialETHBalanceMakerUser = address(makerUser).balance;

        (bool isValid, bytes4 errorSelector) = strategyUSDDynamicAsk.isMakerOrderValid(makerAsk, selector);
        assertTrue(isValid);
        assertEq(errorSelector, _EMPTY_BYTES4);

        // Execute taker bid transaction
        vm.prank(takerUser);
        looksRareProtocol.executeTakerBid{value: maxPrice}(
            takerBid,
            makerAsk,
            signature,
            _EMPTY_MERKLE_TREE,
            _EMPTY_AFFILIATE
        );

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(1), takerUser);
        // Taker bid user pays the whole price, but without overpaying
        assertEq(address(takerUser).balance, initialETHBalanceTakerUser - 1 ether - 1);
        // Maker ask user receives 98% of the whole price (2% protocol)
        assertEq(address(makerUser).balance, initialETHBalanceMakerUser + 0.98 ether);
    }

    function testOraclePriceNotRecentEnough() public {
        (OrderStructs.Maker memory makerAsk, OrderStructs.Taker memory takerBid) = _createMakerAskAndTakerBid({
            numberOfItems: 1,
            numberOfAmounts: 1,
            desiredSalePriceInUSD: LATEST_CHAINLINK_ANSWER_IN_WAD
        });

        makerAsk.startTime = CHAINLINK_PRICE_UPDATED_AT;
        uint256 latencyViolationTimestamp = CHAINLINK_PRICE_UPDATED_AT + MAXIMUM_LATENCY + 1 seconds;
        makerAsk.endTime = latencyViolationTimestamp;

        bytes memory signature = _signMakerOrder(makerAsk, makerUserPK);

        vm.warp(latencyViolationTimestamp);

        bytes4 errorSelector = PriceNotRecentEnough.selector;

        _assertOrderIsInvalid(makerAsk, errorSelector);
        _assertMakerOrderReturnValidationCode(makerAsk, signature, MAKER_ORDER_TEMPORARILY_INVALID_NON_STANDARD_SALE);

        vm.expectRevert(errorSelector);
        vm.prank(takerUser);
        looksRareProtocol.executeTakerBid(takerBid, makerAsk, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function testCannotExecuteIfNotWETHOrETH() public {
        MockERC20 fakeCurrency = new MockERC20();
        vm.prank(_owner);
        looksRareProtocol.updateCurrencyStatus(address(fakeCurrency), true);

        (OrderStructs.Maker memory makerAsk, OrderStructs.Taker memory takerBid) = _createMakerAskAndTakerBid({
            numberOfItems: 1,
            numberOfAmounts: 1,
            desiredSalePriceInUSD: LATEST_CHAINLINK_ANSWER_IN_WAD
        });

        // Adjust the currency to something creative
        makerAsk.currency = address(fakeCurrency);

        bytes memory signature = _signMakerOrder(makerAsk, makerUserPK);

        (bool isValid, bytes4 errorSelector) = strategyUSDDynamicAsk.isMakerOrderValid(makerAsk, selector);
        assertFalse(isValid);
        assertEq(errorSelector, CurrencyInvalid.selector);

        vm.expectRevert(errorSelector);
        vm.prank(takerUser);
        looksRareProtocol.executeTakerBid(takerBid, makerAsk, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function testZeroItemIdsLength() public {
        (OrderStructs.Maker memory makerAsk, OrderStructs.Taker memory takerBid) = _createMakerAskAndTakerBid({
            numberOfItems: 0,
            numberOfAmounts: 0,
            desiredSalePriceInUSD: LATEST_CHAINLINK_ANSWER_IN_WAD
        });

        bytes memory signature = _signMakerOrder(makerAsk, makerUserPK);

        (bool isValid, bytes4 errorSelector) = strategyUSDDynamicAsk.isMakerOrderValid(makerAsk, selector);
        assertFalse(isValid);
        assertEq(errorSelector, OrderInvalid.selector);

        vm.expectRevert(errorSelector);
        vm.prank(takerUser);
        looksRareProtocol.executeTakerBid(takerBid, makerAsk, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function testItemIdsAndAmountsLengthMismatch() public {
        (OrderStructs.Maker memory makerAsk, OrderStructs.Taker memory takerBid) = _createMakerAskAndTakerBid({
            numberOfItems: 1,
            numberOfAmounts: 2,
            desiredSalePriceInUSD: LATEST_CHAINLINK_ANSWER_IN_WAD
        });

        bytes memory signature = _signMakerOrder(makerAsk, makerUserPK);

        (bool isValid, bytes4 errorSelector) = strategyUSDDynamicAsk.isMakerOrderValid(makerAsk, selector);
        assertFalse(isValid);
        assertEq(errorSelector, OrderInvalid.selector);

        vm.expectRevert(errorSelector);
        vm.prank(takerUser);
        looksRareProtocol.executeTakerBid(takerBid, makerAsk, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function testWrongQuoteType() public {
        OrderStructs.Maker memory makerBid = _createSingleItemMakerOrder({
            quoteType: QuoteType.Bid,
            globalNonce: 0,
            subsetNonce: 0,
            strategyId: 1,
            assetType: AssetType.ERC721,
            orderNonce: 0,
            collection: address(mockERC721),
            currency: address(weth),
            signer: makerUser,
            price: 1 ether,
            itemId: 0
        });

        (bool orderIsValid, bytes4 errorSelector) = strategyUSDDynamicAsk.isMakerOrderValid(makerBid, selector);

        assertFalse(orderIsValid);
        assertEq(errorSelector, QuoteTypeInvalid.selector);
    }

    function testZeroAmount() public {
        (OrderStructs.Maker memory makerAsk, OrderStructs.Taker memory takerBid) = _createMakerAskAndTakerBid({
            numberOfItems: 1,
            numberOfAmounts: 1,
            desiredSalePriceInUSD: LATEST_CHAINLINK_ANSWER_IN_WAD
        });

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0;
        makerAsk.amounts = amounts;

        bytes memory signature = _signMakerOrder(makerAsk, makerUserPK);

        // Valid, taker struct validation only happens during execution
        (bool isValid, bytes4 errorSelector) = strategyUSDDynamicAsk.isMakerOrderValid(makerAsk, selector);
        assertFalse(isValid);
        assertEq(errorSelector, OrderInvalid.selector);

        vm.prank(takerUser);
        vm.expectRevert(AmountInvalid.selector);
        looksRareProtocol.executeTakerBid(takerBid, makerAsk, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function testAmountGreaterThanOneForERC721() public {
        (OrderStructs.Maker memory makerAsk, OrderStructs.Taker memory takerBid) = _createMakerAskAndTakerBid({
            numberOfItems: 1,
            numberOfAmounts: 1,
            desiredSalePriceInUSD: LATEST_CHAINLINK_ANSWER_IN_WAD
        });

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 2;
        makerAsk.amounts = amounts;

        bytes memory signature = _signMakerOrder(makerAsk, makerUserPK);

        // Valid, taker struct validation only happens during execution
        _assertOrderIsInvalid(makerAsk, OrderInvalid.selector);
        _assertMakerOrderReturnValidationCode(makerAsk, signature, MAKER_ORDER_PERMANENTLY_INVALID_NON_STANDARD_SALE);

        vm.prank(takerUser);
        vm.expectRevert(AmountInvalid.selector);
        looksRareProtocol.executeTakerBid(takerBid, makerAsk, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function testTakerBidTooLow() public {
        (OrderStructs.Maker memory makerAsk, OrderStructs.Taker memory takerBid) = _createMakerAskAndTakerBid({
            numberOfItems: 1,
            numberOfAmounts: 1,
            desiredSalePriceInUSD: LATEST_CHAINLINK_ANSWER_IN_WAD
        });

        takerBid.additionalParameters = abi.encode(0.99 ether);

        bytes memory signature = _signMakerOrder(makerAsk, makerUserPK);

        // Valid, taker struct validation only happens during execution
        _assertOrderIsValid(makerAsk);
        _assertValidMakerOrder(makerAsk, signature);

        vm.expectRevert(BidTooLow.selector);
        vm.prank(takerUser);

        looksRareProtocol.executeTakerBid(takerBid, makerAsk, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function testInactiveStrategy() public {
        (OrderStructs.Maker memory makerAsk, OrderStructs.Taker memory takerBid) = _createMakerAskAndTakerBid({
            numberOfItems: 1,
            numberOfAmounts: 1,
            desiredSalePriceInUSD: LATEST_CHAINLINK_ANSWER_IN_WAD
        });

        bytes memory signature = _signMakerOrder(makerAsk, makerUserPK);

        vm.prank(_owner);
        looksRareProtocol.updateStrategy(1, false, _standardProtocolFeeBp, _minTotalFeeBp);

        _assertOrderIsValid(makerAsk);
        _assertMakerOrderReturnValidationCode(makerAsk, signature, STRATEGY_NOT_ACTIVE);

        vm.expectRevert(abi.encodeWithSelector(IExecutionManager.StrategyNotAvailable.selector, 1));
        vm.prank(takerUser);

        looksRareProtocol.executeTakerBid(takerBid, makerAsk, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function testInvalidSelector() public {
        OrderStructs.Maker memory makerAsk = _createSingleItemMakerOrder({
            quoteType: QuoteType.Ask,
            globalNonce: 0,
            subsetNonce: 0,
            strategyId: 2,
            assetType: AssetType.ERC721,
            orderNonce: 0,
            collection: address(mockERC721),
            currency: address(weth),
            signer: makerUser,
            price: 1 ether,
            itemId: 0
        });

        (bool orderIsValid, bytes4 errorSelector) = strategyUSDDynamicAsk.isMakerOrderValid(makerAsk, bytes4(0));
        assertFalse(orderIsValid);
        assertEq(errorSelector, FunctionSelectorInvalid.selector);
    }

    function _assertOrderIsInvalid(OrderStructs.Maker memory makerAsk, bytes4 expectedErrorSelector) private {
        (bool isValid, bytes4 errorSelector) = strategyUSDDynamicAsk.isMakerOrderValid(makerAsk, selector);
        assertFalse(isValid);
        assertEq(errorSelector, expectedErrorSelector);
    }

    function _assertOrderIsValid(OrderStructs.Maker memory makerAsk) private {
        (bool isValid, bytes4 errorSelector) = strategyUSDDynamicAsk.isMakerOrderValid(makerAsk, selector);
        assertTrue(isValid);
        assertEq(errorSelector, _EMPTY_BYTES4);
    }
}
