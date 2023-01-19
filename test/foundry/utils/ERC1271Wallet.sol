// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC1271WalletMock} from "openzeppelin-contracts/contracts/mocks/ERC1271WalletMock.sol";

contract ERC1271Wallet is ERC1271WalletMock {
    constructor(address originalOwner) ERC1271WalletMock(originalOwner) {}

    function onERC1155Received(address, address, uint256, uint256, bytes memory) external pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }
}
