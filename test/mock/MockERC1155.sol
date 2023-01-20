// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7;

import {ERC1155} from "solmate/src/tokens/ERC1155.sol";

contract MockERC1155 is ERC1155 {
    function batchMint(address to, uint256[] memory tokenIds, uint256[] memory amounts) public {
        _batchMint(to, tokenIds, amounts, "");
    }

    function mint(address to, uint256 tokenId, uint256 amount) public {
        _mint(to, tokenId, amount, "");
    }

    function uri(uint256) public pure override returns (string memory) {
        return "uri";
    }
}
