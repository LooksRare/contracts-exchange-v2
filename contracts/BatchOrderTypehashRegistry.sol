// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Shared errors
import {MerkleProofTooLarge} from "./errors/SharedErrors.sol";

contract BatchOrderTypehashRegistry {
    function hash(bytes32 root, uint256 proofLength) external pure returns (bytes32 batchOrderTypehash) {
        batchOrderTypehash = keccak256(abi.encode(getTypehash(proofLength), root));
    }

    function getTypehash(uint256 height) public pure returns (bytes32 typehash) {
        /**
         * It looks like this for each height
         * height == 1: BatchOrder(Maker[2] tree)Maker(uint8 quoteType,uint256 globalNonce,uint256 orderNonce,uint256 subsetNonce,uint256 strategyId,uint8 assetType,address collection,address currency,address signer,uint256 startTime,uint256 endTime,uint256 price,uint256[] itemIds,uint256[] amounts,bytes additionalParameters)
         * height == 2: BatchOrder(Maker[2][2] tree)Maker(uint8 quoteType,uint256 globalNonce,uint256 orderNonce,uint256 subsetNonce,uint256 strategyId,uint8 assetType,address collection,address currency,address signer,uint256 startTime,uint256 endTime,uint256 price,uint256[] itemIds,uint256[] amounts,bytes additionalParameters)
         * height == n: BatchOrder(Maker[2]...[2] tree)Maker(uint8 quoteType,uint256 globalNonce,uint256 orderNonce,uint256 subsetNonce,uint256 strategyId,uint8 assetType,address collection,address currency,address signer,uint256 startTime,uint256 endTime,uint256 price,uint256[] itemIds,uint256[] amounts,bytes additionalParameters)
         */
        if (height == 1) {
            typehash = hex"e38dbaa95c7c389056f595cc23317ac8621f63e8084e61bf4033ce5e607052d8";
        } else if (height == 2) {
            typehash = hex"f4125a8d908521a5a9a85660cf49bdbd5faaf02ed89ceb48834409c711e6f90a";
        } else if (height == 3) {
            typehash = hex"eb45f933fae62e2cd328959656194332b3346cfa329bfb9a72c77abbd9a718e5";
        } else if (height == 4) {
            typehash = hex"c871d8783b4a68f25e642c15245408589a765119e124421e39682bd1661fd878";
        } else if (height == 5) {
            typehash = hex"44fbb30c791d2707130f3c54fee7ef31248a13a1483e373b91ec2a73b215516d";
        } else if (height == 6) {
            typehash = hex"36a7707e0cc39191e009fde894f6f51600b1ecd4222c3bb09035475c6ba8d871";
        } else if (height == 7) {
            typehash = hex"a82fad44735141369501c4e4f967228ba648b7fedf5db98abbaabc5ffd55eb7e";
        } else if (height == 8) {
            typehash = hex"8a7b799a968f7c2f8f709e3625fd58477ac76408d74b02a5e1253ce50ebf8970";
        } else if (height == 9) {
            typehash = hex"d52d959878f03aab662aa1f8c00ae8182f46bf1119c503fe3d580cbeffd67d64";
        } else if (height == 10) {
            typehash = hex"3a3192f21c99f1fb02fadbe1c034c51845fc75379ae35447edeffd9f562e93b2";
        } else {
            revert MerkleProofTooLarge(height);
        }
    }
}
