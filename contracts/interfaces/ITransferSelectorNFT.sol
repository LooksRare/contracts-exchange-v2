// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title ITransferSelectorNFT
 * @author LooksRare protocol team (👀,💎)
 */
interface ITransferSelectorNFT {
    /**
     * @notice Custom struct that contains information about the transfer manager and function selector.
     * @param transferManager Address of the transfer manager
     * @param selector Function selector
     */
    struct ManagerSelector {
        address transferManager;
        bytes4 selector;
    }

    /**
     * @notice It is emitted if there is a new asset type added to the protocol.
     * @param assetType Asset type id
     * @param transferManager Address of the transfer manager
     * @param selector Function selector
     */
    event NewAssetType(uint256 assetType, address transferManager, bytes4 selector);

    /**
     * @notice It is returned if the contract is initialized.
     */
    error AlreadySet();

    /**
     * @notice It is returned if NFT transfer fails.
     * @param collection Collection address
     * @param assetType Asset type id
     */
    error NFTTransferFail(address collection, uint256 assetType);

    /**
     * @notice It is returned if there is no transfer manager for the asset type
     * @param assetType Asset type id
     */
    error NoTransferManagerForAssetType(uint256 assetType);
}
