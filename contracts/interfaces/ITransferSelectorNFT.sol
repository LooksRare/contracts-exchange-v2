// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title ITransferSelectorNFT
 * @author LooksRare protocol team (👀,💎)
 */
interface ITransferSelectorNFT {
    /**
     * @notice It is returned if the NFT transfer fails.
     * @param collection Collection address
     * @param assetType Asset type id
     */
    error NFTTransferFail(address collection, uint256 assetType);

    /**
     * @notice It is returned if there is no transfer manager for the asset type.
     * @param assetType Asset type id
     */
    error NoTransferManagerForAssetType(uint256 assetType);
}
