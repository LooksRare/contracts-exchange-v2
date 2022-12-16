// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// 0. No error
uint256 constant ORDER_EXPECTED_TO_BE_VALID = 0;

// 1. Nonce-related errors
uint256 constant USER_SUBSET_NONCE_CANCELLED = 101; // OK
uint256 constant USER_ORDER_NONCE_EXECUTED_OR_CANCELLED = 111; // OK
uint256 constant USER_ORDER_NONCE_IN_EXECUTION_WITH_OTHER_HASH = 112; // OK
uint256 constant USER_GLOBAL_BID_NONCE_HIGHER = 121; // ok
uint256 constant USER_GLOBAL_BID_NONCE_LOWER = 122; // OK
uint256 constant USER_GLOBAL_ASK_NONCE_HIGHER = 123; // OK
uint256 constant USER_GLOBAL_ASK_NONCE_LOWER = 124; // OK

// 2. Error codes related to signatures (EOA, EIP-1271) and Merkle Tree computations
uint256 constant ORDER_HASH_PROOF_NOT_IN_MERKLE_TREE = 201;
uint256 constant WRONG_SIGNATURE_LENGTH = 211; // OK
uint256 constant INVALID_S_PARAMETER_EOA = 212; // OK
uint256 constant INVALID_V_PARAMETER_EOA = 213; // OK
uint256 constant NULL_SIGNER_EOA = 214; // OK
uint256 constant WRONG_SIGNER_EOA = 215; // OK
uint256 constant MISSING_IS_VALID_SIGNATURE_FUNCTION_EIP1271 = 221; // OK
uint256 constant SIGNATURE_INVALID_EIP1271 = 222; // OK

// 3. Strategy & currency-related errors
uint256 constant CURRENCY_NOT_WHITELISTED = 301; // OK
uint256 constant STRATEGY_NOT_IMPLEMENTED = 311; // OK
uint256 constant STRATEGY_TAKER_BID_SELECTOR_INVALID = 312; // OK
uint256 constant STRATEGY_TAKER_ASK_SELECTOR_INVALID = 313; // OK
uint256 constant STRATEGY_NOT_ACTIVE = 314; // OK

// 4. Timestamp-related validation errors
uint256 constant TOO_LATE_TO_EXECUTE_ORDER = 401; // OK
uint256 constant TOO_EARLY_TO_EXECUTE_ORDER = 402; // OK

// 5. Transfer-related (ERC20, ERC721, ERC1155 tokens), including transfers and approvals, errors
uint256 constant SAME_ITEM_ID_IN_BUNDLE = 502; // OK
uint256 constant ERC20_BALANCE_INFERIOR_TO_PRICE = 511; // OK
uint256 constant ERC20_APPROVAL_INFERIOR_TO_PRICE = 512; // OK
uint256 constant ERC721_ITEM_ID_DOES_NOT_EXIST = 521; // OK
uint256 constant ERC721_ITEM_ID_NOT_IN_BALANCE = 522; // OK
uint256 constant ERC721_NO_APPROVAL_FOR_ALL_OR_ITEM_ID = 523; // OK
uint256 constant ERC1155_BALANCE_OF_DOES_NOT_EXIST = 531; // OK
uint256 constant ERC1155_BALANCE_OF_ITEM_ID_INFERIOR_TO_AMOUNT = 532; // OK
uint256 constant ERC1155_IS_APPROVED_FOR_ALL_DOES_NOT_EXIST = 533; // OK
uint256 constant ERC1155_NO_APPROVAL_FOR_ALL = 534; // OK

// 6. Asset-type suggestion
uint256 constant POTENTIAL_WRONG_ASSET_TYPE_SHOULD_BE_ERC721 = 701; // OK
uint256 constant POTENTIAL_WRONG_ASSET_TYPE_SHOULD_BE_ERC1155 = 702; // OK
uint256 constant ASSET_TYPE_NOT_SUPPORTED = 711; // OK

// 7. Transfer manager-related
uint256 constant NO_TRANSFER_MANAGER_APPROVAL_BY_USER_FOR_EXCHANGE = 611; // OK
uint256 constant TRANSFER_MANAGER_APPROVAL_REVOKED_BY_OWNER_FOR_EXCHANGE = 612; // OK

// 8. Maker order struct-related errors
uint256 constant MAKER_ORDER_INVALID_STANDARD_SALE = 801; // OK
uint256 constant MAKER_ORDER_INVALID_NON_STANDARD_SALE = 802; // OK

// 9. Creator fee-related errors
uint256 constant BUNDLE_ERC2981_NOT_SUPPORTED = 901;
uint256 constant CREATOR_FEE_TOO_HIGH = 902;
