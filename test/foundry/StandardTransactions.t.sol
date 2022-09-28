// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";
import {ProtocolBase} from "./ProtocolBase.t.sol";

contract StandardTransactionsTest is ProtocolBase {
    /**
     * One ERC721 (where royalties come from the registry) is sold through a taker bid
     */
    function testTakerBidERC721WithRoyaltiesFromRegistry() public {
        _setUpUsers();
        _setUpRoyalties(address(mockERC721), _standardRoyaltyFee);

        price = 1 ether; // Fixed price of sale
        uint256 itemId = 0; // TokenId
        uint16 minNetRatio = 10000 - (_standardRoyaltyFee + _standardProtocolFee);

        {
            // Mint asset
            mockERC721.mint(makerUser, itemId);

            // Prepare the order hash
            makerAsk = _createSingleItemMakerAskOrder(
                0, // askNonce
                0, // subsetNonce
                0, // strategyId (Standard sale for fixed price)
                0, // assetType ERC721,
                0, // orderNonce
                minNetRatio,
                address(mockERC721),
                address(0), // ETH,
                makerUser,
                price,
                itemId
            );

            // Sign order
            signature = _signMakerAsk(makerAsk, makerUserPK);
        }

        // Taker user actions
        vm.startPrank(takerUser);

        {
            // Prepare the taker bid
            takerBid = OrderStructs.TakerBid(
                takerUser,
                makerAsk.minNetRatio,
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
                _emptyMerkleRoot,
                _emptyMerkleProof,
                _emptyReferrer
            );
            emit log_named_uint("TakerBid // ERC721 // Protocol Fee // Registry Royalties", gasLeft - gasleft());
        }

        vm.stopPrank();

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(itemId), takerUser);
        // Taker bid user pays the whole price
        assertEq(address(takerUser).balance, _initialETHBalanceUser - price);
        // Maker ask user receives 97% of the whole price (2% protocol + 1% royalties)
        assertEq(address(makerUser).balance, _initialETHBalanceUser + (price * minNetRatio) / 10000);
        // No leftover in the balance of the contract
        assertEq(address(looksRareProtocol).balance, 0);
        // Verify the nonce is marked as executed
        assertTrue(looksRareProtocol.viewUserOrderNonce(makerUser, makerAsk.orderNonce));
    }

    /**
     * One ERC721 (where royalties come from the registry) is sold through a taker ask using WETH
     */
    function testTakerAskERC721WithRoyaltiesFromRegistry() public {
        _setUpUsers();
        _setUpRoyalties(address(mockERC721), _standardRoyaltyFee);

        price = 1 ether; // Fixed price of sale
        uint256 itemId = 0; // TokenId
        uint16 minNetRatio = 10000 - (_standardRoyaltyFee + _standardProtocolFee);

        {
            // Prepare the order hash
            makerBid = _createSingleItemMakerBidOrder(
                0, // askNonce
                0, // subsetNonce
                0, // strategyId (Standard sale for fixed price)
                0, // assetType ERC721,
                0, // orderNonce
                minNetRatio,
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
                makerBid.minNetRatio,
                makerBid.maxPrice,
                makerBid.itemIds,
                makerBid.amounts,
                abi.encode()
            );
        }

        {
            uint256 gasLeft = gasleft();

            // Execute taker ask transaction
            looksRareProtocol.executeTakerAsk(
                takerAsk,
                makerBid,
                signature,
                _emptyMerkleRoot,
                _emptyMerkleProof,
                _emptyReferrer
            );
            emit log_named_uint("TakerAsk // ERC721 // Protocol Fee // Registry Royalties", gasLeft - gasleft());
        }

        vm.stopPrank();

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(itemId), makerUser);
        // Maker bid user pays the whole price
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser - price);
        // Taker ask user receives 97% of the whole price (2% protocol + 1% royalties)
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser + (price * minNetRatio) / 10000);
        // Verify the nonce is marked as executed
        assertTrue(looksRareProtocol.viewUserOrderNonce(makerUser, makerBid.orderNonce));
    }

    /**
     * TakerAsk matches makerBid but protocol fee was discontinued for this strategy.
     */
    function testTakerAskERC721WithoutProtocolFeeNorRoyalty() public {
        _setUpUsers();

        // Remove protocol fee for ERC721
        vm.startPrank(_owner);
        looksRareProtocol.updateCollectionDiscountController(_owner);
        looksRareProtocol.updateCollectionDiscountFactor(address(mockERC721), 10000);
        vm.stopPrank();

        price = 1 ether; // Fixed price of sale
        uint256 itemId = 0; // TokenId
        uint16 minNetRatio = 10000; // 0% slippage protection

        {
            // Prepare the order hash
            makerBid = _createSingleItemMakerBidOrder(
                0, // askNonce
                0, // subsetNonce
                0, // strategyId (Standard sale for fixed price)
                0, // assetType ERC721,
                0, // orderNonce
                minNetRatio,
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
                makerBid.minNetRatio,
                makerBid.maxPrice,
                makerBid.itemIds,
                makerBid.amounts,
                abi.encode()
            );
        }

        {
            uint256 gasLeft = gasleft();

            // Execute taker ask transaction
            looksRareProtocol.executeTakerAsk(
                takerAsk,
                makerBid,
                signature,
                _emptyMerkleRoot,
                _emptyMerkleProof,
                _emptyReferrer
            );
            emit log_named_uint("TakerAsk // ERC721 // No Protocol Fee // No Royalties", gasLeft - gasleft());
        }

        vm.stopPrank();

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(itemId), makerUser);
        // Maker bid user pays the whole price
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser - price);
        // Taker ask user receives 100% of whole price
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser + price);
        // Verify the nonce is marked as executed
        assertTrue(looksRareProtocol.viewUserOrderNonce(makerUser, makerBid.orderNonce));
    }

    /**
     * TakerBid matches makerAsk with EIP2981 token
     */
    function testTakerBidERC721WithEIP2981Royalties() public {
        _setUpUsers();

        price = 1 ether; // Fixed price of sale
        uint256 itemId = 0; // TokenId
        uint16 minNetRatio = 10000 - (_standardRoyaltyFee + _standardProtocolFee);

        {
            // Mint asset
            mockERC721WithRoyalties.mint(makerUser, itemId);

            // Prepare the order hash
            makerAsk = _createSingleItemMakerAskOrder(
                0, // askNonce
                0, // subsetNonce
                0, // strategyId (Standard sale for fixed price)
                0, // assetType ERC721,
                0, // orderNonce
                minNetRatio,
                address(mockERC721WithRoyalties),
                address(0), // ETH,
                makerUser,
                price,
                itemId
            );

            // Sign order
            signature = _signMakerAsk(makerAsk, makerUserPK);
        }

        // Taker user actions
        vm.startPrank(takerUser);

        {
            // Prepare the taker bid
            takerBid = OrderStructs.TakerBid(
                takerUser,
                makerAsk.minNetRatio,
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
                _emptyMerkleRoot,
                _emptyMerkleProof,
                _emptyReferrer
            );
            emit log_named_uint("TakerBid // ERC721 // Protocol Fee // EIP2981 Royalties", gasLeft - gasleft());
        }

        vm.stopPrank();

        // Taker user has received the asset
        assertEq(mockERC721WithRoyalties.ownerOf(itemId), takerUser);
        // Taker bid user pays the whole price
        assertEq(address(takerUser).balance, _initialETHBalanceUser - price);
        // Maker ask user receives 100% of whole price
        assertEq(
            address(makerUser).balance,
            _initialETHBalanceUser + (price * (10000 - _standardProtocolFee - _standardRoyaltyFee)) / 10000
        );
        // No leftover in the balance of the contract
        assertEq(address(looksRareProtocol).balance, 0);
        // Verify the nonce is marked as executed
        assertTrue(looksRareProtocol.viewUserOrderNonce(makerUser, makerAsk.orderNonce));
    }

    /**
     * One ERC721 (with EIP2981 royalties) is sold through a taker ask using WETH
     */
    function testTakerAskERC721WithEIP2981Royalties() public {
        _setUpUsers();

        price = 1 ether; // Fixed price of sale
        uint256 itemId = 0; // TokenId
        uint16 minNetRatio = 10000 - (_standardRoyaltyFee + _standardProtocolFee);

        {
            // Prepare the order hash
            makerBid = _createSingleItemMakerBidOrder(
                0, // askNonce
                0, // subsetNonce
                0, // strategyId (Standard sale for fixed price)
                0, // assetType ERC721,
                0, // orderNonce
                minNetRatio,
                address(mockERC721WithRoyalties),
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
            mockERC721WithRoyalties.mint(takerUser, itemId);

            // Prepare the taker ask
            takerAsk = OrderStructs.TakerAsk(
                takerUser,
                makerBid.minNetRatio,
                makerBid.maxPrice,
                makerBid.itemIds,
                makerBid.amounts,
                abi.encode()
            );
        }

        {
            uint256 gasLeft = gasleft();

            // Execute taker ask transaction
            looksRareProtocol.executeTakerAsk(
                takerAsk,
                makerBid,
                signature,
                _emptyMerkleRoot,
                _emptyMerkleProof,
                _emptyReferrer
            );
            emit log_named_uint("TakerAsk // ERC721 // Protocol Fee // EIP2981 Royalties", gasLeft - gasleft());
        }

        vm.stopPrank();

        // Taker user has received the asset
        assertEq(mockERC721WithRoyalties.ownerOf(itemId), makerUser);
        // Maker bid user pays the whole price
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser - price);
        // Taker ask user receives 97% of the whole price (2% protocol + 1% royalties)
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser + (price * minNetRatio) / 10000);
        // Verify the nonce is marked as executed
        assertTrue(looksRareProtocol.viewUserOrderNonce(makerUser, makerBid.orderNonce));
    }

    /**
     * TakerBid matches makerAsk but protocol fee was discontinued for this strategy using the discount function.
     */
    function testTakerBidERC721WithoutProtocolFeeNorRoyalty() public {
        _setUpUsers();

        // Remove protocol fee for ERC721
        vm.startPrank(_owner);
        looksRareProtocol.updateCollectionDiscountController(_owner);
        looksRareProtocol.updateCollectionDiscountFactor(address(mockERC721), 10000);
        vm.stopPrank();

        price = 1 ether; // Fixed price of sale
        uint256 itemId = 0; // TokenId
        uint16 minNetRatio = 10000;

        {
            // Mint asset
            mockERC721.mint(makerUser, itemId);

            // Prepare the order hash
            makerAsk = _createSingleItemMakerAskOrder(
                0, // askNonce
                0, // subsetNonce
                0, // strategyId (Standard sale for fixed price)
                0, // assetType ERC721,
                0, // orderNonce
                minNetRatio,
                address(mockERC721),
                address(0), // ETH,
                makerUser,
                price,
                itemId
            );

            // Sign order
            signature = _signMakerAsk(makerAsk, makerUserPK);
        }

        // Taker user actions
        vm.startPrank(takerUser);

        {
            // Prepare the taker bid
            takerBid = OrderStructs.TakerBid(
                takerUser,
                makerAsk.minNetRatio,
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
                _emptyMerkleRoot,
                _emptyMerkleProof,
                _emptyReferrer
            );
            emit log_named_uint("TakerBid // ERC721 // No Protocol Fee // No Royalties", gasLeft - gasleft());
        }

        vm.stopPrank();

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(itemId), takerUser);
        // Taker bid user pays the whole price
        assertEq(address(takerUser).balance, _initialETHBalanceUser - price);
        // Maker ask user receives 100% of whole price
        assertEq(address(makerUser).balance, _initialETHBalanceUser + price);
        // No leftover in the balance of the contract
        assertEq(address(looksRareProtocol).balance, 0);
        // Verify the nonce is marked as executed
        assertTrue(looksRareProtocol.viewUserOrderNonce(makerUser, makerAsk.orderNonce));
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
            makerAsks[i] = _createSingleItemMakerAskOrder(
                0, // askNonce
                0, // subsetNonce
                0, // strategyId (Standard sale for fixed price)
                0, // assetType ERC721,
                uint112(i), // orderNonce
                9800,
                address(mockERC721),
                address(0), // ETH,
                makerUser,
                price, // Fixed
                i // itemId (0, 1, etc.)
            );

            // Sign order
            signatures[i] = _signMakerAsk(makerAsks[i], makerUserPK);

            takerBids[i] = OrderStructs.TakerBid(
                takerUser,
                makerAsks[i].minNetRatio,
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
            OrderStructs.MerkleRoot[] memory merkleRoots = new OrderStructs.MerkleRoot[](numberPurchases);
            bytes32[][] memory merkleProofs = new bytes32[][](numberPurchases);

            uint256 gasLeft = gasleft();

            // Execute taker bid transaction
            looksRareProtocol.executeMultipleTakerBids{value: price * numberPurchases}(
                takerBids,
                makerAsks,
                signatures,
                merkleRoots,
                merkleProofs,
                _emptyReferrer,
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
            assertTrue(looksRareProtocol.viewUserOrderNonce(makerUser, uint112(i)));
        }
        // Taker bid user pays the whole price
        assertEq(address(takerUser).balance, _initialETHBalanceUser - (numberPurchases * price));
        // Maker ask user receives 98% of the whole price (2% protocol)
        assertEq(address(makerUser).balance, _initialETHBalanceUser + ((price * 9800) * numberPurchases) / 10000);
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
            makerAsks[i] = _createSingleItemMakerAskOrder(
                0, // askNonce
                0, // subsetNonce
                0, // strategyId (Standard sale for fixed price)
                0, // assetType ERC721,
                uint112(i), // orderNonce
                9800,
                address(mockERC721),
                address(0), // ETH,
                makerUser,
                price, // Fixed
                i // itemId (0, 1, etc.)
            );

            // Sign order
            signatures[i] = _signMakerAsk(makerAsks[i], makerUserPK);

            takerBids[i] = OrderStructs.TakerBid(
                takerUser,
                makerAsks[i].minNetRatio,
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
            OrderStructs.MerkleRoot[] memory merkleRoots = new OrderStructs.MerkleRoot[](numberPurchases);
            bytes32[][] memory merkleProofs = new bytes32[][](numberPurchases);

            // It is for ERC721TransferFromFail();
            vm.expectRevert(0xe0f5c508);
            looksRareProtocol.executeMultipleTakerBids{value: price * numberPurchases}(
                takerBids,
                makerAsks,
                signatures,
                merkleRoots,
                merkleProofs,
                _emptyReferrer,
                true
            );
        }

        /**
         * 2. The whole purchase doesn't fail if execution is not-atomic
         */
        {
            // Other execution parameters
            OrderStructs.MerkleRoot[] memory merkleRoots = new OrderStructs.MerkleRoot[](numberPurchases);
            bytes32[][] memory merkleProofs = new bytes32[][](numberPurchases);

            // Execute taker bid transaction
            looksRareProtocol.executeMultipleTakerBids{value: price * numberPurchases}(
                takerBids,
                makerAsks,
                signatures,
                merkleRoots,
                merkleProofs,
                _emptyReferrer,
                false
            );
        }

        vm.stopPrank();

        for (uint256 i; i < faultyTokenId; i++) {
            // Taker user has received the first two assets
            assertEq(mockERC721.ownerOf(i), takerUser);
            // Verify the first two nonces are marked as executed
            assertTrue(looksRareProtocol.viewUserOrderNonce(makerUser, uint112(i)));
        }

        // Taker user has not received the asset
        assertEq(mockERC721.ownerOf(faultyTokenId), randomUser);
        // Verify the nonce is NOT marked as executed
        assertFalse(looksRareProtocol.viewUserOrderNonce(makerUser, uint112(faultyTokenId)));
        // Taker bid user pays the whole price
        assertEq(address(takerUser).balance, _initialETHBalanceUser - ((numberPurchases - 1) * price));
        // Maker ask user receives 98% of the whole price (2% protocol)
        assertEq(address(makerUser).balance, _initialETHBalanceUser + ((price * 9800) * (numberPurchases - 1)) / 10000);
        // No leftover in the balance of the contract
        assertEq(address(looksRareProtocol).balance, 0);
    }
}
