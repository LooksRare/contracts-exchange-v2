// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Libraries and interfaces
import {ITransferSelectorNFT} from "../../contracts/interfaces/ITransferSelectorNFT.sol";
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";

// Base test
import {ProtocolBase} from "./ProtocolBase.t.sol";

contract StandardTransactionsTest is ProtocolBase {
    /**
     * One ERC721 (where royalties come from the registry) is sold through a taker bid
     */
    function testTakerBidERC721WithRoyaltiesFromRegistry() public {
        _setUpUsers();
        _setupRegistryRoyalties(address(mockERC721), _standardRoyaltyFee);

        price = 1 ether; // Fixed price of sale
        uint256 itemId = 0; // TokenId

        {
            // Mint asset
            mockERC721.mint(makerUser, itemId);

            // Prepare the order hash
            makerAsk = _createSingleItemMakerAskOrder({
                askNonce: 0,
                subsetNonce: 0,
                strategyId: 0, // Standard sale for fixed price
                assetType: 0, // ERC721,
                orderNonce: 0,
                collection: address(mockERC721),
                currency: address(0), // ETH,
                signer: makerUser,
                minPrice: price,
                itemId: itemId
            });

            // Sign order
            signature = _signMakerAsk(makerAsk, makerUserPK);
        }

        // Taker user actions
        vm.startPrank(takerUser);

        {
            // Prepare the taker bid
            takerBid = OrderStructs.TakerBid(
                takerUser,
                makerAsk.minPrice,
                makerAsk.itemIds,
                makerAsk.amounts,
                abi.encode()
            );
        }

        {
            uint256 gasLeft = gasleft();

            // Execute taker bid transaction
            looksRareProtocol.executeTakerBid{value: price}(
                takerBid,
                makerAsk,
                signature,
                _emptyMerkleTree,
                _emptyAffiliate
            );
            emit log_named_uint("TakerBid // ERC721 // Protocol Fee // Registry Royalties", gasLeft - gasleft());
        }

        vm.stopPrank();

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(itemId), takerUser);
        // Taker bid user pays the whole price
        assertEq(address(takerUser).balance, _initialETHBalanceUser - price);
        // Maker ask user receives 98% of the whole price (2%)
        assertEq(address(makerUser).balance, _initialETHBalanceUser + (price * 9_800) / 10_000);
        // Royalty recipient receives 0.5% of the whole price
        assertEq(
            address(_royaltyRecipient).balance,
            _initialETHBalanceRoyaltyRecipient + (price * _standardRoyaltyFee) / 10_000
        );
        // No leftover in the balance of the contract
        assertEq(address(looksRareProtocol).balance, 0);
        // Verify the nonce is marked as executed
        assertEq(looksRareProtocol.userOrderNonce(makerUser, makerAsk.orderNonce), MAGIC_VALUE_NONCE_EXECUTED);
    }

    /**
     * One ERC721 (where royalties come from the registry) is sold through a taker ask using WETH
     */
    function testTakerAskERC721WithRoyaltiesFromRegistry() public {
        _setUpUsers();
        _setupRegistryRoyalties(address(mockERC721), _standardRoyaltyFee);

        price = 1 ether; // Fixed price of sale
        uint256 itemId = 0; // TokenId

        {
            // Prepare the order hash
            makerBid = _createSingleItemMakerBidOrder(
                0, // askNonce
                0, // subsetNonce
                0, // strategyId (Standard sale for fixed price)
                0, // assetType ERC721,
                0, // orderNonce
                address(mockERC721),
                address(weth),
                makerUser,
                price,
                itemId
            );

            // Sign order
            signature = _signMakerBid(makerBid, makerUserPK);
        }

        // Taker user actions
        vm.startPrank(takerUser);

        {
            // Mint asset
            mockERC721.mint(takerUser, itemId);

            // Prepare the taker ask
            takerAsk = OrderStructs.TakerAsk(
                takerUser,
                makerBid.maxPrice,
                makerBid.itemIds,
                makerBid.amounts,
                abi.encode()
            );
        }

        {
            uint256 gasLeft = gasleft();

            // Execute taker ask transaction
            looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _emptyMerkleTree, _emptyAffiliate);
            emit log_named_uint("TakerAsk // ERC721 // Protocol Fee // Registry Royalties", gasLeft - gasleft());
        }

        vm.stopPrank();

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(itemId), makerUser);
        // Maker bid user pays the whole price
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser - price);
        // Taker ask user receives 98% of the whole price
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser + (price * 9_800) / 10_000);
        // Royalty recipient receives 0.5% of the whole price
        assertEq(
            weth.balanceOf(_royaltyRecipient),
            _initialWETHBalanceRoyaltyRecipient + (price * _standardRoyaltyFee) / 10_000
        );
        // Verify the nonce is marked as executed
        assertEq(looksRareProtocol.userOrderNonce(makerUser, makerBid.orderNonce), MAGIC_VALUE_NONCE_EXECUTED);
    }

    /**
     * Three ERC721 are sold through 3 taker bids in one transaction with non-atomicity.
     */
    function testThreeTakerBidsERC721() public {
        _setUpUsers();

        uint256 numberPurchases = 3;
        price = 1 ether;

        OrderStructs.MakerAsk[] memory makerAsks = new OrderStructs.MakerAsk[](numberPurchases);
        OrderStructs.TakerBid[] memory takerBids = new OrderStructs.TakerBid[](numberPurchases);
        bytes[] memory signatures = new bytes[](numberPurchases);

        for (uint256 i; i < numberPurchases; i++) {
            // Mint asset
            mockERC721.mint(makerUser, i);

            // Prepare the order hash
            makerAsks[i] = _createSingleItemMakerAskOrder({
                askNonce: 0,
                subsetNonce: 0,
                strategyId: 0, // Standard sale for fixed price
                assetType: 0, // ERC721,
                orderNonce: i,
                collection: address(mockERC721),
                currency: address(0), // ETH,
                signer: makerUser,
                minPrice: price, // Fixed
                itemId: i // (0, 1, etc.)
            });

            // Sign order
            signatures[i] = _signMakerAsk(makerAsks[i], makerUserPK);

            takerBids[i] = OrderStructs.TakerBid(
                takerUser,
                makerAsks[i].minPrice,
                makerAsks[i].itemIds,
                makerAsks[i].amounts,
                abi.encode()
            );
        }

        // Taker user actions
        vm.startPrank(takerUser);

        {
            // Other execution parameters
            OrderStructs.MerkleTree[] memory merkleTrees = new OrderStructs.MerkleTree[](numberPurchases);

            uint256 gasLeft = gasleft();

            // Execute taker bid transaction
            looksRareProtocol.executeMultipleTakerBids{value: price * numberPurchases}(
                takerBids,
                makerAsks,
                signatures,
                merkleTrees,
                _emptyAffiliate,
                false
            );
            emit log_named_uint(
                "TakerBid (3 items) // Non-atomic // ERC721 // Protocol Fee // No Royalties",
                gasLeft - gasleft()
            );
        }

        vm.stopPrank();

        for (uint256 i; i < numberPurchases; i++) {
            // Taker user has received the asset
            assertEq(mockERC721.ownerOf(i), takerUser);
            // Verify the nonce is marked as executed
            assertEq(looksRareProtocol.userOrderNonce(makerUser, i), MAGIC_VALUE_NONCE_EXECUTED);
        }
        // Taker bid user pays the whole price
        assertEq(address(takerUser).balance, _initialETHBalanceUser - (numberPurchases * price));
        // Maker ask user receives 98% of the whole price (2% protocol)
        assertEq(address(makerUser).balance, _initialETHBalanceUser + ((price * 9_800) * numberPurchases) / 10_000);
        // No leftover in the balance of the contract
        assertEq(address(looksRareProtocol).balance, 0);
    }

    /**
     * Transaction cannot go through if atomic, goes through if non-atomic (fund returns to buyer).
     */
    function testThreeTakerBidsERC721OneFails() public {
        _setUpUsers();

        uint256 numberPurchases = 3;
        price = 1 ether;
        uint256 faultyTokenId = numberPurchases - 1;

        OrderStructs.MakerAsk[] memory makerAsks = new OrderStructs.MakerAsk[](numberPurchases);
        OrderStructs.TakerBid[] memory takerBids = new OrderStructs.TakerBid[](numberPurchases);
        bytes[] memory signatures = new bytes[](numberPurchases);

        for (uint256 i; i < numberPurchases; i++) {
            // Mint asset
            mockERC721.mint(makerUser, i);

            // Prepare the order hash
            makerAsks[i] = _createSingleItemMakerAskOrder({
                askNonce: 0,
                subsetNonce: 0,
                strategyId: 0, // Standard sale for fixed price
                assetType: 0, // ERC721,
                orderNonce: i,
                collection: address(mockERC721),
                currency: address(0), // ETH,
                signer: makerUser,
                minPrice: price, // Fixed
                itemId: i // (0, 1, etc.)
            });

            // Sign order
            signatures[i] = _signMakerAsk(makerAsks[i], makerUserPK);

            takerBids[i] = OrderStructs.TakerBid(
                takerUser,
                makerAsks[i].minPrice,
                makerAsks[i].itemIds,
                makerAsks[i].amounts,
                abi.encode()
            );
        }

        // Transfer tokenId=2 to random user
        address randomUser = address(55);
        vm.prank(makerUser);
        mockERC721.transferFrom(makerUser, randomUser, faultyTokenId);

        // Taker user actions
        vm.startPrank(takerUser);

        /**
         * 1. The whole purchase fails if execution is atomic
         */
        {
            // Other execution parameters
            OrderStructs.MerkleTree[] memory merkleTrees = new OrderStructs.MerkleTree[](numberPurchases);

            // NFTTransferFail(address collection, uint8 assetType);
            vm.expectRevert(
                abi.encodeWithSelector(
                    ITransferSelectorNFT.NFTTransferFail.selector,
                    makerAsks[faultyTokenId].collection,
                    uint8(0)
                )
            );
            looksRareProtocol.executeMultipleTakerBids{value: price * numberPurchases}(
                takerBids,
                makerAsks,
                signatures,
                merkleTrees,
                _emptyAffiliate,
                true
            );
        }

        /**
         * 2. The whole purchase doesn't fail if execution is not-atomic
         */
        {
            // Other execution parameters
            OrderStructs.MerkleTree[] memory merkleTrees = new OrderStructs.MerkleTree[](numberPurchases);

            // Execute taker bid transaction
            looksRareProtocol.executeMultipleTakerBids{value: price * numberPurchases}(
                takerBids,
                makerAsks,
                signatures,
                merkleTrees,
                _emptyAffiliate,
                false
            );
        }

        vm.stopPrank();

        for (uint256 i; i < faultyTokenId; i++) {
            // Taker user has received the first two assets
            assertEq(mockERC721.ownerOf(i), takerUser);
            // Verify the first two nonces are marked as executed
            assertEq(looksRareProtocol.userOrderNonce(makerUser, i), MAGIC_VALUE_NONCE_EXECUTED);
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
            _initialETHBalanceUser + ((price * 9_800) * (numberPurchases - 1)) / 10_000
        );
        // 1 wei left in the balance of the contract
        assertEq(address(looksRareProtocol).balance, 1);
    }
}
