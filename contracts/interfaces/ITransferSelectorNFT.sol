// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title ITransferSelectorNFT
 * @author LooksRare protocol team (👀,💎)
 */

interface ITransferSelectorNFT {
    // Custom errors
    error AlreadySet();
    error NFTTransferFail(address collection, uint8 assetType);
    event NewAssetType(uint8 assetType, address transferManager, bytes4 selector);
    error NoTransferManagerForAssetType(uint8 assetType);
    error WrongAssetType(uint8 assetType);

    // Custom structs
    struct ManagerSelector {
        address transferManager;
        bytes4 selector;
    }
}
