// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Murky (third-party) library is used to compute Merkle trees in Solidity
import {Merkle} from "../../lib/murky/src/Merkle.sol";

// Libraries
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";

// Base test
import {ProtocolBase} from "./ProtocolBase.t.sol";

contract BatchMakerOrdersTest is ProtocolBase {
    // The test will sell itemId = numberOrders - 1
    uint256 numberOrders = 1_000;

    function setUp() public override {
        super.setUp();
        _setUpUsers();
        price = 1 ether; // Fixed price of sale
    }

    function testTakerBidMultipleOrdersSignedERC721() public {
        // Initialize Merkle Tree
        Merkle m = new Merkle();

        bytes32[] memory orderHashes = new bytes32[](numberOrders);

        for (uint256 i; i < numberOrders; i++) {
            // Mint asset
            mockERC721.mint(makerUser, i);

            // Prepare the order hash
            makerAsk = _createSingleItemMakerAskOrder({
                askNonce: 0,
                subsetNonce: 0,
                strategyId: 0, // Standard sale for fixed price
                assetType: 0, // ERC721,
                orderNonce: i, // incremental
                collection: address(mockERC721),
                currency: address(0), // ETH,
                signer: makerUser,
                minPrice: price,
                itemId: i
            });

            orderHashes[i] = computeOrderHashMakerAsk(makerAsk);
        }

        OrderStructs.MerkleTree memory merkleTree = OrderStructs.MerkleTree({
            root: m.getRoot(orderHashes),
            proof: m.getProof(orderHashes, numberOrders - 1)
        });

        _verifyMerkleProof(orderHashes, m, merkleTree);

        // Maker signs the root
        signature = _signMerkleProof(merkleTree, makerUserPK);

        // Taker user actions
        vm.startPrank(takerUser);

        // Prepare the taker bid
        takerBid = OrderStructs.TakerBid(
            takerUser,
            makerAsk.minPrice,
            makerAsk.itemIds,
            makerAsk.amounts,
            abi.encode()
        );

        uint256 gasLeft = gasleft();

        // Execute taker bid transaction
        looksRareProtocol.executeTakerBid{value: price}(takerBid, makerAsk, signature, merkleTree, _emptyAffiliate);
        emit log_named_uint(
            "TakerBid // ERC721 // Protocol Fee // Multiple Orders Signed // No Royalties",
            gasLeft - gasleft()
        );

        vm.stopPrank();

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(numberOrders - 1), takerUser);
        // Taker bid user pays the whole price
        assertEq(address(takerUser).balance, _initialETHBalanceUser - price);
        // Maker ask user receives 98% of the whole price (2% protocol)
        assertEq(address(makerUser).balance, _initialETHBalanceUser + (price * 9_800) / 10_000);
        // No leftover in the balance of the contract
        assertEq(address(looksRareProtocol).balance, 0);
        // Verify the nonce is marked as executed
        assertEq(looksRareProtocol.userOrderNonce(makerUser, makerAsk.orderNonce), MAGIC_VALUE_NONCE_EXECUTED);
    }

    function testTakerAskMultipleOrdersSignedERC721() public {
        // Initialize Merkle Tree
        Merkle m = new Merkle();

        bytes32[] memory orderHashes = new bytes32[](numberOrders);

        for (uint256 i; i < numberOrders; i++) {
            // Prepare the order hash
            makerBid = _createSingleItemMakerBidOrder({
                bidNonce: 0,
                subsetNonce: 0,
                strategyId: 0, // Standard sale for fixed price
                assetType: 0, // ERC721,
                orderNonce: i, // incremental
                collection: address(mockERC721),
                currency: address(weth),
                signer: makerUser,
                maxPrice: price,
                itemId: i
            });

            orderHashes[i] = computeOrderHashMakerBid(makerBid);
        }

        OrderStructs.MerkleTree memory merkleTree = OrderStructs.MerkleTree({
            root: m.getRoot(orderHashes),
            proof: m.getProof(orderHashes, numberOrders - 1)
        });

        _verifyMerkleProof(orderHashes, m, merkleTree);

        // Maker signs the root
        signature = _signMerkleProof(merkleTree, makerUserPK);

        // Taker user actions
        vm.startPrank(takerUser);

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

        uint256 gasLeft = gasleft();

        // Execute taker ask transaction
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, merkleTree, _emptyAffiliate);

        emit log_named_uint(
            "TakerAsk // ERC721 // Protocol Fee // Multiple Orders Signed // No Royalties",
            gasLeft - gasleft()
        );

        vm.stopPrank();

        // Maker user has received the asset
        assertEq(mockERC721.ownerOf(numberOrders - 1), makerUser);
        // Maker bid user pays the whole price
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser - price);
        // Taker ask user receives 98% of the whole price (2% protocol)
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser + (price * 9_800) / 10_000);
        // Verify the nonce is marked as executed
        assertEq(looksRareProtocol.userOrderNonce(makerUser, makerBid.orderNonce), MAGIC_VALUE_NONCE_EXECUTED);
    }

    function testTakerBidMultipleOrdersSignedERC721WrongMerkleProof() public {
        // Initialize Merkle Tree
        Merkle m = new Merkle();

        bytes32[] memory orderHashes = new bytes32[](numberOrders);

        for (uint256 i; i < numberOrders; i++) {
            // Prepare the order hash
            makerAsk = _createSingleItemMakerAskOrder({
                askNonce: 0, // askNonce
                subsetNonce: 0, // subsetNonce
                strategyId: 0, // Standard sale for fixed price
                assetType: 0, // ERC721
                orderNonce: i, // incremental
                collection: address(mockERC721),
                currency: address(0), // ETH,
                signer: makerUser,
                minPrice: price,
                itemId: i
            });

            orderHashes[i] = computeOrderHashMakerAsk(makerAsk);
        }

        bytes32 tamperedRoot = bytes32(uint256(m.getRoot(orderHashes)) + 1);
        OrderStructs.MerkleTree memory merkleTree = OrderStructs.MerkleTree({
            root: tamperedRoot,
            proof: m.getProof(orderHashes, numberOrders - 1)
        });

        // Maker signs the root
        signature = _signMerkleProof(merkleTree, makerUserPK);

        // Prepare the taker bid
        takerBid = OrderStructs.TakerBid(
            takerUser,
            makerAsk.minPrice,
            makerAsk.itemIds,
            makerAsk.amounts,
            abi.encode()
        );

        // Taker user actions
        vm.startPrank(takerUser);

        vm.expectRevert(WrongMerkleProof.selector);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerBid{value: price}(takerBid, makerAsk, signature, merkleTree, _emptyAffiliate);

        vm.stopPrank();
    }

    function testTakerAskMultipleOrdersSignedERC721WrongMerkleProof() public {
        // Initialize Merkle Tree
        Merkle m = new Merkle();

        bytes32[] memory orderHashes = new bytes32[](numberOrders);

        for (uint256 i; i < numberOrders; i++) {
            // Prepare the order hash
            makerBid = _createSingleItemMakerBidOrder({
                bidNonce: 0,
                subsetNonce: 0,
                strategyId: 0, // Standard sale for fixed price
                assetType: 0, // ERC721
                orderNonce: i, // incremental
                collection: address(mockERC721),
                currency: address(weth),
                signer: makerUser,
                maxPrice: price,
                itemId: i
            });

            orderHashes[i] = computeOrderHashMakerBid(makerBid);
        }

        bytes32 tamperedRoot = bytes32(uint256(m.getRoot(orderHashes)) + 1);
        OrderStructs.MerkleTree memory merkleTree = OrderStructs.MerkleTree({
            root: tamperedRoot,
            proof: m.getProof(orderHashes, numberOrders - 1)
        });

        // Maker signs the root
        signature = _signMerkleProof(merkleTree, makerUserPK);

        // Prepare the taker ask
        takerAsk = OrderStructs.TakerAsk(
            takerUser,
            makerBid.maxPrice,
            makerBid.itemIds,
            makerBid.amounts,
            abi.encode()
        );

        // Taker user actions
        vm.startPrank(takerUser);

        vm.expectRevert(WrongMerkleProof.selector);
        // Execute taker ask transaction
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, merkleTree, _emptyAffiliate);

        vm.stopPrank();
    }

    function _verifyMerkleProof(
        bytes32[] memory orderHashes,
        Merkle m,
        OrderStructs.MerkleTree memory merkleTree
    ) private {
        for (uint256 i; i < numberOrders; i++) {
            {
                bytes32[] memory tempMerkleProof = m.getProof(orderHashes, i);
                assertTrue(m.verifyProof(merkleTree.root, tempMerkleProof, orderHashes[i]));
            }
        }
    }
}
