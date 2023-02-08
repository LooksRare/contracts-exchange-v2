// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Libraries, interfaces, errors
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";
import {LengthsInvalid} from "../../contracts/errors/SharedErrors.sol";

// Base test
import {ProtocolBase} from "./ProtocolBase.t.sol";

// Constants
import {ONE_HUNDRED_PERCENT_IN_BP, ASSET_TYPE_ERC721} from "../../contracts/constants/NumericConstants.sol";

contract StandardTransactionsTest is ProtocolBase {
    error ERC721TransferFromFail();

    uint256 private constant itemId = 42;

    function setUp() public {
        _setUp();
    }

    /**
     * One ERC721 (where royalties come from the registry) is sold through a taker bid
     */
    function testTakerBidERC721WithRoyaltiesFromRegistry(uint256 price) public {
        vm.assume(price <= 2 ether);
        _setUpUsers();
        _setupRegistryRoyalties(address(mockERC721), _standardRoyaltyFee);

        // Mint asset
        mockERC721.mint(makerUser, itemId);

        // Prepare the orders and signature
        (
            OrderStructs.Maker memory makerAsk,
            OrderStructs.Taker memory takerBid,
            bytes memory signature
        ) = _createSingleItemMakerAskAndTakerBidOrderAndSignature({
                askNonce: 0,
                subsetNonce: 0,
                strategyId: STANDARD_SALE_FOR_FIXED_PRICE_STRATEGY,
                assetType: ASSET_TYPE_ERC721,
                orderNonce: 0,
                collection: address(mockERC721),
                currency: ETH,
                signer: makerUser,
                minPrice: price,
                itemId: itemId
            });

        // Verify validity of maker ask order
        _assertValidMakerAskOrder(makerAsk, signature);

        // Arrays for events
        uint256[3] memory expectedFees = _calculateExpectedFees({price: price, royaltyFeeBp: _standardRoyaltyFee});
        address[2] memory expectedRecipients;

        expectedRecipients[0] = makerUser;
        expectedRecipients[1] = _royaltyRecipient;

        // Execute taker bid transaction
        vm.prank(takerUser);
        vm.expectEmit({checkTopic1: true, checkTopic2: false, checkTopic3: false, checkData: true});

        emit TakerBid(
            SignatureParameters({
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

        // Mint asset
        mockERC721.mint(makerUser, itemId);

        // Prepare the orders and signature
        (
            OrderStructs.Maker memory makerAsk,
            OrderStructs.Taker memory takerBid,
            bytes memory signature
        ) = _createSingleItemMakerAskAndTakerBidOrderAndSignature({
                askNonce: 0,
                subsetNonce: 0,
                strategyId: STANDARD_SALE_FOR_FIXED_PRICE_STRATEGY,
                assetType: ASSET_TYPE_ERC721,
                orderNonce: 0,
                collection: address(mockERC721),
                currency: ETH,
                signer: makerUser,
                minPrice: price,
                itemId: itemId
            });

        // Adjustment
        takerBid.recipient = address(0);

        // Verify validity of maker ask order
        _assertValidMakerAskOrder(makerAsk, signature);

        // Arrays for events
        uint256[3] memory expectedFees = _calculateExpectedFees({price: price, royaltyFeeBp: 0});
        address[2] memory expectedRecipients;

        expectedRecipients[0] = makerUser;
        expectedRecipients[1] = address(0); // No royalties

        // Execute taker bid transaction
        vm.prank(takerUser);
        vm.expectEmit({checkTopic1: true, checkTopic2: false, checkTopic3: false, checkData: true});

        emit TakerBid(
            SignatureParameters({
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
        _setupRegistryRoyalties(address(mockERC721), _standardRoyaltyFee);

        (
            OrderStructs.Maker memory makerBid,
            OrderStructs.Taker memory takerAsk,
            bytes memory signature
        ) = _createSingleItemMakerBidAndTakerAskOrderAndSignature({
                bidNonce: 0,
                subsetNonce: 0,
                strategyId: STANDARD_SALE_FOR_FIXED_PRICE_STRATEGY,
                assetType: ASSET_TYPE_ERC721,
                orderNonce: 0,
                collection: address(mockERC721),
                currency: address(weth),
                signer: makerUser,
                maxPrice: price,
                itemId: itemId
            });

        // Verify maker bid order
        _assertValidMakerBidOrder(makerBid, signature);

        // Mint asset
        mockERC721.mint(takerUser, itemId);

        // Arrays for events
        uint256[3] memory expectedFees = _calculateExpectedFees({price: price, royaltyFeeBp: _standardRoyaltyFee});
        address[2] memory expectedRecipients;

        expectedRecipients[0] = takerUser;
        expectedRecipients[1] = _royaltyRecipient;

        // Execute taker ask transaction
        vm.prank(takerUser);

        vm.expectEmit({checkTopic1: true, checkTopic2: false, checkTopic3: false, checkData: true});

        emit TakerAsk(
            SignatureParameters({
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

        (
            OrderStructs.Maker memory makerBid,
            OrderStructs.Taker memory takerAsk,
            bytes memory signature
        ) = _createSingleItemMakerBidAndTakerAskOrderAndSignature({
                bidNonce: 0,
                subsetNonce: 0,
                strategyId: STANDARD_SALE_FOR_FIXED_PRICE_STRATEGY,
                assetType: ASSET_TYPE_ERC721,
                orderNonce: 0,
                collection: address(mockERC721),
                currency: address(weth),
                signer: makerUser,
                maxPrice: price,
                itemId: itemId
            });

        // Verify maker bid order
        _assertValidMakerBidOrder(makerBid, signature);

        // Adjustment
        takerAsk.recipient = address(0);

        // Mint asset
        mockERC721.mint(takerUser, itemId);

        // Arrays for events
        uint256[3] memory expectedFees = _calculateExpectedFees({price: price, royaltyFeeBp: 0});
        address[2] memory expectedRecipients;

        expectedRecipients[0] = takerUser;
        expectedRecipients[1] = address(0); // No royalties

        // Execute taker ask transaction
        vm.prank(takerUser);
        vm.expectEmit({checkTopic1: true, checkTopic2: false, checkTopic3: false, checkData: true});

        emit TakerAsk(
            SignatureParameters({
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

        uint256 numberPurchases = 3;

        OrderStructs.Maker[] memory makerAsks = new OrderStructs.Maker[](numberPurchases);
        OrderStructs.Taker[] memory takerBids = new OrderStructs.Taker[](numberPurchases);
        bytes[] memory signatures = new bytes[](numberPurchases);

        for (uint256 i; i < numberPurchases; i++) {
            // Mint asset
            mockERC721.mint(makerUser, i);

            // Prepare the order hash
            makerAsks[i] = _createSingleItemMakerAskOrder({
                askNonce: 0,
                subsetNonce: 0,
                strategyId: STANDARD_SALE_FOR_FIXED_PRICE_STRATEGY,
                assetType: ASSET_TYPE_ERC721,
                orderNonce: i,
                collection: address(mockERC721),
                currency: ETH,
                signer: makerUser,
                minPrice: price, // Fixed
                itemId: i // (0, 1, etc.)
            });

            // Sign order
            signatures[i] = _signMakerOrder(makerAsks[i], makerUserPK);

            takerBids[i] = OrderStructs.Taker(takerUser, abi.encode());
        }

        // Other execution parameters
        OrderStructs.MerkleTree[] memory merkleTrees = new OrderStructs.MerkleTree[](numberPurchases);

        // Execute taker bid transaction
        vm.prank(takerUser);
        looksRareProtocol.executeMultipleTakerBids{value: price * numberPurchases}(
            takerBids,
            makerAsks,
            signatures,
            merkleTrees,
            _EMPTY_AFFILIATE,
            false
        );

        for (uint256 i; i < numberPurchases; i++) {
            // Taker user has received the asset
            assertEq(mockERC721.ownerOf(i), takerUser);
            // Verify the nonce is marked as executed
            assertEq(looksRareProtocol.userOrderNonce(makerUser, i), MAGIC_VALUE_ORDER_NONCE_EXECUTED);
        }

        // Taker bid user pays the whole price
        assertEq(address(takerUser).balance, _initialETHBalanceUser - (numberPurchases * price));
        // Maker ask user receives 98% of the whole price (2% protocol)
        assertEq(
            address(makerUser).balance,
            _initialETHBalanceUser + ((price * 9_800) * numberPurchases) / ONE_HUNDRED_PERCENT_IN_BP
        );
        // No leftover in the balance of the contract
        assertEq(address(looksRareProtocol).balance, 0);
    }

    /**
     * Transaction cannot go through if atomic, goes through if non-atomic (fund returns to buyer).
     */
    function testThreeTakerBidsERC721OneFails() public {
        uint256 price = 1.4 ether;

        _setUpUsers();

        uint256 numberPurchases = 3;
        uint256 faultyTokenId = numberPurchases - 1;

        OrderStructs.Maker[] memory makerAsks = new OrderStructs.Maker[](numberPurchases);
        OrderStructs.Taker[] memory takerBids = new OrderStructs.Taker[](numberPurchases);
        bytes[] memory signatures = new bytes[](numberPurchases);

        for (uint256 i; i < numberPurchases; i++) {
            // Mint asset
            mockERC721.mint(makerUser, i);

            // Prepare the order hash
            makerAsks[i] = _createSingleItemMakerAskOrder({
                askNonce: 0,
                subsetNonce: 0,
                strategyId: STANDARD_SALE_FOR_FIXED_PRICE_STRATEGY,
                assetType: ASSET_TYPE_ERC721,
                orderNonce: i,
                collection: address(mockERC721),
                currency: ETH,
                signer: makerUser,
                minPrice: price, // Fixed
                itemId: i // (0, 1, etc.)
            });

            // Sign order
            signatures[i] = _signMakerOrder(makerAsks[i], makerUserPK);

            takerBids[i] = OrderStructs.Taker(takerUser, abi.encode());
        }

        // Transfer tokenId = 2 to random user
        address randomUser = address(55);
        vm.prank(makerUser);
        mockERC721.transferFrom(makerUser, randomUser, faultyTokenId);

        /**
         * 1. The whole purchase fails if execution is atomic
         */
        {
            // Other execution parameters
            OrderStructs.MerkleTree[] memory merkleTrees = new OrderStructs.MerkleTree[](numberPurchases);

            vm.expectRevert(abi.encodeWithSelector(ERC721TransferFromFail.selector));
            vm.prank(takerUser);
            looksRareProtocol.executeMultipleTakerBids{value: price * numberPurchases}(
                takerBids,
                makerAsks,
                signatures,
                merkleTrees,
                _EMPTY_AFFILIATE,
                true
            );
        }

        /**
         * 2. The whole purchase doesn't fail if execution is not-atomic
         */
        {
            // Other execution parameters
            OrderStructs.MerkleTree[] memory merkleTrees = new OrderStructs.MerkleTree[](numberPurchases);

            vm.prank(takerUser);
            // Execute taker bid transaction
            looksRareProtocol.executeMultipleTakerBids{value: price * numberPurchases}(
                takerBids,
                makerAsks,
                signatures,
                merkleTrees,
                _EMPTY_AFFILIATE,
                false
            );
        }

        for (uint256 i; i < faultyTokenId; i++) {
            // Taker user has received the first two assets
            assertEq(mockERC721.ownerOf(i), takerUser);
            // Verify the first two nonces are marked as executed
            assertEq(looksRareProtocol.userOrderNonce(makerUser, i), MAGIC_VALUE_ORDER_NONCE_EXECUTED);
        }

        // Taker user has not received the asset
        assertEq(mockERC721.ownerOf(faultyTokenId), randomUser);
        // Verify the nonce is NOT marked as executed
        assertEq(looksRareProtocol.userOrderNonce(makerUser, faultyTokenId), bytes32(0));
        // Taker bid user pays the whole price
        assertEq(address(takerUser).balance, _initialETHBalanceUser - 1 - ((numberPurchases - 1) * price));
        // Maker ask user receives 98% of the whole price (2% protocol)
        assertEq(
            address(makerUser).balance,
            _initialETHBalanceUser + ((price * 9_800) * (numberPurchases - 1)) / ONE_HUNDRED_PERCENT_IN_BP
        );
        // 1 wei left in the balance of the contract
        assertEq(address(looksRareProtocol).balance, 1);
    }

    function testThreeTakerBidsERC721LengthsInvalid() public {
        _setUpUsers();

        uint256 price = 1.12121111111 ether;
        uint256 numberPurchases = 3;

        OrderStructs.Taker[] memory takerBids = new OrderStructs.Taker[](numberPurchases);
        bytes[] memory signatures = new bytes[](numberPurchases);
        OrderStructs.MerkleTree[] memory merkleTrees = new OrderStructs.MerkleTree[](numberPurchases);

        // 1. Invalid maker asks length
        OrderStructs.Maker[] memory makerAsks = new OrderStructs.Maker[](numberPurchases - 1);

        vm.expectRevert(LengthsInvalid.selector);
        vm.prank(takerUser);
        looksRareProtocol.executeMultipleTakerBids{value: price * numberPurchases}(
            takerBids,
            makerAsks,
            signatures,
            merkleTrees,
            _EMPTY_AFFILIATE,
            false
        );

        // 2. Invalid signatures length
        makerAsks = new OrderStructs.Maker[](numberPurchases);
        signatures = new bytes[](numberPurchases - 1);

        vm.expectRevert(LengthsInvalid.selector);
        vm.prank(takerUser);
        looksRareProtocol.executeMultipleTakerBids{value: price * numberPurchases}(
            takerBids,
            makerAsks,
            signatures,
            merkleTrees,
            _EMPTY_AFFILIATE,
            false
        );

        // 3. Invalid merkle trees length
        signatures = new bytes[](numberPurchases);
        merkleTrees = new OrderStructs.MerkleTree[](numberPurchases - 1);

        vm.expectRevert(LengthsInvalid.selector);
        vm.prank(takerUser);
        looksRareProtocol.executeMultipleTakerBids{value: price * numberPurchases}(
            takerBids,
            makerAsks,
            signatures,
            merkleTrees,
            _EMPTY_AFFILIATE,
            false
        );
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
        // Buyer pays the whole price
        assertEq(weth.balanceOf(buyer), _initialWETHBalanceUser - price);
        // Seller receives 98% of the whole price
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
        // Buyer pays the whole price
        assertEq(address(buyer).balance, _initialETHBalanceUser - price);
        // Seller receives 98% of the whole price (2%)
        assertEq(address(seller).balance, _initialETHBalanceUser + expectedFees[0]);
        // Royalty recipient receives 0.5% of the whole price
        assertEq(address(_royaltyRecipient).balance, _initialETHBalanceRoyaltyRecipient + expectedFees[1]);
    }
}
