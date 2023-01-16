// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Direct dependencies
import {ExecutionManager} from "./ExecutionManager.sol";
import {PackableReentrancyGuard} from "@looksrare/contracts-libs/contracts/PackableReentrancyGuard.sol";

// Interfaces
import {ITransferSelectorNFT} from "./interfaces/ITransferSelectorNFT.sol";

// Shared errors
import {WrongAssetType} from "./interfaces/SharedErrors.sol";

/**
 * @title TransferSelectorNFT
 * @notice This contract handles the logic for transferring non-fungible items.
 * @author LooksRare protocol team (👀,💎)
 */
contract TransferSelectorNFT is ITransferSelectorNFT, ExecutionManager, PackableReentrancyGuard {
    /**
     * @notice Transfer manager for ERC721 and ERC1155.
     */
    address public transferManager;

    /**
     * @notice Constructor
     * @param _owner Owner address
     * @param _transferManager Address of the transfer manager for ERC721/ERC1155
     */
    constructor(address _owner, address _transferManager) ExecutionManager(_owner) {
        transferManager = _transferManager;
    }

    /**
     * @notice This function is internal and used to transfer non-fungible tokens.
     * @param collection Collection address
     * @param assetType Asset type (e.g. 0 = ERC721, 1 = ERC1155)
     * @param sender Sender address
     * @param recipient Recipient address
     * @param itemIds Array of itemIds
     * @param amounts Array of amounts
     */
    function _transferNFT(
        address collection,
        uint256 assetType,
        address sender,
        address recipient,
        uint256[] memory itemIds,
        uint256[] memory amounts
    ) internal {
        bool status;

        if (assetType == 0) {
            (status, ) = transferManager.call(
                abi.encodeWithSelector(0xa7bc96d3, collection, sender, recipient, itemIds, amounts)
            );
        } else if (assetType == 1) {
            (status, ) = transferManager.call(
                abi.encodeWithSelector(0xa0a406c6, collection, sender, recipient, itemIds, amounts)
            );
        } else {
            revert WrongAssetType(assetType);
        }

        if (!status) {
            revert NFTTransferFail(collection, assetType);
        }
    }
}
