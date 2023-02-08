// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../../../contracts/TypehashDirectory.sol";
import "../../../contracts/libraries/OrderStructs.sol";

// Interfaces
import "../../../contracts/interfaces/ILooksRareProtocol.sol";

// Libraries
import {Test} from "forge-std/Test.sol";
import {Math} from "../../../contracts/libraries/OpenZeppelin/Math.sol";
import {Merkle} from "../../../lib/murky/src/Merkle.sol";

contract EIP712MerkleTree is Test {
    using OrderStructs for OrderStructs.MakerAsk;

    TypehashDirectory private typehashDirectory;
    ILooksRareProtocol private looksRareProtocol;

    constructor(ILooksRareProtocol _looksRareProtocol) {
        typehashDirectory = new TypehashDirectory();
        looksRareProtocol = _looksRareProtocol;
    }

    function sign(
        uint256 privateKey,
        OrderStructs.MakerAsk[] memory makerAsks,
        uint256 makerAskIndex
    ) external returns (bytes memory signature, bytes32[] memory proof, bytes32 root) {
        uint256 bidCount = makerAsks.length;
        uint256 treeHeight = Math.log2(bidCount);
        if (2 ** treeHeight != bidCount || treeHeight == 0) {
            treeHeight += 1;
        }
        bytes32 merkleOrderTypehash = typehashDirectory.get(treeHeight);
        uint256 leafCount = 2 ** treeHeight;
        bytes32[] memory leaves = new bytes32[](leafCount);

        for (uint256 i = 0; i < bidCount; i++) {
            leaves[i] = makerAsks[i].hash();
        }

        bytes32 emptyMakerAskHash = _emptyMakerAskHash();
        for (uint256 i = bidCount; i < leafCount; i++) {
            leaves[i] = emptyMakerAskHash;
        }

        Merkle merkle = new Merkle();
        proof = merkle.getProof(leaves, makerAskIndex);
        root = merkle.getRoot(leaves);

        signature = _sign(privateKey, merkleOrderTypehash, root);
    }

    function _emptyMakerAskHash() private pure returns (bytes32 makerAskHash) {
        OrderStructs.MakerAsk memory makerAsk;
        makerAskHash = makerAsk.hash();
    }

    function _sign(
        uint256 privateKey,
        bytes32 merkleOrderTypehash,
        bytes32 root
    ) private view returns (bytes memory signature) {
        bytes32 digest = keccak256(abi.encode(merkleOrderTypehash, root));

        bytes32 domainSeparator = looksRareProtocol.domainSeparator();

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(abi.encodePacked("\x19\x01", domainSeparator, digest))
        );

        signature = abi.encodePacked(r, s, v);
    }
}
