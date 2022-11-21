// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// LooksRare unopinionated libraries
import {OwnableTwoSteps} from "@looksrare/contracts-libs/contracts/OwnableTwoSteps.sol";
import {LowLevelERC721Transfer} from "@looksrare/contracts-libs/contracts/lowLevelCallers/LowLevelERC721Transfer.sol";
import {LowLevelERC1155Transfer} from "@looksrare/contracts-libs/contracts/lowLevelCallers/LowLevelERC1155Transfer.sol";
import {IERC165} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC165.sol";
import {IERC721} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC721.sol";
import {IERC1155} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC1155.sol";

// Interfaces
import {ITransferManager} from "./interfaces/ITransferManager.sol";

/**
 * @title TransferManager
 * @notice Core functions of TransferManager contracts for ERC721/ERC1155.
 *         Asset type "0" refers to ERC721 transfer functions.
 *         Asset type "1" refers to ERC1155 transfer functions.
 *         "Safe" transfer functions for ERC721 are not implemented; these functions introduce added gas costs to verify if the recipient is a contract as it requires verifying the receiver interface is valid.
 * @author LooksRare protocol team (👀,💎)
 */
contract TransferManager is ITransferManager, LowLevelERC721Transfer, LowLevelERC1155Transfer, OwnableTwoSteps {
    // Whether the user has approved the operator address (first address is user, second address is operator)
    mapping(address => mapping(address => bool)) public hasUserApprovedOperator;

    // Whether the operator address is whitelisted
    mapping(address => bool) public isOperatorWhitelisted;

    /**
     * @notice Transfer items for ERC721 collection
     * @param collection Collection address
     * @param from Sender address
     * @param to Recipient address
     * @param itemIds Array of itemIds
     */
    function transferItemsERC721(
        address collection,
        address from,
        address to,
        uint256[] calldata itemIds,
        uint256[] calldata
    ) external {
        uint256 length = itemIds.length;
        if (length == 0) revert WrongLengths();
        if (!isOperatorValidForTransfer(from, msg.sender)) revert TransferCallerInvalid();

        for (uint256 i; i < length; ) {
            _executeERC721TransferFrom(collection, from, to, itemIds[i]);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Transfer items for ERC1155 collection
     * @param collection Collection address
     * @param from Sender address
     * @param to Recipient address
     * @param itemIds Array of itemIds
     * @param amounts Array of amounts (it is not used for ERC721)
     * @dev It does not allow batch transferring if from = msg.sender since native function should be used.
     */
    function transferItemsERC1155(
        address collection,
        address from,
        address to,
        uint256[] calldata itemIds,
        uint256[] calldata amounts
    ) external {
        uint256 length = itemIds.length;
        if (length == 0 || amounts.length != length) revert WrongLengths();
        if (!isOperatorValidForTransfer(from, msg.sender)) revert TransferCallerInvalid();

        if (length == 1) {
            _executeERC1155SafeTransferFrom(collection, from, to, itemIds[0], amounts[0]);
        } else {
            _executeERC1155SafeBatchTransferFrom(collection, from, to, itemIds, amounts);
        }
    }

    /**
     * @notice Transfer batch items across collections
     * @param collections Array of collection addresses
     * @param assetTypes Array of asset types
     * @param from Sender address
     * @param to Recipient address
     * @param itemIds Array of array of itemIds
     * @param amounts Array of array of amounts
     * @dev If assetType for ERC721 is used, amounts aren't used.
     */
    function transferBatchItemsAcrossCollections(
        address[] calldata collections,
        uint8[] calldata assetTypes,
        address from,
        address to,
        uint256[][] calldata itemIds,
        uint256[][] calldata amounts
    ) external {
        uint256 collectionsLength = collections.length;

        if (
            collectionsLength == 0 ||
            itemIds.length != collectionsLength ||
            collections.length != collectionsLength ||
            amounts.length != collectionsLength
        ) revert WrongLengths();

        if (from != msg.sender) {
            if (!isOperatorValidForTransfer(from, msg.sender)) revert TransferCallerInvalid();
        }

        for (uint256 i; i < collectionsLength; ) {
            uint256 itemIdsLengthForSingleCollection = itemIds[i].length;
            if (itemIdsLengthForSingleCollection == 0 || amounts[i].length != itemIdsLengthForSingleCollection)
                revert WrongLengths();

            if (assetTypes[i] == 0) {
                for (uint256 j; j < itemIdsLengthForSingleCollection; ) {
                    _executeERC721TransferFrom(collections[i], from, to, itemIds[i][j]);
                    unchecked {
                        ++j;
                    }
                }
            } else if (assetTypes[i] == 1) {
                _executeERC1155SafeBatchTransferFrom(collections[i], from, to, itemIds[i], amounts[i]);
            } else {
                revert WrongAssetType(assetTypes[i]);
            }

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Grant approvals for list of operators on behalf of the sender
     * @param operators Array of operator addresses
     * @dev Each operator address must be globally whitelisted to be approved.
     */
    function grantApprovals(address[] calldata operators) external {
        if (operators.length == 0) revert WrongLengths();

        for (uint256 i; i < operators.length; ) {
            if (!isOperatorWhitelisted[operators[i]]) revert NotWhitelisted();
            if (hasUserApprovedOperator[msg.sender][operators[i]]) revert AlreadyApproved();

            hasUserApprovedOperator[msg.sender][operators[i]] = true;

            unchecked {
                ++i;
            }
        }

        emit ApprovalsGranted(msg.sender, operators);
    }

    /**
     * @notice Revoke all approvals for the sender
     * @param operators Array of operator addresses
     * @dev Each operator address must be approved at the user level to be revoked.
     */
    function revokeApprovals(address[] calldata operators) external {
        if (operators.length == 0) revert WrongLengths();

        for (uint256 i; i < operators.length; ) {
            if (!hasUserApprovedOperator[msg.sender][operators[i]]) revert NotApproved();

            delete hasUserApprovedOperator[msg.sender][operators[i]];
            unchecked {
                ++i;
            }
        }

        emit ApprovalsRemoved(msg.sender, operators);
    }

    /**
     * @notice Whitelist an operator in the system
     * @param operator Operator address to add
     */
    function whitelistOperator(address operator) external onlyOwner {
        if (isOperatorWhitelisted[operator]) revert AlreadyWhitelisted();

        isOperatorWhitelisted[operator] = true;

        emit OperatorWhitelisted(operator);
    }

    /**
     * @notice Remove an operator from the system
     * @param operator Operator address to remove
     */
    function removeOperator(address operator) external onlyOwner {
        if (!isOperatorWhitelisted[operator]) revert NotWhitelisted();

        delete isOperatorWhitelisted[operator];

        emit OperatorRemoved(operator);
    }

    /**
     * @notice Check (internally) whether transfer (by an operator) is valid
     * @param user User address
     * @param operator Operator address
     */
    function isOperatorValidForTransfer(address user, address operator) internal view returns (bool) {
        return isOperatorWhitelisted[operator] && hasUserApprovedOperator[user][operator];
    }
}
