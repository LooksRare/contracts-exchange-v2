// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7;

import {IERC165} from "@looksrare/contracts-libs/contracts/interfaces/IERC165.sol";
import {ERC721} from "@rari-capital/solmate/src/tokens/ERC721.sol";

contract MockERC721 is ERC721("MockERC721", "MockERC721") {
    function mint(address to, uint256 tokenId) public {
        _mint(to, tokenId);
    }

    function batchMint(address to, uint256[] memory tokenIds) public {
        for (uint256 i; i < tokenIds.length; i++) {
            _mint(to, tokenIds[i]);
        }
    }

    function tokenURI(uint256) public pure override returns (string memory) {
        return "tokenURI";
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
