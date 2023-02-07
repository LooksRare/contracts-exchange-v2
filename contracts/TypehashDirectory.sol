// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

contract TypehashDirectory {
    function get(uint256 height) external returns (bytes32 typehash) {
        if (height > 5) {
            revert("Not supported (yet)!");
        }

        /**
         * It looks like this for each height
         * height == 2: MerkleOrder(MakerAsk[2][2] tree)
         * height == 3: MerkleOrder(MakerAsk[2][2][2] tree)
         * height == n: MerkleOrder(MakerAsk[2][2]..[2] tree)
         */
        if (height == 2) {
            typehash = hex"450b57bc1980c882a8c31a630c040926b167106ae38c757c493d255c2a919d22";
        } else if (height == 3) {
            typehash = hex"7d6c02c33e04a66393fbd24f5afe4b46e3b489cd72e86eb19806e9d0fa51a469";
        } else if (height == 4) {
            typehash = hex"ddb0a0e95b1a8f022e8b7902a78d9730b63dd4407d2ef372e75699b893ed0110";
        } else if (height == 5) {
            typehash = hex"05822cbadb7ea3a6a9af719cb5ea171534eb980bbf35deda21ef899d8f45cbc0";
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
