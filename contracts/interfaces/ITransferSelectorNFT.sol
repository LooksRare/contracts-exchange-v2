// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Libraries
import {OrderStructs} from "../libraries/OrderStructs.sol";

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
    error NFTTransferFail(address collection, OrderStructs.AssetType assetType);

    /**
     * @notice It is returned if there is no transfer manager for the asset type.
     * @param assetType Asset type id
     */
    error NoTransferManagerForAssetType(OrderStructs.AssetType assetType);
}
