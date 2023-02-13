// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../../../contracts/BatchOrderTypehashRegistry.sol";
import "../../../contracts/libraries/OrderStructs.sol";

// Interfaces
import "../../../contracts/LooksRareProtocol.sol";

// Libraries
import {OrderStructs} from "../../../contracts/libraries/OrderStructs.sol";
import {Test} from "forge-std/Test.sol";
import {Math} from "../../../contracts/libraries/OpenZeppelin/Math.sol";
import {Merkle} from "../../../lib/murky/src/Merkle.sol";

// Constants
import {MAX_CALLDATA_PROOF_LENGTH} from "../../../contracts/constants/NumericConstants.sol";

contract EIP712MerkleTree is Test {
    using OrderStructs for OrderStructs.Maker;

    LooksRareProtocol private looksRareProtocol;

    constructor(LooksRareProtocol _looksRareProtocol) {
        looksRareProtocol = _looksRareProtocol;
    }

    function sign(
        uint256 privateKey,
        OrderStructs.Maker[] memory makerOrders,
        uint256 makerOrderIndex
    ) external returns (bytes memory signature, OrderStructs.MerkleTree memory merkleTree) {
        uint256 bidCount = makerOrders.length;
        uint256 treeHeight = Math.log2(bidCount);
        if (2 ** treeHeight != bidCount || treeHeight == 0) {
            treeHeight += 1;
        }
        bytes32 batchOrderTypehash = _getBatchOrderTypehash(treeHeight);
        uint256 leafCount = 2 ** treeHeight;
        bytes32[] memory leaves = new bytes32[](leafCount);

        for (uint256 i; i < bidCount; i++) {
            leaves[i] = makerOrders[i].hash();
        }

        bytes32 emptyMakerOrderHash = _emptyMakerOrderHash();
        for (uint256 i = bidCount; i < leafCount; i++) {
            leaves[i] = emptyMakerOrderHash;
        }

        Merkle merkle = new Merkle();
        bytes32[] memory proof = merkle.getProof(leaves, makerOrderIndex);
        bytes32 root = merkle.getRoot(leaves);

        signature = _sign(privateKey, batchOrderTypehash, root);
        merkleTree = OrderStructs.MerkleTree({root: root, proof: proof});
    }

    function _emptyMakerOrderHash() private pure returns (bytes32 makerOrderHash) {
        OrderStructs.Maker memory makerOrder;
        makerOrderHash = makerOrder.hash();
    }

    function _sign(
        uint256 privateKey,
        bytes32 batchOrderTypehash,
        bytes32 root
    ) private view returns (bytes memory signature) {
        bytes32 digest = keccak256(abi.encode(batchOrderTypehash, root));

        bytes32 domainSeparator = looksRareProtocol.domainSeparator();

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(abi.encodePacked("\x19\x01", domainSeparator, digest))
        );

        signature = abi.encodePacked(r, s, v);
    }

    function _getBatchOrderTypehash(uint256 treeHeight) private pure returns (bytes32 batchOrderTypehash) {
        if (treeHeight == 1) {
            batchOrderTypehash = hex"cbbc55854abc707c09d732e7a51c3a1afc570dbbbd52fc5a98e4405f5379b60a";
        } else if (treeHeight == 2) {
            batchOrderTypehash = hex"17a0c314d856b89d3cacb1db1904702847910f15e9092b28cfa5ef32ae2b851b";
        } else if (treeHeight == 3) {
            batchOrderTypehash = hex"73d811d61eeec3b062bc4e79135b198acd0036360931714173b6d31e8da1838d";
        } else if (treeHeight == 4) {
            batchOrderTypehash = hex"9a418ad3a5100c9f4baf19fa46c9863f0cfe8e47ed76281e0b31cf59db8f0d7a";
        } else if (treeHeight == 5) {
            batchOrderTypehash = hex"added5faf1d2f37945d7b637b2c838e38814d49c683d79e665d2996f4a2b1ace";
        } else if (treeHeight == 6) {
            batchOrderTypehash = hex"ec13b4bc83cfc2d7885d4f0c3cacb5b70d6e85c746f307e63b382deaa1d72e0d";
        } else if (treeHeight == 7) {
            batchOrderTypehash = hex"4d13a175331d7cb26822d3f8a43ff58d186b0d7199bbc4a8f3d6bd424fe9329f";
        } else if (treeHeight == 8) {
            batchOrderTypehash = hex"06a7cb7b48e9ae3539ba1e484c81abb2618e41ccdc3825b2057a5fd22a17b447";
        } else if (treeHeight == 9) {
            batchOrderTypehash = hex"b7a574557d8026c2a7da2f7b5494254ca1367ae18b2118ccdbb6f2f6fe3d1a61";
        } else if (treeHeight == 10) {
            batchOrderTypehash = hex"8660a645605d92be3fca6dd485f2662e51c0cd2295a59b3db32bf713fbb81ee4";
        } else if (treeHeight == 11) {
            batchOrderTypehash = hex"9a3ce74af1cf5f60b4762d883e0f75912ccffd3a5a75d18399d9273faed739fb";
        } else if (treeHeight == 12) {
            batchOrderTypehash = hex"06195feea862ccec6fab4646f653db6df0ea88e1312269e92c502071c7f57c16";
        } else if (treeHeight == 13) {
            batchOrderTypehash = hex"0aa2f1d0d9d5bfd8e18b7fa947f3957ab4283e016dbec7aa4406586fbfabeb85";
        }
    }
}
