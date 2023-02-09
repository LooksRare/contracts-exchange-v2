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
         * height == 1: BatchOrder(Maker[2] tree)Maker(QuoteType quoteType,uint256 globalNonce,uint256 orderNonce,uint256 subsetNonce,uint256 strategyId,AssetType assetType,address collection,address currency,address signer,uint256 startTime,uint256 endTime,uint256 price,uint256[] itemIds,uint256[] amounts,bytes additionalParameters)
         * height == 2: BatchOrder(Maker[2][2] tree)Maker(QuoteType quoteType,uint256 globalNonce,uint256 orderNonce,uint256 subsetNonce,uint256 strategyId,AssetType assetType,address collection,address currency,address signer,uint256 startTime,uint256 endTime,uint256 price,uint256[] itemIds,uint256[] amounts,bytes additionalParameters)
         * height == n: BatchOrder(Maker[2]...[2] tree)Maker(QuoteType quoteType,uint256 globalNonce,uint256 orderNonce,uint256 subsetNonce,uint256 strategyId,AssetType assetType,address collection,address currency,address signer,uint256 startTime,uint256 endTime,uint256 price,uint256[] itemIds,uint256[] amounts,bytes additionalParameters)
         */
        if (height == 1) {
            typehash = hex"fd8d80d0315a381e334966c4ba05971e2a83dfcdd24e29b7f4692a50abaf0ec1";
        } else if (height == 2) {
            typehash = hex"5ca370d8017ab2bd080a7a03cad23e0a40d8e60684d086337d3ea50db9a61333";
        } else if (height == 3) {
            typehash = hex"d8e409d67b24095238a0560d75f27b6ede8ac141838cd5d4c15822e32ecafd5f";
        } else if (height == 4) {
            typehash = hex"8f03ed7d697137a91b53f695d39b3b027c223ffaef9b6b2d7c22ad6fef54cbb3";
        } else if (height == 5) {
            typehash = hex"b51b8fb8511e65d0f68fe374cd1de53e6d897858e9c77698a76fb97b0e3a7111";
        } else if (height == 6) {
            typehash = hex"ab20a90b8c759d121eee5a78b6fa7b784ecb2fa331dc0cff73e7857e290c90ff";
        } else if (height == 7) {
            typehash = hex"d3764a8b03dd85ecaf60b05a2bd52dcf13fbe81fae1818321c93eab218fb934d";
        } else if (height == 8) {
            typehash = hex"01903768ba35b9aaec730056807346d9f6cb689ba8c6c61d21def3ee0aee960e";
        } else if (height == 9) {
            typehash = hex"d07a0372a4b6f6bebf9360c1a1d772c31bc415527972c03003c518fcbafd3ac8";
        } else if (height == 10) {
            typehash = hex"8c97dccf7be0b886237955fffbbb1a401134006da146b3d8b0de943bfa52cecb";
        } else {
            revert MerkleProofTooLarge(height);
        }
    }
}
