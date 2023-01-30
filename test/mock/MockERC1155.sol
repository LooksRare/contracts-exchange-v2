// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7;

import {ERC1155} from "solmate/src/tokens/ERC1155.sol";

// LooksRare unopinionated libraries
import {IERC2981} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC2981.sol";

contract MockERC1155 is ERC1155 {
    bool private revertBalanceOfBatch;

    function batchMint(address to, uint256[] memory tokenIds, uint256[] memory amounts) public {
        _batchMint(to, tokenIds, amounts, "");
    }

    function mint(address to, uint256 tokenId, uint256 amount) public {
        _mint(to, tokenId, amount, "");
    }

    function uri(uint256) public pure override returns (string memory) {
        return "uri";
    }

    function balanceOfBatch(
        address[] calldata owners,
        uint256[] calldata ids
    ) public view override returns (uint256[] memory) {
        if (revertBalanceOfBatch) {
            revert("revertBalanceOfBatch");
        } else {
            return super.balanceOfBatch(owners, ids);
        }
    }

    function setRevertBalanceOfBatch(bool _revertBalanceOfBatch) external {
        revertBalanceOfBatch = _revertBalanceOfBatch;
    }

    function royaltyInfo(uint256, uint256) external pure returns (address, uint256) {
        return (address(0), 0);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC2981).interfaceId || super.supportsInterface(interfaceId);
    }
}
