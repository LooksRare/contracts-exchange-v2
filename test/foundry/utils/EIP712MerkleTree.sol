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
        BatchOrderTypehashRegistry batchOrderTypehashRegistry = looksRareProtocol.batchOrderTypehashRegistry();
        if (treeHeight > MAX_CALLDATA_PROOF_LENGTH) {
            if (treeHeight == 11) {
                batchOrderTypehash = hex"9e57c4795d748b22bed196a50d5db40033bb0aaf647cb5ccafc013c79f148468";
            } else if (treeHeight == 12) {
                batchOrderTypehash = hex"215eba812ae377db858beef9413fa31c720c53b8e5ab79dc7556e2c2452fcba4";
            } else if (treeHeight == 13) {
                batchOrderTypehash = hex"f9caca4f4ff7e69fbc09582b1cbecf985f749cabcaf8bf8e8b1f2272661d7459";
            }
        } else {
            batchOrderTypehash = batchOrderTypehashRegistry.getTypehash(treeHeight);
        }
    }
}
