// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC721} from "@rari-capital/solmate/src/tokens/ERC721.sol";
import {IERC165, IERC2981} from "@looksrare/contracts-libs/contracts/interfaces/IERC2981.sol";

contract MockERC721WithRoyalties is ERC721, IERC2981 {
    address public immutable RECIPIENT;
    uint256 public immutable ROYALTY_FEE;

    mapping(uint256 => uint256) internal _royaltyFeeForTokenId;
    mapping(uint256 => address) internal _royaltyRecipientForTokenId;

    constructor(address _royaltyFeeRECIPIENT, uint256 _royaltyFee) ERC721("MockERC721", "MockERC721") {
        RECIPIENT = _royaltyFeeRECIPIENT;
        ROYALTY_FEE = _royaltyFee;
    }

    function addCustomRoyaltyInformationForTokenId(
        uint256 tokenId,
        address royaltyRecipient,
        uint256 royaltyFee
    ) external {
        require(royaltyFee <= 10000, "Royalty too high");
        _royaltyRecipientForTokenId[tokenId] = royaltyRecipient;
        _royaltyFeeForTokenId[tokenId] = royaltyFee;
    }

    function mint(address to, uint256 tokenId) public {
        _mint(to, tokenId);
    }

    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        override
        returns (address royaltyRecipient, uint256 royaltyAmount)
    {
        address recipient = _royaltyRecipientForTokenId[tokenId] == address(0)
            ? RECIPIENT
            : _royaltyRecipientForTokenId[tokenId];
        uint256 royaltyFee = _royaltyFeeForTokenId[tokenId] == 0 ? ROYALTY_FEE : _royaltyFeeForTokenId[tokenId];
        return (recipient, (royaltyFee * salePrice) / 10000);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, IERC165) returns (bool) {
        return interfaceId == 0x2a55205a || super.supportsInterface(interfaceId);
    }

    function tokenURI(uint256) public pure override returns (string memory) {
        return "tokenURI";
    }
}
