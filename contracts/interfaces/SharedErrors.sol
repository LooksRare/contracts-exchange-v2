// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @notice Ask price is too high for the bid user.
 */
error AskTooHigh();

/**
 * @notice Bid price is too low for the ask user.
 */
error BidTooLow();

/**
 * @notice Function selector is invalid for this strategy implementation.
 *         It cannot be used for this operation.
 */
error FunctionSelectorInvalid();

/**
 * @notice It is emitted if the merkle tree proof's length is greater than tolerated.
 */
error MerkleProofTooLarge(uint256 length);

/**
 * @notice The order is invalid. There may be an issue with the order formatting.
 */
error OrderInvalid();

/**
 * @notice It is returned if the asset type is not 0, nor 1.
 * @param assetType Asset type
 */
error WrongAssetType(uint256 assetType);

/**
 * @notice This function cannot be called by the sender.
 */
error WrongCaller();

/**
 * @notice The currency is invalid.
 */
error WrongCurrency();

/**
 * @notice The function selector is not implemented.
 */
error WrongFunctionSelector();

/**
 * @notice There is either a mismatch or an error in the length of the array(s).
 */
error WrongLengths();

/**
 * @notice It is returned if the Merkle Proof is incorrect
 */
error WrongMerkleProof();
