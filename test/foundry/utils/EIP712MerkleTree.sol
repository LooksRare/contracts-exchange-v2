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
        bytes32 batchOrderTypehash = _getTypehash(treeHeight);
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

    function _getTypehash(uint256 treeHeight) private view returns (bytes32 batchOrderTypehash) {
        if (treeHeight > MAX_CALLDATA_PROOF_LENGTH) {
            if (treeHeight == 11) {
                batchOrderTypehash = hex"9a3ce74af1cf5f60b4762d883e0f75912ccffd3a5a75d18399d9273faed739fb";
            } else if (treeHeight == 12) {
                batchOrderTypehash = hex"06195feea862ccec6fab4646f653db6df0ea88e1312269e92c502071c7f57c16";
            } else if (treeHeight == 13) {
                batchOrderTypehash = hex"0aa2f1d0d9d5bfd8e18b7fa947f3957ab4283e016dbec7aa4406586fbfabeb85";
            }
        } else {
            batchOrderTypehash = looksRareProtocol.getBatchOrderTypehash(treeHeight);
        }
    }
}
