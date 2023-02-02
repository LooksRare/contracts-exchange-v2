// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @notice It is emitted if the itemId is reported as flagged.
 */
error ItemIdFlagged(address collection, uint256 itemId);

/**
 * @notice It is emitted if the itemId was transferred too recently.
 */
error ItemTransferredTooRecently(address collection, uint256 itemId);

/**
 * @notice It is emitted if the itemId was never transferred.
 * @dev It indicates that the signature was generated with incorrect data.
 */
error LastTransferTimeInvalid();

/**
 * @notice It is emitted if the recovered message id is not matching the expected message id.
 * @dev For instance, it is emitted if the itemId is not the same itemId from the message.
 */
error MessageIdInvalid();

/**
 * @notice It is emitted if the signature from the Reservoir's offchain oracle has expired.
 */
error SignatureTimestampExpired();
