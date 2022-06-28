// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import {OrderStructs} from "../libraries/OrderStructs.sol";

/**
 * @title ITransferManager
 * @notice Contains core functions of transfer manager contract.
 * @dev Asset type "0" refers to ERC721 transfer functions. Asset type "1" refers to ERC1155 transfer functions.
 * @author LooksRare protocol team (👀,💎)
 */
interface ITransferManager {
    /**
     * @notice Transfer a single item
     * @param collection collection address
     * @param assetType asset type (0 for ERC721, 1 for ERC1155)
     * @param from sender address
     * @param to recipient address
     * @param itemId itemId
     * @param amount amount (it is not used for ERC721)
     */
    function transferSingleItem(
        address collection,
        uint8 assetType,
        address from,
        address to,
        uint256 itemId,
        uint256 amount
    ) external;

    /**
     * @notice Transfer batch items in the same collection
     * @param collection collection address
     * @param assetType asset type (0 for ERC721, 1 for ERC1155)
     * @param from sender address
     * @param to recipient address
     * @param itemIds array of itemIds
     * @param amounts array of amounts (it is not used for ERC721)
     */
    function transferBatchItems(
        address collection,
        uint8 assetType,
        address from,
        address to,
        uint256[] calldata itemIds,
        uint256[] calldata amounts
    ) external;

    /**
     * @notice Transfer batch items across collections
     * @param collections array of collection addresses
     * @param assetTypes array of asset types
     * @param from sender address
     * @param to recipient address
     * @param itemIds array of array of itemIds
     * @param amounts array of array of amounts
     */
    function transferBatchItemsAcrossCollections(
        address[] calldata collections,
        uint8[] calldata assetTypes,
        address from,
        address to,
        uint256[][] calldata itemIds,
        uint256[][] calldata amounts
    ) external;
}
