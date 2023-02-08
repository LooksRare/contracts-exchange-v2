// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

contract TypehashDirectory {
    function get(uint256 height) external pure returns (bytes32 typehash) {
        if (height > 5) {
            revert("Not supported (yet)!");
        }

        /**
         * It looks like this for each height
         * height == 1: MerkleOrder(MakerAsk[2] tree)MakerAsk(uint256 askNonce,uint256 subsetNonce,uint256 strategyId,uint256 assetType,uint256 orderNonce,address collection,address currency,address signer,uint256 startTime,uint256 endTime,uint256 minPrice,uint256[] itemIds,uint256[] amounts,bytes additionalParameters)
         * height == 2: MerkleOrder(MakerAsk[2][2] tree)MakerAsk(uint256 askNonce,uint256 subsetNonce,uint256 strategyId,uint256 assetType,uint256 orderNonce,address collection,address currency,address signer,uint256 startTime,uint256 endTime,uint256 minPrice,uint256[] itemIds,uint256[] amounts,bytes additionalParameters)
         * height == n: MerkleOrder(MakerAsk[2]...[2] tree)MakerAsk(uint256 askNonce,uint256 subsetNonce,uint256 strategyId,uint256 assetType,uint256 orderNonce,address collection,address currency,address signer,uint256 startTime,uint256 endTime,uint256 minPrice,uint256[] itemIds,uint256[] amounts,bytes additionalParameters)
         */
        if (height == 1) {
            typehash = hex"8f0d7502fb27b1b5e1ee35a5017c8794eb83a09bfada924d2dc476d9833181f2";
        } else if (height == 2) {
            typehash = hex"ea43b791c444a1ea70ed031bb199e2e78f8acdbb99b17361cd8b08d3f5d7d242";
        } else if (height == 3) {
            typehash = hex"762cd7234326eb172b29355a4562a01b1f037948a6c447d79fbb973c6e446082";
        } else if (height == 4) {
            typehash = hex"efc491bbd29fc00f5965410a8bec8b695f4e2d6e80708b059cd70aa2d8633868";
        } else if (height == 5) {
            typehash = hex"1bac1193c5474e76a5442692a196d659a99788d7a02883f41ec0a231a969755b";
        }
        // TODO: Fill the rest
        // } else if (height == 6) {
        //   typehash = hex"";
        // } else if (height == 7) {
        //   typehash = hex"";
        // } else if (height == 8) {
        //   typehash = hex"";
        // } else if (height == 9) {
        //   typehash = hex"";
        // } else if (height == 10) {
        //   typehash = hex"";
        // }
    }
}
