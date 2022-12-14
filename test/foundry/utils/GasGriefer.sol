// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract GasGriefer {
    receive() external payable {
        uint256 count;
        while (true) {
            count += 1;
        }
    }

    function isValidSignature(bytes32, bytes memory) external pure returns (bytes4 magicValue) {
        magicValue = this.isValidSignature.selector;
    }
}
