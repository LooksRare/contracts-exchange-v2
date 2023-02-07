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
