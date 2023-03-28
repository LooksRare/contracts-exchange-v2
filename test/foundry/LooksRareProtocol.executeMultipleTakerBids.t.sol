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

contract LooksRareProtocolExecuteMultipleTakerBidsTest is ProtocolBase {
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
     * Three ERC721 are sold through 3 taker bids in one transaction with non-atomicity.
     */
    function test_ThreeTakerBidsERC721() public {
        _setUpUsers();

        uint256 numberOfPurchases = 3;

        BatchExecutionParameters[] memory batchExecutionParameters = _batchERC721ExecutionSetUp(
            price,
            numberOfPurchases,
            QuoteType.Ask
        );

        // Execute taker bid transaction
        vm.prank(takerUser);
        looksRareProtocol.executeMultipleTakerBids{value: price * numberOfPurchases}(
            batchExecutionParameters,
            _EMPTY_AFFILIATE,
            false
        );

        for (uint256 i; i < numberOfPurchases; i++) {
            // Taker user has received the asset
            assertEq(mockERC721.ownerOf(i), takerUser);
            // Verify the nonce is marked as executed
            assertEq(looksRareProtocol.userOrderNonce(makerUser, i), MAGIC_VALUE_ORDER_NONCE_EXECUTED);
        }

        _assertBuyerPaidETH(takerUser, price * numberOfPurchases);
        _assertSellerReceivedETHAfterStandardProtocolFee(makerUser, price * numberOfPurchases);
        // No leftover in the balance of the contract
        assertEq(address(looksRareProtocol).balance, 0);
    }

    /**
     * Transaction cannot go through if atomic, goes through if non-atomic (fund returns to buyer).
     */
    function test_ThreeTakerBidsERC721_RevertIf_OneFails() public {
        _setUpUsers();

        uint256 numberOfPurchases = 3;
        uint256 faultyTokenId = numberOfPurchases - 1;

        BatchExecutionParameters[] memory batchExecutionParameters = _batchERC721ExecutionSetUp(
            price,
            numberOfPurchases,
            QuoteType.Ask
        );

        // Transfer tokenId = 2 to random user
        vm.prank(makerUser);
        mockERC721.transferFrom(makerUser, _randomUser, faultyTokenId);

        /**
         * 1. The whole purchase fails if execution is atomic
         */
        vm.expectRevert(abi.encodeWithSelector(ERC721TransferFromFail.selector));
        vm.prank(takerUser);
        looksRareProtocol.executeMultipleTakerBids{value: price * numberOfPurchases}(
            batchExecutionParameters,
            _EMPTY_AFFILIATE,
            true
        );

        /**
         * 2. The whole purchase doesn't fail if execution is not-atomic
         */
        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeMultipleTakerBids{value: price * numberOfPurchases}(
            batchExecutionParameters,
            _EMPTY_AFFILIATE,
            false
        );

        for (uint256 i; i < faultyTokenId; i++) {
            // Taker user has received the first two assets
            assertEq(mockERC721.ownerOf(i), takerUser);
            // Verify the first two nonces are marked as executed
            assertEq(looksRareProtocol.userOrderNonce(makerUser, i), MAGIC_VALUE_ORDER_NONCE_EXECUTED);
        }

        // Taker user has not received the asset
        assertEq(mockERC721.ownerOf(faultyTokenId), _randomUser);
        // Verify the nonce is NOT marked as executed
        assertEq(looksRareProtocol.userOrderNonce(makerUser, faultyTokenId), bytes32(0));
        // Taker bid user pays the whole price
        assertEq(takerUser.balance, _initialETHBalanceUser - 1 - ((numberOfPurchases - 1) * price));
        _assertSellerReceivedETHAfterStandardProtocolFee(makerUser, price * (numberOfPurchases - 1));
        // 1 wei left in the balance of the contract
        assertEq(address(looksRareProtocol).balance, 1);
    }

    function test_ThreeTakerBidsERC721LengthsInvalid() public {
        _setUpUsers();

        BatchExecutionParameters[] memory batchExecutionParameters = new BatchExecutionParameters[](0);
        vm.expectRevert(LengthsInvalid.selector);
        vm.prank(takerUser);
        looksRareProtocol.executeMultipleTakerBids(batchExecutionParameters, _EMPTY_AFFILIATE, false);
    }

    function test_Trade_RevertIf_CurrencyInvalid() public {
        _setUpUsers();

        (OrderStructs.Maker memory makerAsk, OrderStructs.Taker memory takerBid) = _createMockMakerAskAndTakerBid(
            address(mockERC721)
        );
        makerAsk.currency = address(mockERC20);

        // Mint asset
        mockERC721.mint(makerUser, makerAsk.itemIds[0]);

        // Sign order
        bytes memory signature = _signMakerOrder(makerAsk, makerUserPK);

        // Verify validity of maker ask order
        _assertMakerOrderReturnValidationCode(makerAsk, signature, CURRENCY_NOT_ALLOWED);

        vm.prank(takerUser);
        vm.expectRevert(CurrencyInvalid.selector);
        looksRareProtocol.executeTakerBid{value: price}(
            takerBid,
            makerAsk,
            signature,
            _EMPTY_MERKLE_TREE,
            _EMPTY_AFFILIATE
        );

        BatchExecutionParameters[] memory batchExecutionParameters = new BatchExecutionParameters[](1);
        batchExecutionParameters[0].maker = makerAsk;
        batchExecutionParameters[0].taker = takerBid;
        batchExecutionParameters[0].makerSignature = signature;

        bool[2] memory boolFlags = _boolFlagsArray();
        for (uint256 i; i < boolFlags.length; i++) {
            vm.prank(takerUser);
            vm.expectRevert(CurrencyInvalid.selector);
            looksRareProtocol.executeMultipleTakerBids{value: price}(
                batchExecutionParameters,
                _EMPTY_AFFILIATE,
                boolFlags[i]
            );
        }
    }

    function test_RestrictedExecuteTakerBid_RevertIf_NotSelf() public {
        _setUpUsers();

        (OrderStructs.Maker memory makerAsk, OrderStructs.Taker memory takerBid) = _createMockMakerAskAndTakerBid(
            address(mockERC721)
        );

        // Mint asset
        mockERC721.mint(makerUser, makerAsk.itemIds[0]);

        vm.prank(takerUser);
        vm.expectRevert(CallerInvalid.selector);
        looksRareProtocol.restrictedExecuteTakerOrder(takerBid, makerAsk, takerUser, _computeOrderHash(makerAsk));
    }

    /**
     * Cannot execute two or more taker bids if the currencies are different
     */
    function test_ExecuteMultipleTakerBids_RevertIf_DifferentCurrenciesIsAtomic() public {
        _testCannotExecuteMultipleTakerBidsIfDifferentCurrencies(true);
    }

    function test_ExecuteMultipleTakerBids_RevertIf_DifferentCurrenciesIsNonAtomic() public {
        _testCannotExecuteMultipleTakerBidsIfDifferentCurrencies(false);
    }

    function _testCannotExecuteMultipleTakerBidsIfDifferentCurrencies(bool isAtomic) public {
        _setUpUsers();
        vm.prank(_owner);
        looksRareProtocol.updateCurrencyStatus(address(mockERC20), true);

        uint256 numberOfPurchases = 2;

        BatchExecutionParameters[] memory batchExecutionParameters = _batchERC721ExecutionSetUp(
            price,
            numberOfPurchases,
            QuoteType.Ask
        );
        batchExecutionParameters[1].maker.currency = address(mockERC20);

        vm.prank(takerUser);
        vm.expectRevert(CurrencyInvalid.selector);
        looksRareProtocol.executeMultipleTakerBids{value: price}(batchExecutionParameters, _EMPTY_AFFILIATE, isAtomic);
    }
}
