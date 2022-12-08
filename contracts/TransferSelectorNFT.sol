// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// LooksRare unopinionated libraries
import {OwnableTwoSteps} from "@looksrare/contracts-libs/contracts/OwnableTwoSteps.sol";

// Interfaces
import {ITransferSelectorNFT} from "./interfaces/ITransferSelectorNFT.sol";

/**
 * @title TransferSelectorNFT
 * @notice This contract handles the logic for transferring items.
 * @author LooksRare protocol team (👀,💎)
 */
contract TransferSelectorNFT is ITransferSelectorNFT, OwnableTwoSteps {
    // Tracks manager address and associated selector to transfer asset type
    mapping(uint8 => ManagerSelector) public managerSelectorOfAssetType;

    /**
     * @notice Constructor
     */
    constructor(address transferManager) {
        // Transfer manager with selectors for ERC721/ERC1155
        managerSelectorOfAssetType[0] = ManagerSelector({transferManager: transferManager, selector: 0xa7bc96d3});
        managerSelectorOfAssetType[1] = ManagerSelector({transferManager: transferManager, selector: 0xa0a406c6});
    }

    /**
     * @notice Add transfer manager for new asset types
     * @param assetType Asset type
     * @param transferManagerForAssetType Transfer manager address for this asset type
     * @param selectorForAssetType Selector for the function to call to transfer this asset type
     */
    function addTransferManagerForAssetType(
        uint8 assetType,
        address transferManagerForAssetType,
        bytes4 selectorForAssetType
    ) external onlyOwner {
        if (managerSelectorOfAssetType[assetType].transferManager != address(0)) revert AlreadySet();

        managerSelectorOfAssetType[assetType] = ManagerSelector({
            transferManager: transferManagerForAssetType,
            selector: selectorForAssetType
        });

        emit NewAssetType(assetType, transferManagerForAssetType, selectorForAssetType);
    }

    /**
     * @notice Transfer non-fungible tokens
     * @param collection Collection address
     * @param assetType Asset type (e.g., 0 = ERC721, 1 = ERC1155)
     * @param sender Sender address
     * @param recipient Recipient address
     * @param itemIds Array of itemIds
     * @param amounts Array of amounts
     */
    function _transferNFT(
        address collection,
        uint8 assetType,
        address sender,
        address recipient,
        uint256[] memory itemIds,
        uint256[] memory amounts
    ) internal {
        address transferManager = managerSelectorOfAssetType[assetType].transferManager;
        bytes4 selector = managerSelectorOfAssetType[assetType].selector;

        if (transferManager == address(0) || selector == bytes4(0)) revert NoTransferManagerForAssetType(assetType);

        (bool status, ) = transferManager.call(
            abi.encodeWithSelector(selector, collection, sender, recipient, itemIds, amounts)
        );

        if (!status) revert NFTTransferFail(collection, assetType);
    }
}
