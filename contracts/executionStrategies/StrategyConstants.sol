// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/*
 * @dev error OrderInvalid()
 *      Memory layout:
 *        - 0x00: Left-padded selector (data begins at 0x1c)
 *      Revert buffer is memory[0x1c:0x20]
 */
uint256 constant OrderInvalid_error_selector = 0x2e0c0f71;
uint256 constant OrderInvalid_error_length = 0x04;
uint256 constant Error_selector_offset = 0x1c;

uint256 constant OneWord = 0x20;
