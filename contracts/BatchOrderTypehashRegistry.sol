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
         * height == 1: BatchOrder(Maker[2] tree)Maker(uint8 quoteType,uint256 globalNonce,uint256 subsetNonce,uint256 orderNonce,uint256 strategyId,uint8 assetType,address collection,address currency,address signer,uint256 startTime,uint256 endTime,uint256 price,uint256[] itemIds,uint256[] amounts,bytes additionalParameters)
         * height == 2: BatchOrder(Maker[2][2] tree)Maker(uint8 quoteType,uint256 globalNonce,uint256 subsetNonce,uint256 orderNonce,uint256 strategyId,uint8 assetType,address collection,address currency,address signer,uint256 startTime,uint256 endTime,uint256 price,uint256[] itemIds,uint256[] amounts,bytes additionalParameters)
         * height == n: BatchOrder(Maker[2]...[2] tree)Maker(uint8 quoteType,uint256 globalNonce,uint256 subsetNonce,uint256 orderNonce,uint256 strategyId,uint8 assetType,address collection,address currency,address signer,uint256 startTime,uint256 endTime,uint256 price,uint256[] itemIds,uint256[] amounts,bytes additionalParameters)
         */
        if (height == 1) {
            typehash = hex"cbbc55854abc707c09d732e7a51c3a1afc570dbbbd52fc5a98e4405f5379b60a";
        } else if (height == 2) {
            typehash = hex"17a0c314d856b89d3cacb1db1904702847910f15e9092b28cfa5ef32ae2b851b";
        } else if (height == 3) {
            typehash = hex"73d811d61eeec3b062bc4e79135b198acd0036360931714173b6d31e8da1838d";
        } else if (height == 4) {
            typehash = hex"9a418ad3a5100c9f4baf19fa46c9863f0cfe8e47ed76281e0b31cf59db8f0d7a";
        } else if (height == 5) {
            typehash = hex"added5faf1d2f37945d7b637b2c838e38814d49c683d79e665d2996f4a2b1ace";
        } else if (height == 6) {
            typehash = hex"ec13b4bc83cfc2d7885d4f0c3cacb5b70d6e85c746f307e63b382deaa1d72e0d";
        } else if (height == 7) {
            typehash = hex"4d13a175331d7cb26822d3f8a43ff58d186b0d7199bbc4a8f3d6bd424fe9329f";
        } else if (height == 8) {
            typehash = hex"06a7cb7b48e9ae3539ba1e484c81abb2618e41ccdc3825b2057a5fd22a17b447";
        } else if (height == 9) {
            typehash = hex"b7a574557d8026c2a7da2f7b5494254ca1367ae18b2118ccdbb6f2f6fe3d1a61";
        } else if (height == 10) {
            typehash = hex"8660a645605d92be3fca6dd485f2662e51c0cd2295a59b3db32bf713fbb81ee4";
        } else {
            revert MerkleProofTooLarge(height);
        }
    }
}
