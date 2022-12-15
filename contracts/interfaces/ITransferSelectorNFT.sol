// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title ITransferSelectorNFT
 * @author LooksRare protocol team (👀,💎)
 */

interface ITransferSelectorNFT {
    event NewAssetType(uint256 assetType, address transferManager, bytes4 selector);

    // Custom errors
    error AlreadySet();
    error NFTTransferFail(address collection, uint256 assetType);
    error NoTransferManagerForAssetType(uint256 assetType);
    error WrongAssetType(uint256 assetType);

    // Custom structs
    struct ManagerSelector {
        address transferManager;
        bytes4 selector;
    }
}
