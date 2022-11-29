// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

uint256 constant ORDER_EXPECTED_TO_BE_VALID = 0;
uint256 constant USER_GLOBAL_BID_NONCE_HIGHER = 101;
uint256 constant USER_GLOBAL_BID_NONCE_LOWER = 102;
uint256 constant USER_GLOBAL_ASK_NONCE_HIGHER = 103;
uint256 constant USER_GLOBAL_ASK_NONCE_LOWER = 104;
uint256 constant USER_SUBSET_NONCE_CANCELLED = 111;
uint256 constant USER_ORDER_NONCE_EXECUTED_OR_CANCELLED = 121;
uint256 constant USER_ORDER_NONCE_IN_EXECUTION_WITH_OTHER_HASH = 122;
uint256 constant ORDER_AMOUNT_CANNOT_BE_ZERO = 201;
uint256 constant MAKER_SIGNER_IS_NULL_SIGNER = 301;
uint256 constant INVALID_S_PARAMETER_EOA = 302;
uint256 constant INVALID_V_PARAMETER_EOA = 303;
uint256 constant NULL_SIGNER_EOA = 304;
uint256 constant WRONG_SIGNER_EOA = 305;
uint256 constant SIGNATURE_INVALID_EIP1271 = 311;
uint256 constant MISSING_IS_VALID_SIGNATURE_FUNCTION_EIP1271 = 312;
uint256 constant CURRENCY_NOT_WHITELISTED = 401;
uint256 constant STRATEGY_NOT_IMPLEMENTED = 411;
uint256 constant STRATEGY_TAKER_BID_SELECTOR_INVALID = 412;
uint256 constant STRATEGY_TAKER_ASK_SELECTOR_INVALID = 413;
uint256 constant STRATEGY_NOT_ACTIVE = 413;
uint256 constant TOO_LATE_TO_EXECUTE_ORDER = 601;
uint256 constant TOO_EARLY_TO_EXECUTE_ORDER = 602;
uint256 constant NO_TRANSFER_MANAGER_SELECTOR = 701;
uint256 constant SAME_ITEM_ID_IN_BUNDLE = 702;
uint256 constant ERC20_BALANCE_INFERIOR_TO_PRICE = 711;
uint256 constant ERC20_APPROVAL_INFERIOR_TO_PRICE = 712;
uint256 constant ERC721_ITEM_ID_DOES_NOT_EXIST = 721;
uint256 constant ERC721_ITEM_ID_NOT_IN_BALANCE = 722;
uint256 constant ERC721_NO_APPROVAL_FOR_ALL_OR_ITEM_ID = 723;
uint256 constant ERC1155_BALANCE_OF_DOES_NOT_EXIST = 731;
uint256 constant ERC1155_BALANCE_OF_ITEM_ID_INFERIOR_TO_AMOUNT = 732;
uint256 constant ERC1155_IS_APPROVED_FOR_ALL_DOES_NOT_EXIST = 733;
uint256 constant ERC1155_NO_APPROVAL_FOR_ALL = 734;