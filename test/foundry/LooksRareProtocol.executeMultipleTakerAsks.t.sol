// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Libraries
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";
import {LengthsInvalid} from "../../contracts/errors/SharedErrors.sol";
import {ERC721TransferFromFail} from "@looksrare/contracts-libs/contracts/lowLevelCallers/LowLevelERC721Transfer.sol";

// Base test
import {ProtocolBase} from "./ProtocolBase.t.sol";

// Shared errors
import {CallerInvalid, CurrencyInvalid} from "../../contracts/errors/SharedErrors.sol";
import {CURRENCY_NOT_ALLOWED} from "../../contracts/constants/ValidationCodeConstants.sol";

// Other mocks and utils
import {MockERC20} from "../mock/MockERC20.sol";

// Enums
import {QuoteType} from "../../contracts/enums/QuoteType.sol";

contract LooksRareProtocolExecuteMultipleTakerAsksTest is ProtocolBase {
    // Fixed price of sale
    uint256 private constant price = 1 ether;

    // Mock files
    MockERC20 private mockERC20;

    function setUp() public {
        _setUp();
        vm.prank(_owner);
        mockERC20 = new MockERC20();
    }

    /**
     * Three ERC721 are sold through 3 taker asks in one transaction with non-atomicity.
     */
    function testThreeTakerAsksERC721() public {
        _setUpUsers();

        uint256 numberOfPurchases = 3;

        BatchExecutionParameters[] memory batchExecutionParameters = _batchERC721ExecutionSetUp(
            price,
            numberOfPurchases,
            QuoteType.Bid
        );

        // Execute taker ask transaction
        vm.prank(takerUser);
        looksRareProtocol.executeMultipleTakerAsks(batchExecutionParameters, _EMPTY_AFFILIATE, false);

        for (uint256 i; i < numberOfPurchases; i++) {
            // Maker user has received the asset
            assertEq(mockERC721.ownerOf(i), makerUser);
            // Verify the nonce is marked as executed
            assertEq(looksRareProtocol.userOrderNonce(makerUser, i), MAGIC_VALUE_ORDER_NONCE_EXECUTED);
        }

        _assertBuyerPaidWETH(makerUser, price * numberOfPurchases);
        _assertSellerReceivedWETHAfterStandardProtocolFee(takerUser, price * numberOfPurchases);
    }

    function testThreeTakerAsksERC721DifferentSignerForEachBidAtomic() public {
        _testThreeTakerAsksERC721DifferentSignerForEachBid(true);
    }

    function testThreeTakerAsksERC721DifferentSignerForEachBidNonAtomic() public {
        _testThreeTakerAsksERC721DifferentSignerForEachBid(false);
    }

    function _testThreeTakerAsksERC721DifferentSignerForEachBid(bool isAtomic) public {
        _setUpUsers();

        uint256 numberOfPurchases = 3;

        BatchExecutionParameters[] memory batchExecutionParameters = _batchERC721ExecutionSetUp(
            price,
            numberOfPurchases,
            QuoteType.Bid
        );

        for (uint256 i; i < batchExecutionParameters.length; i++) {
            uint256 privateKey = i + 3;
            address signer = vm.addr(privateKey);

            deal(address(weth), signer, _initialWETHBalanceUser);
            vm.prank(signer);
            weth.approve(address(looksRareProtocol), price);

            batchExecutionParameters[i].maker.signer = signer;
            batchExecutionParameters[i].makerSignature = _signMakerOrder(batchExecutionParameters[i].maker, privateKey);
        }

        // Execute taker ask transaction
        vm.prank(takerUser);
        looksRareProtocol.executeMultipleTakerAsks(batchExecutionParameters, _EMPTY_AFFILIATE, isAtomic);

        for (uint256 i; i < numberOfPurchases; i++) {
            address maker = vm.addr(i + 3);
            // Maker user has received the asset
            assertEq(mockERC721.ownerOf(i), maker);
            // Verify the nonce is marked as executed
            assertEq(looksRareProtocol.userOrderNonce(maker, i), MAGIC_VALUE_ORDER_NONCE_EXECUTED);
            _assertBuyerPaidWETH(maker, price);
        }

        _assertSellerReceivedWETHAfterStandardProtocolFee(takerUser, price * numberOfPurchases);
    }

    function testThreeTakerAsksERC721LastSignerIsTheSameAsThePenultimateSignerAtomic() public {
        _testThreeTakerAsksERC721LastSignerIsTheSameAsThePenultimateSigner(true);
    }

    function testThreeTakerAsksERC721LastSignerIsTheSameAsThePenultimateSignerNonAtomic() public {
        _testThreeTakerAsksERC721LastSignerIsTheSameAsThePenultimateSigner(false);
    }

    function _testThreeTakerAsksERC721LastSignerIsTheSameAsThePenultimateSigner(bool isAtomic) private {
        _setUpUsers();

        uint256 numberOfPurchases = 3;

        BatchExecutionParameters[] memory batchExecutionParameters = _batchERC721ExecutionSetUp(
            price,
            numberOfPurchases,
            QuoteType.Bid
        );

        // 1st signer != 2nd/3rd signer
        uint256 privateKey = 3;
        address signer = vm.addr(privateKey);

        deal(address(weth), signer, _initialWETHBalanceUser);
        vm.prank(signer);
        weth.approve(address(looksRareProtocol), price);

        batchExecutionParameters[0].maker.signer = signer;
        batchExecutionParameters[0].makerSignature = _signMakerOrder(batchExecutionParameters[0].maker, privateKey);

        // Execute taker ask transaction
        vm.prank(takerUser);
        looksRareProtocol.executeMultipleTakerAsks(batchExecutionParameters, _EMPTY_AFFILIATE, isAtomic);

        address makerOne = vm.addr(3);
        // Maker user has received the asset
        assertEq(mockERC721.ownerOf(0), makerOne);
        // Verify the nonce is marked as executed
        assertEq(looksRareProtocol.userOrderNonce(makerOne, 0), MAGIC_VALUE_ORDER_NONCE_EXECUTED);
        _assertBuyerPaidWETH(makerOne, price);

        // Maker user has received the assets
        assertEq(mockERC721.ownerOf(1), makerUser);
        assertEq(mockERC721.ownerOf(2), makerUser);
        // Verify the nonce is marked as executed
        assertEq(looksRareProtocol.userOrderNonce(makerUser, 1), MAGIC_VALUE_ORDER_NONCE_EXECUTED);
        assertEq(looksRareProtocol.userOrderNonce(makerUser, 2), MAGIC_VALUE_ORDER_NONCE_EXECUTED);
        _assertBuyerPaidWETH(makerUser, price * 2);

        _assertSellerReceivedWETHAfterStandardProtocolFee(takerUser, price * numberOfPurchases);
    }

    /**
     * Transaction cannot go through if atomic, goes through if non-atomic (fund returns to buyer).
     */
    function testThreeTakerAsksERC721OneFails() public {
        _setUpUsers();

        uint256 numberOfPurchases = 3;
        uint256 faultyTokenId = numberOfPurchases - 1;

        BatchExecutionParameters[] memory batchExecutionParameters = _batchERC721ExecutionSetUp(
            price,
            numberOfPurchases,
            QuoteType.Bid
        );

        // Transfer tokenId = 2 to random user
        vm.prank(takerUser);
        mockERC721.transferFrom(takerUser, _randomUser, faultyTokenId);

        /**
         * 1. The whole purchase fails if execution is atomic
         */
        vm.expectRevert(abi.encodeWithSelector(ERC721TransferFromFail.selector));
        vm.prank(takerUser);
        looksRareProtocol.executeMultipleTakerAsks(batchExecutionParameters, _EMPTY_AFFILIATE, true);

        /**
         * 2. The whole purchase doesn't fail if execution is not-atomic
         */
        vm.prank(takerUser);
        looksRareProtocol.executeMultipleTakerAsks(batchExecutionParameters, _EMPTY_AFFILIATE, false);

        for (uint256 i; i < faultyTokenId; i++) {
            // Maker user has received the first two assets
            assertEq(mockERC721.ownerOf(i), makerUser);
            // Verify the first two nonces are marked as executed
            assertEq(looksRareProtocol.userOrderNonce(makerUser, i), MAGIC_VALUE_ORDER_NONCE_EXECUTED);
        }

        // Taker user has not received the asset
        assertEq(mockERC721.ownerOf(faultyTokenId), _randomUser);
        // Verify the nonce is NOT marked as executed
        assertEq(looksRareProtocol.userOrderNonce(makerUser, faultyTokenId), bytes32(0));
        _assertBuyerPaidWETH(makerUser, price * (numberOfPurchases - 1));
        _assertSellerReceivedWETHAfterStandardProtocolFee(takerUser, price * (numberOfPurchases - 1));
    }

    function testThreeTakerAsksERC721LengthsInvalid() public {
        _setUpUsers();

        BatchExecutionParameters[] memory batchExecutionParameters = new BatchExecutionParameters[](0);
        vm.expectRevert(LengthsInvalid.selector);
        vm.prank(takerUser);
        looksRareProtocol.executeMultipleTakerAsks(batchExecutionParameters, _EMPTY_AFFILIATE, false);
    }

    function testCannotTradeIfCurrencyInvalid() public {
        _testCannotTradeIfCurrencyInvalid(address(mockERC20));
    }

    function testCannotTradeIfETHIsUsedForMakerBid() public {
        _testCannotTradeIfCurrencyInvalid(ETH);
    }

    function testCannotCallRestrictedExecuteTakerAsk() public {
        _setUpUsers();

        (OrderStructs.Maker memory makerBid, OrderStructs.Taker memory takerAsk) = _createMockMakerBidAndTakerAsk(
            address(mockERC721),
            address(mockERC20)
        );

        // Mint asset
        mockERC721.mint(takerUser, makerBid.itemIds[0]);

        vm.prank(takerUser);
        vm.expectRevert(CallerInvalid.selector);
        looksRareProtocol.restrictedExecuteTakerOrder(takerAsk, makerBid, takerUser, _computeOrderHash(makerBid));
    }

    /**
     * Cannot execute two or more taker bids if the currencies are different
     */
    function testCannotExecuteMultipleTakerAsksIfDifferentCurrenciesIsAtomic() public {
        _testCannotExecuteMultipleTakerAsksIfDifferentCurrencies(true);
    }

    function testCannotExecuteMultipleTakerAsksIfDifferentCurrenciesIsNonAtomic() public {
        _testCannotExecuteMultipleTakerAsksIfDifferentCurrencies(false);
    }

    function _testCannotExecuteMultipleTakerAsksIfDifferentCurrencies(bool isAtomic) public {
        _setUpUsers();
        vm.prank(_owner);
        looksRareProtocol.updateCurrencyStatus(address(weth), true);

        uint256 numberOfPurchases = 2;

        BatchExecutionParameters[] memory batchExecutionParameters = _batchERC721ExecutionSetUp(
            price,
            numberOfPurchases,
            QuoteType.Bid
        );
        batchExecutionParameters[1].maker.currency = address(mockERC20);

        vm.prank(takerUser);
        vm.expectRevert(CurrencyInvalid.selector);
        looksRareProtocol.executeMultipleTakerAsks(batchExecutionParameters, _EMPTY_AFFILIATE, isAtomic);
    }

    function _testCannotTradeIfCurrencyInvalid(address currency) private {
        _setUpUsers();

        (OrderStructs.Maker memory makerBid, OrderStructs.Taker memory takerAsk) = _createMockMakerBidAndTakerAsk(
            address(mockERC721),
            currency
        );

        // Mint asset
        mockERC721.mint(takerUser, makerBid.itemIds[0]);

        // Sign order
        bytes memory signature = _signMakerOrder(makerBid, makerUserPK);

        // Verify validity of maker ask order
        _assertMakerOrderReturnValidationCode(makerBid, signature, CURRENCY_NOT_ALLOWED);

        BatchExecutionParameters[] memory batchExecutionParameters = new BatchExecutionParameters[](1);

        batchExecutionParameters[0].maker = makerBid;
        batchExecutionParameters[0].taker = takerAsk;
        batchExecutionParameters[0].makerSignature = signature;

        bool[2] memory boolFlags = _boolFlagsArray();
        for (uint256 i; i < boolFlags.length; i++) {
            vm.prank(takerUser);
            vm.expectRevert(CurrencyInvalid.selector);
            looksRareProtocol.executeMultipleTakerAsks(batchExecutionParameters, _EMPTY_AFFILIATE, boolFlags[i]);
        }
    }
}
