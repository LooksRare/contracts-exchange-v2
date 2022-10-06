// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import {OrderStructs} from "../libraries/OrderStructs.sol";

/**
 * @title ITransferManager
 * @notice Contains core functions of transfer manager contract.
 * @dev Asset type "0" refers to ERC721 transfer functions. Asset type "1" refers to ERC1155 transfer functions.
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
