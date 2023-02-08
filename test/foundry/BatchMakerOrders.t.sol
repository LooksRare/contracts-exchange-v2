// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Murky (third-party) library is used to compute Merkle trees in Solidity
import {Merkle} from "../../lib/murky/src/Merkle.sol";

// Libraries
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";

// Errors and constants
import {MerkleProofTooLarge, MerkleProofInvalid} from "../../contracts/errors/SharedErrors.sol";
import {MERKLE_PROOF_PROOF_TOO_LARGE, ORDER_HASH_PROOF_NOT_IN_MERKLE_TREE} from "../../contracts/constants/ValidationCodeConstants.sol";
import {ONE_HUNDRED_PERCENT_IN_BP, MAX_CALLDATA_PROOF_LENGTH, ASSET_TYPE_ERC721} from "../../contracts/constants/NumericConstants.sol";

// Base test
import {ProtocolBase} from "./ProtocolBase.t.sol";

import {EIP712MerkleTree} from "./utils/EIP712MerkleTree.sol";

contract BatchMakerOrdersTest is ProtocolBase {
    uint256 private constant price = 1.2222 ether; // Fixed price of sale

    function setUp() public {
        _setUp();
        _setUpUsers();
    }

    function testTakerBidMultipleOrdersSignedERC721() public {
        // uint256 numberOrders = 2 ** MAX_CALLDATA_PROOF_LENGTH;
        uint256 numberOrders = 2 ** 5; // 32
        uint256 makerAskIndex = 15; // The 16th maker ask

        // The test will sell itemId = numberOrders - 1
        // Merkle m = new Merkle();
        // bytes32[] memory orderHashes = new bytes32[](numberOrders);

        for (uint256 i; i < numberOrders; i++) {
            mockERC721.mint(makerUser, i);
        }

        OrderStructs.MakerAsk[] memory makerAsks = _createBatchMakerAsks(numberOrders);
        bytes32[] memory orderHashes = new bytes32[](numberOrders);
        for (uint256 i; i < numberOrders; i++) {
            orderHashes[i] = _computeOrderHashMakerAsk(makerAsks[i]);
        }

        EIP712MerkleTree eip712MerkleTree = new EIP712MerkleTree(looksRareProtocol);

        (bytes memory signature, bytes32[] memory proof, bytes32 root) = eip712MerkleTree.sign(
            makerUserPK,
            makerAsks,
            makerAskIndex
        );

        OrderStructs.MerkleTree memory merkleTree = OrderStructs.MerkleTree({root: root, proof: proof});
        _verifyMerkleProof(merkleTree, orderHashes);

        // Verify validity
        // _assertValidMakerAskOrderWithMerkleTree(makerAsk, signature, merkleTree);

        // Prepare the taker bid
        OrderStructs.Taker memory takerBid = OrderStructs.Taker(takerUser, abi.encode());

        // Execute taker bid transaction
        vm.prank(takerUser);
        looksRareProtocol.executeTakerBid{value: price}(
            takerBid,
            makerAsks[makerAskIndex],
            signature,
            merkleTree,
            _EMPTY_AFFILIATE
        );

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(makerAskIndex), takerUser);
        // Taker bid user pays the whole price
        assertEq(address(takerUser).balance, _initialETHBalanceUser - price);
        // Maker ask user receives 98% of the whole price (2% protocol)
        assertEq(address(makerUser).balance, _initialETHBalanceUser + (price * 9_800) / ONE_HUNDRED_PERCENT_IN_BP);
        // No leftover in the balance of the contract
        assertEq(address(looksRareProtocol).balance, 0);
        // Verify the nonce is marked as executed
        assertEq(
            looksRareProtocol.userOrderNonce(makerUser, makerAsks[makerAskIndex].orderNonce),
            MAGIC_VALUE_ORDER_NONCE_EXECUTED
        );
    }

    function testTakerBidMultipleOrdersSignedERC721FromSDK() public {
        address seller = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;
        _setUpUser(seller);

        bytes32 root = hex"f3909fc2edba95a4306626b6f4b96d22c54861b7c2abb0da472122ad61c5142b";
        bytes
            memory signature = hex"d207e8c4d42e51ebf124aa417faff624d0e201686276243101a11d706f52fa447a0a580ec61a70cfdb7d22c0e5b26c293d35ff6fac554212c0683209578d1c871b";

        OrderStructs.MakerAsk[] memory makerAsks = new OrderStructs.MakerAsk[](2);

        makerAsks[0].askNonce = 0;
        makerAsks[0].subsetNonce = 0;
        makerAsks[0].strategyId = 0;
        makerAsks[0].assetType = 0;
        makerAsks[0].orderNonce = 0;
        makerAsks[0].collection = address(mockERC721);
        makerAsks[0].currency = address(weth);
        makerAsks[0].signer = seller;
        makerAsks[0].startTime = 1675788113;
        makerAsks[0].endTime = 1677602513;
        makerAsks[0].minPrice = 1 ether;
        uint256[] memory itemIds = new uint256[](1);
        itemIds[0] = 1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;
        makerAsks[0].itemIds = itemIds;
        makerAsks[0].amounts = amounts;

        makerAsks[1].askNonce = 0;
        makerAsks[1].subsetNonce = 0;
        makerAsks[1].strategyId = 0;
        makerAsks[1].assetType = 0;
        makerAsks[1].orderNonce = 0;
        makerAsks[1].collection = address(mockERC721);
        makerAsks[1].currency = address(weth);
        makerAsks[1].signer = seller;
        makerAsks[1].startTime = 1675788113;
        makerAsks[1].endTime = 1677602513;
        makerAsks[1].minPrice = 1 ether;
        uint256[] memory itemIdsTwo = new uint256[](1);
        itemIdsTwo[0] = 2;
        makerAsks[1].itemIds = itemIdsTwo;
        makerAsks[1].amounts = amounts;

        uint256 numberOrders = 2 ** 1; // 2
        uint256 makerAskIndex = 0; // The 1st maker ask

        for (uint256 i = 1; i <= numberOrders; i++) {
            mockERC721.mint(seller, i);
        }

        bytes32[] memory orderHashes = new bytes32[](numberOrders);
        for (uint256 i; i < numberOrders; i++) {
            orderHashes[i] = _computeOrderHashMakerAsk(makerAsks[i]);
        }

        // bytes32[] memory proof = new bytes32[](2);
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = hex"420d61e3890d7c0f02a0418690205fc56ed5b0b4f54ef00a470a53b09552ae15";
        // proof[1] = hex"20817d86c67bf108b25591d82c9615dbeecb365a0299f6d64b01df7a204e2e8e";

        OrderStructs.MerkleTree memory merkleTree = OrderStructs.MerkleTree({root: root, proof: proof});
        _verifyMerkleProof(merkleTree, orderHashes);

        // Verify validity
        // _assertValidMakerAskOrderWithMerkleTree(makerAsk, signature, merkleTree);

        // Prepare the taker bid
        OrderStructs.Taker memory takerBid = OrderStructs.Taker(takerUser, abi.encode());

        vm.warp(makerAsks[0].startTime + 1);

        // Execute taker bid transaction
        vm.prank(takerUser);
        looksRareProtocol.executeTakerBid{value: 1 ether}(
            takerBid,
            makerAsks[makerAskIndex],
            signature,
            merkleTree,
            _EMPTY_AFFILIATE
        );

        // token ID 2 is not sold
        assertEq(mockERC721.ownerOf(2), seller);

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(1), takerUser);
        // // Taker bid user pays the whole price
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser - 1 ether);
        // Maker ask user receives 98% of the whole price (2% protocol)
        assertEq(weth.balanceOf(seller), _initialWETHBalanceUser + (1 ether * 9_800) / ONE_HUNDRED_PERCENT_IN_BP);
        // No leftover in the balance of the contract
        assertEq(weth.balanceOf(address(looksRareProtocol)), 0);
        // Verify the nonce is marked as executed
        assertEq(
            looksRareProtocol.userOrderNonce(seller, makerAsks[makerAskIndex].orderNonce),
            MAGIC_VALUE_ORDER_NONCE_EXECUTED
        );
    }

    // function testTakerAskMultipleOrdersSignedERC721() public {
    //     uint256 numberOrders = 2 ** MAX_CALLDATA_PROOF_LENGTH;

    //     // @dev The test will sell itemId = numberOrders - 1
    //     Merkle m = new Merkle();
    //     bytes32[] memory orderHashes = new bytes32[](numberOrders);

    //     OrderStructs.MakerBid memory makerBid = _createBatchMakerBidOrderHashes(orderHashes);

    //     OrderStructs.MerkleTree memory merkleTree = _getMerkleTree(m, orderHashes);
    //     _verifyMerkleProof(m, merkleTree, orderHashes);

    //     // Maker signs the root
    //     bytes memory signature = _signMerkleProof(merkleTree, makerUserPK);

    //     // Verify validity
    //     _assertValidMakerBidOrderWithMerkleTree(makerBid, signature, merkleTree);

    //     // Mint asset
    //     mockERC721.mint(takerUser, numberOrders - 1);

    //     // Prepare the taker ask
    //     OrderStructs.Taker memory takerAsk = OrderStructs.Taker(takerUser, abi.encode());

    //     // Execute taker ask transaction
    //     vm.prank(takerUser);
    //     looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, merkleTree, _EMPTY_AFFILIATE);

    //     // Maker user has received the asset
    //     assertEq(mockERC721.ownerOf(numberOrders - 1), makerUser);
    //     // Maker bid user pays the whole price
    //     assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser - price);
    //     // Taker ask user receives 98% of the whole price (2% protocol)
    //     assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser + (price * 9_800) / ONE_HUNDRED_PERCENT_IN_BP);
    //     // Verify the nonce is marked as executed
    //     assertEq(looksRareProtocol.userOrderNonce(makerUser, makerBid.orderNonce), MAGIC_VALUE_ORDER_NONCE_EXECUTED);
    // }

    // function testTakerBidMultipleOrdersSignedERC721MerkleProofInvalid() public {
    //     uint256 numberOrders = 2 ** MAX_CALLDATA_PROOF_LENGTH;

    //     Merkle m = new Merkle();
    //     bytes32[] memory orderHashes = new bytes32[](numberOrders);
    //     OrderStructs.MakerAsk memory makerAsk = _createBatchMakerAskOrderHashes(orderHashes);

    //     OrderStructs.MerkleTree memory merkleTree = _getMerkleTree(m, orderHashes);
    //     bytes32 tamperedRoot = bytes32(uint256(m.getRoot(orderHashes)) + 1);
    //     merkleTree.root = tamperedRoot;

    //     // Maker signs the root
    //     bytes memory signature = _signMerkleProof(merkleTree, makerUserPK);

    //     // Verify invalidity of maker ask order
    //     _doesMakerAskOrderReturnValidationCodeWithMerkleTree(
    //         makerAsk,
    //         signature,
    //         merkleTree,
    //         ORDER_HASH_PROOF_NOT_IN_MERKLE_TREE
    //     );

    //     // Prepare the taker bid
    //     OrderStructs.Taker memory takerBid = OrderStructs.Taker(takerUser, abi.encode());

    //     vm.prank(takerUser);
    //     vm.expectRevert(MerkleProofInvalid.selector);
    //     looksRareProtocol.executeTakerBid{value: price}(takerBid, makerAsk, signature, merkleTree, _EMPTY_AFFILIATE);
    // }

    // function testTakerAskMultipleOrdersSignedERC721MerkleProofInvalid() public {
    //     uint256 numberOrders = 2 ** MAX_CALLDATA_PROOF_LENGTH;

    //     Merkle m = new Merkle();
    //     bytes32[] memory orderHashes = new bytes32[](numberOrders);
    //     OrderStructs.MakerBid memory makerBid = _createBatchMakerBidOrderHashes(orderHashes);

    //     OrderStructs.MerkleTree memory merkleTree = _getMerkleTree(m, orderHashes);
    //     bytes32 tamperedRoot = bytes32(uint256(m.getRoot(orderHashes)) + 1);
    //     merkleTree.root = tamperedRoot;

    //     // Maker signs the root
    //     bytes memory signature = _signMerkleProof(merkleTree, makerUserPK);

    //     // Verify invalidity of maker bid order
    //     _doesMakerBidOrderReturnValidationCodeWithMerkleTree(
    //         makerBid,
    //         signature,
    //         merkleTree,
    //         ORDER_HASH_PROOF_NOT_IN_MERKLE_TREE
    //     );

    //     // Prepare the taker ask
    //     OrderStructs.Taker memory takerAsk = OrderStructs.Taker(takerUser, abi.encode());

    //     vm.prank(takerUser);
    //     vm.expectRevert(MerkleProofInvalid.selector);
    //     looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, merkleTree, _EMPTY_AFFILIATE);
    // }

    // function testTakerBidRevertsIfProofTooLarge() public {
    //     uint256 numberOrders = 2 ** MAX_CALLDATA_PROOF_LENGTH + 1;

    //     // The test will sell itemId = numberOrders - 1
    //     Merkle m = new Merkle();
    //     bytes32[] memory orderHashes = new bytes32[](numberOrders);

    //     for (uint256 i; i < numberOrders; i++) {
    //         mockERC721.mint(makerUser, i);
    //     }

    //     OrderStructs.MakerAsk memory makerAsk = _createBatchMakerAskOrderHashes(orderHashes);
    //     OrderStructs.MerkleTree memory merkleTree = _getMerkleTree(m, orderHashes);
    //     _verifyMerkleProof(m, merkleTree, orderHashes);

    //     // Maker signs the root
    //     bytes memory signature = _signMerkleProof(merkleTree, makerUserPK);

    //     // Verify validity
    //     _doesMakerAskOrderReturnValidationCodeWithMerkleTree(
    //         makerAsk,
    //         signature,
    //         merkleTree,
    //         MERKLE_PROOF_PROOF_TOO_LARGE
    //     );

    //     // Prepare the taker bid
    //     OrderStructs.Taker memory takerBid = OrderStructs.Taker(takerUser, abi.encode());

    //     vm.prank(takerUser);
    //     vm.expectRevert(abi.encodeWithSelector(MerkleProofTooLarge.selector, MAX_CALLDATA_PROOF_LENGTH + 1));
    //     looksRareProtocol.executeTakerBid{value: price}(takerBid, makerAsk, signature, merkleTree, _EMPTY_AFFILIATE);
    // }

    // function testTakerAskRevertsIfProofTooLarge() public {
    //     uint256 numberOrders = 2 ** MAX_CALLDATA_PROOF_LENGTH + 1;

    //     // @dev The test will sell itemId = numberOrders - 1
    //     Merkle m = new Merkle();
    //     bytes32[] memory orderHashes = new bytes32[](numberOrders);

    //     OrderStructs.MakerBid memory makerBid = _createBatchMakerBidOrderHashes(orderHashes);

    //     OrderStructs.MerkleTree memory merkleTree = _getMerkleTree(m, orderHashes);
    //     _verifyMerkleProof(m, merkleTree, orderHashes);

    //     // Maker signs the root
    //     bytes memory signature = _signMerkleProof(merkleTree, makerUserPK);

    //     // Verify validity
    //     _doesMakerBidOrderReturnValidationCodeWithMerkleTree(
    //         makerBid,
    //         signature,
    //         merkleTree,
    //         MERKLE_PROOF_PROOF_TOO_LARGE
    //     );

    //     // Mint asset
    //     mockERC721.mint(takerUser, numberOrders - 1);

    //     // Prepare the taker ask
    //     OrderStructs.Taker memory takerAsk = OrderStructs.Taker(takerUser, abi.encode());

    //     vm.prank(takerUser);
    //     vm.expectRevert(abi.encodeWithSelector(MerkleProofTooLarge.selector, MAX_CALLDATA_PROOF_LENGTH + 1));
    //     looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, merkleTree, _EMPTY_AFFILIATE);
    // }

    // function _getMerkleTree(
    //     Merkle m,
    //     bytes32[] memory orderHashes
    // ) private pure returns (OrderStructs.MerkleTree memory merkleTree) {
    //     uint256 numberOrders = orderHashes.length;
    //     merkleTree = OrderStructs.MerkleTree({
    //         root: m.getRoot(orderHashes),
    //         proof: m.getProof(orderHashes, numberOrders - 1)
    //     });
    // }

    function _verifyMerkleProof(OrderStructs.MerkleTree memory merkleTree, bytes32[] memory orderHashes) private {
        Merkle m = new Merkle();
        uint256 numberOrders = orderHashes.length;

        for (uint256 i; i < numberOrders; i++) {
            {
                bytes32[] memory merkleProof = m.getProof(orderHashes, i);
                assertTrue(m.verifyProof(merkleTree.root, merkleProof, orderHashes[i]));
            }
        }
    }

    function _createBatchMakerAsks(
        uint256 numberOrders
    ) private view returns (OrderStructs.MakerAsk[] memory makerAsks) {
        makerAsks = new OrderStructs.MakerAsk[](numberOrders);
        for (uint256 i; i < numberOrders; i++) {
            makerAsks[i] = _createSingleItemMakerAskOrder({
                askNonce: 0,
                subsetNonce: 0,
                strategyId: STANDARD_SALE_FOR_FIXED_PRICE_STRATEGY,
                assetType: ASSET_TYPE_ERC721,
                orderNonce: i, // incremental
                collection: address(mockERC721),
                currency: ETH,
                signer: makerUser,
                minPrice: price,
                itemId: i
            });
        }
    }

    // function _createBatchMakerBidOrderHashes(
    //     bytes32[] memory orderHashes
    // ) private view returns (OrderStructs.MakerBid memory makerBid) {
    //     uint256 numberOrders = orderHashes.length;

    //     for (uint256 i; i < numberOrders; i++) {
    //         // Prepare the order hash
    //         makerBid = _createSingleItemMakerBidOrder({
    //             bidNonce: 0,
    //             subsetNonce: 0,
    //             strategyId: STANDARD_SALE_FOR_FIXED_PRICE_STRATEGY,
    //             assetType: ASSET_TYPE_ERC721,
    //             orderNonce: i, // incremental
    //             collection: address(mockERC721),
    //             currency: address(weth),
    //             signer: makerUser,
    //             maxPrice: price,
    //             itemId: i
    //         });

    //         orderHashes[i] = _computeOrderHashMakerBid(makerBid);
    //     }
    // }
}
