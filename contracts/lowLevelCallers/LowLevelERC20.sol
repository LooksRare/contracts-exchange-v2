// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import {IERC20} from "../interfaces/IERC20.sol";

/**
 * @title LowLevelERC20
 * @notice This contract contains low-level calls to transfer ERC20 tokens.
 * @author LooksRare protocol team (👀,💎)
 */
contract LowLevelERC20 {
    error TransferERC20Fail();

    /**
     * @notice Execute ERC20 Transfer
     * @param currency address of the currency
     * @param from address of the sender
     * @param to address of the recipient
     * @param amount amount to transfer
     */
    function _executeERC20Transfer(
        address currency,
        address from,
        address to,
        uint256 amount
    ) internal {
        (bool status, bytes memory data) = currency.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );

        if (!status) {
            revert TransferERC20Fail();
        }

        if (data.length != 0 && data.length >= 32) {
            if (!abi.decode(data, (bool))) {
                revert TransferERC20Fail();
            }
        }
    }
}
