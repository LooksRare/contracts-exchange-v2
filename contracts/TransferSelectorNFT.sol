// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Direct dependencies
import {PackableReentrancyGuard} from "@looksrare/contracts-libs/contracts/PackableReentrancyGuard.sol";
import {ExecutionManager} from "./ExecutionManager.sol";
import {TransferManager} from "./TransferManager.sol";

// Interfaces
import {ITransferSelectorNFT} from "./interfaces/ITransferSelectorNFT.sol";

// Shared errors
import {WrongAssetType} from "./errors/SharedErrors.sol";

// Constants
import {ASSET_TYPE_ERC721, ASSET_TYPE_ERC1155} from "./constants/NumericConstants.sol";

/**
 * @title TransferSelectorNFT
 * @notice This contract handles the logic for transferring non-fungible items.
 * @author LooksRare protocol team (👀,💎)
 */
contract TransferSelectorNFT is ITransferSelectorNFT, ExecutionManager, PackableReentrancyGuard {
    /**
     * @notice Transfer manager for ERC721 and ERC1155.
     */
    TransferManager public immutable transferManager;

    /**
     * @notice Constructor
     * @param _owner Owner address
     * @param _protocolFeeRecipient Protocol fee recipient address
     * @param _transferManager Address of the transfer manager for ERC721/ERC1155
     */
    constructor(
        address _owner,
        address _protocolFeeRecipient,
        address _transferManager
    ) ExecutionManager(_owner, _protocolFeeRecipient) {
        transferManager = TransferManager(_transferManager);
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
        if (assetType == ASSET_TYPE_ERC721) {
            transferManager.transferItemsERC721(collection, sender, recipient, itemIds, amounts);
        } else if (assetType == ASSET_TYPE_ERC1155) {
            transferManager.transferItemsERC1155(collection, sender, recipient, itemIds, amounts);
        } else {
            revert WrongAssetType(assetType);
        }
    }
}
