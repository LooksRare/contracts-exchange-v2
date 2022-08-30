// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC721} from "@rari-capital/solmate/src/tokens/ERC721.sol";
import {IERC165, IERC2981} from "@looksrare/contracts-libs/contracts/interfaces/IERC2981.sol";

contract MockERC721WithRoyalty is ERC721, IERC2981 {
    address public immutable RECEIVER;
    uint256 public immutable ROYALTY_FEE;

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _royaltyFee
    ) ERC721(_name, _symbol) {
        ROYALTY_FEE = _royaltyFee;
        RECEIVER = msg.sender;
    }

    function mint(address to, uint256 tokenId) public {
        _mint(to, tokenId);
    }

    function royaltyInfo(uint256, uint256 salePrice)
        external
        view
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        return (RECEIVER, (ROYALTY_FEE * salePrice) / 10000);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, IERC165) returns (bool) {
        return interfaceId == 0x2a55205a || super.supportsInterface(interfaceId);
    }

    function tokenURI(uint256) public pure override returns (string memory) {
        return "tokenURI";
    }
}
