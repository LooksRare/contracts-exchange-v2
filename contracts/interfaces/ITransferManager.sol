// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title ITransferManager
 * @author LooksRare protocol team (👀,💎)
 */
interface ITransferManager {
    // Custom errors
    error AlreadyApproved();
    error AlreadyWhitelisted();
    error NotApproved();
    error NotWhitelisted();
    error TransferCallerInvalid();
    error WrongAssetType(uint8 assetType);
    error WrongLengths();

    // Events
    event ApprovalsGranted(address user, address[] operators);
    event ApprovalsRemoved(address user, address[] operators);
    event OperatorRemoved(address operator);
    event OperatorWhitelisted(address operator);
}
