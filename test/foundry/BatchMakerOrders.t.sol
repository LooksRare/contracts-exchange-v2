// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Merkle} from "../../lib/murky/src/Merkle.sol";
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";
import {ProtocolBase} from "./ProtocolBase.t.sol";

contract BatchMakerOrdersTest is ProtocolBase {
    function testTakerBidMultipleOrdersSignedERC721() public {
        _setUpUsers();

        // Initialize Merkle Tree
        Merkle m = new Merkle();

        uint256 numberOrders = 1000; // The test will sell itemId = numberOrders - 1
        bytes32[] memory orderHashes = new bytes32[](numberOrders);

        price = 1 ether; // Fixed price of sale

        for (uint112 i; i < numberOrders; i++) {
            // Mint asset
            mockERC721.mint(makerUser, i);

            // Prepare the order hash
            makerAsk = _createSingleItemMakerAskOrder(
                0, // askNonce
                0, // subsetNonce
                0, // strategyId (Standard sale for fixed price)
                0, // assetType ERC721,
                i, // orderNonce (incremental)
                address(mockERC721),
                address(0), // ETH,
                makerUser,
                price,
                i // itemId
            );

            orderHashes[i] = _computeOrderHashMakerAsk(makerAsk);
        }

        OrderStructs.MerkleRoot memory merkleRoot = OrderStructs.MerkleRoot({root: m.getRoot(orderHashes)});

        // Verify the merkle proof
        for (uint256 i; i < numberOrders; i++) {
            {
                bytes32[] memory tempMerkleProof = m.getProof(orderHashes, i);
                assertTrue(m.verifyProof(merkleRoot.root, tempMerkleProof, orderHashes[i]));
            }
        }

        // Maker signs the root
        signature = _signMerkleProof(merkleRoot, makerUserPK);

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

        bytes32[] memory merkleProof = m.getProof(orderHashes, numberOrders - 1);
        delete m;

        {
            uint256 gasLeft = gasleft();

            // Execute taker bid transaction
            looksRareProtocol.executeTakerBid{value: price}(
                takerBid,
                makerAsk,
                signature,
                merkleRoot,
                merkleProof,
                _emptyAffiliate
            );
            emit log_named_uint(
                "TakerBid // ERC721 // Protocol Fee // Multiple Orders Signed // No Royalties",
                gasLeft - gasleft()
            );
        }

        vm.stopPrank();

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(numberOrders - 1), takerUser);
        // Taker bid user pays the whole price
        assertEq(address(takerUser).balance, _initialETHBalanceUser - price);
        // Maker ask user receives 98% of the whole price (2% protocol)
        assertEq(address(makerUser).balance, _initialETHBalanceUser + (price * 9800) / 10000);
        // No leftover in the balance of the contract
        assertEq(address(looksRareProtocol).balance, 0);
        // Verify the nonce is marked as executed
        assertTrue(looksRareProtocol.userOrderNonce(makerUser, makerAsk.orderNonce));
    }

    function testTakerAskMultipleOrdersSignedERC721() public {
        _setUpUsers();

        // Initialize Merkle Tree
        Merkle m = new Merkle();

        uint256 numberOrders = 1000; // The test will sell itemId = numberOrders - 1
        bytes32[] memory orderHashes = new bytes32[](numberOrders);

        price = 1 ether; // Fixed price of sale

        for (uint112 i; i < numberOrders; i++) {
            // Prepare the order hash
            makerBid = _createSingleItemMakerBidOrder(
                0, // askNonce
                0, // subsetNonce
                0, // strategyId (Standard sale for fixed price)
                0, // assetType ERC721,
                i, // orderNonce (incremental)
                address(mockERC721),
                address(weth),
                makerUser,
                price,
                i // itemId
            );

            orderHashes[i] = _computeOrderHashMakerBid(makerBid);
        }

        OrderStructs.MerkleRoot memory merkleRoot = OrderStructs.MerkleRoot({root: m.getRoot(orderHashes)});

        // Verify the merkle proof
        for (uint256 i; i < numberOrders; i++) {
            {
                bytes32[] memory tempMerkleProof = m.getProof(orderHashes, i);
                assertTrue(m.verifyProof(merkleRoot.root, tempMerkleProof, orderHashes[i]));
            }
        }

        // Maker signs the root
        signature = _signMerkleProof(merkleRoot, makerUserPK);

        // Taker user actions
        vm.startPrank(takerUser);

        {
            // Mint asset
            mockERC721.mint(takerUser, numberOrders - 1);

            // Prepare the taker ask
            takerAsk = OrderStructs.TakerAsk(
                takerUser,
                makerBid.maxPrice,
                makerBid.itemIds,
                makerBid.amounts,
                abi.encode()
            );
        }

        bytes32[] memory merkleProof = m.getProof(orderHashes, numberOrders - 1);
        delete m;

        {
            uint256 gasLeft = gasleft();

            // Execute taker ask transaction
            looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, merkleRoot, merkleProof, _emptyAffiliate);

            emit log_named_uint(
                "TakerAsk // ERC721 // Protocol Fee // Multiple Orders Signed // No Royalties",
                gasLeft - gasleft()
            );
        }

        vm.stopPrank();

        // Maker user has received the asset
        assertEq(mockERC721.ownerOf(numberOrders - 1), makerUser);
        // Maker bid user pays the whole price
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser - price);
        // Taker ask user receives 98% of the whole price (2% protocol)
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser + (price * 9800) / 10000);
        // Verify the nonce is marked as executed
        assertTrue(looksRareProtocol.userOrderNonce(makerUser, makerBid.orderNonce));
    }
}
