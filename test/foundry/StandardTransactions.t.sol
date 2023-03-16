// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Libraries, interfaces, errors
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";
import {LengthsInvalid} from "../../contracts/errors/SharedErrors.sol";

import {CreatorFeeManagerWithRoyalties} from "../../contracts/CreatorFeeManagerWithRoyalties.sol";

// Base test
import {ProtocolBase} from "./ProtocolBase.t.sol";

// Constants
import {ONE_HUNDRED_PERCENT_IN_BP} from "../../contracts/constants/NumericConstants.sol";

// Enums
import {CollectionType} from "../../contracts/enums/CollectionType.sol";
import {QuoteType} from "../../contracts/enums/QuoteType.sol";

contract StandardTransactionsTest is ProtocolBase {
    error ERC721TransferFromFail();

    uint256 private constant itemId = 420;
    uint16 private constant NEW_ROYALTY_FEE = uint16(50);

    function setUp() public {
        _setUp();
        CreatorFeeManagerWithRoyalties creatorFeeManager = new CreatorFeeManagerWithRoyalties(
            address(royaltyFeeRegistry)
        );
        vm.prank(_owner);
        looksRareProtocol.updateCreatorFeeManager(address(creatorFeeManager));
    }

    /**
     * One ERC721 (where royalties come from the registry) is sold through a taker bid
     */
    function testTakerBidERC721WithRoyaltiesFromRegistry(uint256 price) public {
        vm.assume(price <= 2 ether);
        _setUpUsers();
        _setupRegistryRoyalties(address(mockERC721), NEW_ROYALTY_FEE);

        (OrderStructs.Maker memory makerAsk, OrderStructs.Taker memory takerBid) = _createMockMakerAskAndTakerBid(
            address(mockERC721)
        );
        makerAsk.price = price;

        bytes memory signature = _signMakerOrder(makerAsk, makerUserPK);

        // Mint asset
        mockERC721.mint(makerUser, makerAsk.itemIds[0]);

        // Verify validity of maker ask order
        _assertValidMakerOrder(makerAsk, signature);

        // Arrays for events
        uint256[3] memory expectedFees = _calculateExpectedFees({price: price, royaltyFeeBp: NEW_ROYALTY_FEE});
        address[2] memory expectedRecipients;

        expectedRecipients[0] = makerUser;
        expectedRecipients[1] = _royaltyRecipient;

        // Execute taker bid transaction
        vm.prank(takerUser);
        vm.expectEmit({checkTopic1: true, checkTopic2: false, checkTopic3: false, checkData: true});

        emit TakerBid(
            NonceInvalidationParameters({
                orderHash: _computeOrderHash(makerAsk),
                orderNonce: makerAsk.orderNonce,
                isNonceInvalidated: true
            }),
            takerUser,
            takerUser,
            makerAsk.strategyId,
            makerAsk.currency,
            makerAsk.collection,
            makerAsk.itemIds,
            makerAsk.amounts,
            expectedRecipients,
            expectedFees
        );

        looksRareProtocol.executeTakerBid{value: price}(
            takerBid,
            makerAsk,
            signature,
            _EMPTY_MERKLE_TREE,
            _EMPTY_AFFILIATE
        );

        _assertSuccessfulExecutionThroughETH(takerUser, makerUser, price, expectedFees);

        // No leftover in the balance of the contract
        assertEq(address(looksRareProtocol).balance, 0);
        // Verify the nonce is marked as executed
        assertEq(looksRareProtocol.userOrderNonce(makerUser, makerAsk.orderNonce), MAGIC_VALUE_ORDER_NONCE_EXECUTED);
    }

    /**
     * One ERC721 is sold through taker bid. Address zero is specified as the recipient in the taker struct.
     */
    function testTakerBidERC721WithAddressZeroSpecifiedAsRecipient(uint256 price) public {
        vm.assume(price <= 2 ether);
        _setUpUsers();

        (OrderStructs.Maker memory makerAsk, OrderStructs.Taker memory takerBid) = _createMockMakerAskAndTakerBid(
            address(mockERC721)
        );
        makerAsk.price = price;

        bytes memory signature = _signMakerOrder(makerAsk, makerUserPK);

        // Mint asset
        mockERC721.mint(makerUser, makerAsk.itemIds[0]);

        // Adjustment
        takerBid.recipient = address(0);

        // Verify validity of maker ask order
        _assertValidMakerOrder(makerAsk, signature);

        // Arrays for events
        uint256[3] memory expectedFees = _calculateExpectedFees({price: price, royaltyFeeBp: 0});
        address[2] memory expectedRecipients;

        expectedRecipients[0] = makerUser;
        expectedRecipients[1] = address(0); // No royalties

        // Execute taker bid transaction
        vm.prank(takerUser);
        vm.expectEmit({checkTopic1: true, checkTopic2: false, checkTopic3: false, checkData: true});

        emit TakerBid(
            NonceInvalidationParameters({
                orderHash: _computeOrderHash(makerAsk),
                orderNonce: makerAsk.orderNonce,
                isNonceInvalidated: true
            }),
            takerUser,
            takerUser,
            makerAsk.strategyId,
            makerAsk.currency,
            makerAsk.collection,
            makerAsk.itemIds,
            makerAsk.amounts,
            expectedRecipients,
            expectedFees
        );

        looksRareProtocol.executeTakerBid{value: price}(
            takerBid,
            makerAsk,
            signature,
            _EMPTY_MERKLE_TREE,
            _EMPTY_AFFILIATE
        );

        _assertSuccessfulExecutionThroughETH(takerUser, makerUser, price, expectedFees);
    }

    /**
     * One ERC721 (where royalties come from the registry) is sold through a taker ask using WETH
     */
    function testTakerAskERC721WithRoyaltiesFromRegistry(uint256 price) public {
        vm.assume(price <= 2 ether);

        _setUpUsers();
        _setupRegistryRoyalties(address(mockERC721), NEW_ROYALTY_FEE);

        (OrderStructs.Maker memory makerBid, OrderStructs.Taker memory takerAsk) = _createMockMakerBidAndTakerAsk(
            address(mockERC721),
            address(weth)
        );
        makerBid.price = price;

        bytes memory signature = _signMakerOrder(makerBid, makerUserPK);

        // Verify maker bid order
        _assertValidMakerOrder(makerBid, signature);

        // Mint asset
        mockERC721.mint(takerUser, makerBid.itemIds[0]);

        // Arrays for events
        uint256[3] memory expectedFees = _calculateExpectedFees({price: price, royaltyFeeBp: NEW_ROYALTY_FEE});
        address[2] memory expectedRecipients;

        expectedRecipients[0] = takerUser;
        expectedRecipients[1] = _royaltyRecipient;

        // Execute taker ask transaction
        vm.prank(takerUser);

        vm.expectEmit({checkTopic1: true, checkTopic2: false, checkTopic3: false, checkData: true});

        emit TakerAsk(
            NonceInvalidationParameters({
                orderHash: _computeOrderHash(makerBid),
                orderNonce: makerBid.orderNonce,
                isNonceInvalidated: true
            }),
            takerUser,
            makerUser,
            makerBid.strategyId,
            makerBid.currency,
            makerBid.collection,
            makerBid.itemIds,
            makerBid.amounts,
            expectedRecipients,
            expectedFees
        );

        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);

        _assertSuccessfulExecutionThroughWETH(makerUser, takerUser, price, expectedFees);
        // Verify the nonce is marked as executed
        assertEq(looksRareProtocol.userOrderNonce(makerUser, makerBid.orderNonce), MAGIC_VALUE_ORDER_NONCE_EXECUTED);
    }

    /**
     * One ERC721 is sold through a taker ask using WETH. Address zero is specified as the recipient in the taker struct.
     */
    function testTakerAskERC721WithAddressZeroSpecifiedAsRecipient(uint256 price) public {
        vm.assume(price <= 2 ether);
        _setUpUsers();

        (OrderStructs.Maker memory makerBid, OrderStructs.Taker memory takerAsk) = _createMockMakerBidAndTakerAsk(
            address(mockERC721),
            address(weth)
        );
        makerBid.price = price;

        bytes memory signature = _signMakerOrder(makerBid, makerUserPK);

        // Verify maker bid order
        _assertValidMakerOrder(makerBid, signature);

        // Adjustment
        takerAsk.recipient = address(0);

        // Mint asset
        mockERC721.mint(takerUser, makerBid.itemIds[0]);

        // Arrays for events
        uint256[3] memory expectedFees = _calculateExpectedFees({price: price, royaltyFeeBp: 0});
        address[2] memory expectedRecipients;

        expectedRecipients[0] = takerUser;
        expectedRecipients[1] = address(0); // No royalties

        // Execute taker ask transaction
        vm.prank(takerUser);
        vm.expectEmit({checkTopic1: true, checkTopic2: false, checkTopic3: false, checkData: true});

        emit TakerAsk(
            NonceInvalidationParameters({
                orderHash: _computeOrderHash(makerBid),
                orderNonce: makerBid.orderNonce,
                isNonceInvalidated: true
            }),
            takerUser,
            makerUser,
            makerBid.strategyId,
            makerBid.currency,
            makerBid.collection,
            makerBid.itemIds,
            makerBid.amounts,
            expectedRecipients,
            expectedFees
        );

        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);

        _assertSuccessfulExecutionThroughWETH(makerUser, takerUser, price, expectedFees);
    }

    /**
     * Three ERC721 are sold through 3 taker bids in one transaction with non-atomicity.
     */
    function testThreeTakerBidsERC721() public {
        uint256 price = 0.015 ether;
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
    function testThreeTakerBidsERC721OneFails() public {
        _setUpUsers();

        uint256 price = 1.4 ether;
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

    function testThreeTakerBidsERC721LengthsInvalid() public {
        _setUpUsers();

        BatchExecutionParameters[] memory batchExecutionParameters = new BatchExecutionParameters[](0);
        vm.expectRevert(LengthsInvalid.selector);
        vm.prank(takerUser);
        looksRareProtocol.executeMultipleTakerBids(batchExecutionParameters, _EMPTY_AFFILIATE, false);
    }

    /**
     * Three ERC721 are sold through 3 taker asks in one transaction with non-atomicity.
     */
    function testThreeTakerAsksERC721() public {
        uint256 price = 0.015 ether;
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

    /**
     * Transaction cannot go through if atomic, goes through if non-atomic (fund returns to buyer).
     */
    function testThreeTakerAsksERC721OneFails() public {
        _setUpUsers();

        uint256 numberOfPurchases = 3;
        uint256 faultyTokenId = numberOfPurchases - 1;
        uint256 price = 1.4 ether;

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

    function _calculateExpectedFees(
        uint256 price,
        uint256 royaltyFeeBp
    ) private pure returns (uint256[3] memory expectedFees) {
        expectedFees[2] = (price * _standardProtocolFeeBp) / ONE_HUNDRED_PERCENT_IN_BP;
        expectedFees[1] = (price * royaltyFeeBp) / ONE_HUNDRED_PERCENT_IN_BP;
        if (expectedFees[2] + expectedFees[1] < ((price * _minTotalFeeBp) / ONE_HUNDRED_PERCENT_IN_BP)) {
            expectedFees[2] = ((price * _minTotalFeeBp) / ONE_HUNDRED_PERCENT_IN_BP) - expectedFees[1];
        }
        expectedFees[0] = price - (expectedFees[1] + expectedFees[2]);
    }

    function _assertSuccessfulExecutionThroughWETH(
        address buyer,
        address seller,
        uint256 price,
        uint256[3] memory expectedFees
    ) private {
        // Buyer has received the asset
        assertEq(mockERC721.ownerOf(itemId), buyer);
        _assertBuyerPaidWETH(buyer, price);
        // Seller receives 99.5% of the whole price
        assertEq(weth.balanceOf(seller), _initialWETHBalanceUser + expectedFees[0]);
        // Owner receives 1.5% of the whole price
        assertEq(weth.balanceOf(_owner), _initialWETHBalanceOwner + expectedFees[2]);
        // Royalty recipient receives 0.5% of the whole price
        assertEq(weth.balanceOf(_royaltyRecipient), _initialWETHBalanceRoyaltyRecipient + expectedFees[1]);
    }

    function _assertSuccessfulExecutionThroughETH(
        address buyer,
        address seller,
        uint256 price,
        uint256[3] memory expectedFees
    ) private {
        assertEq(mockERC721.ownerOf(itemId), buyer);
        _assertBuyerPaidETH(buyer, price);
        // Seller receives 99.5% of the whole price
        assertEq(seller.balance, _initialETHBalanceUser + expectedFees[0]);
        // Royalty recipient receives 0.5% of the whole price
        assertEq(_royaltyRecipient.balance, _initialETHBalanceRoyaltyRecipient + expectedFees[1]);
    }
}
