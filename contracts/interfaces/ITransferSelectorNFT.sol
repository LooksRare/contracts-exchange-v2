// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

interface ITransferSelectorNFT {
    error AlreadySet();
    error NFTTransferFail(address collection, uint8 assetType);
    error NoTransferManagerForAssetType(uint8 assetType);
    error WrongAssetType(uint8 assetType);
    event NewAssetType(uint8 assetType, address transferManager, bytes4 selector);

    struct ManagerSelector {
        address transferManager;
        bytes4 selector;
    }
}
