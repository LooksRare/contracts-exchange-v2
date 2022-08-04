// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import {IERC165} from "@looksrare/contracts-libs/contracts/interfaces/IERC165.sol";
import {IERC2981} from "@looksrare/contracts-libs/contracts/interfaces/IERC2981.sol";
import {OwnableTwoSteps} from "@looksrare/contracts-libs/contracts/OwnableTwoSteps.sol";

import {ITransferManager} from "./interfaces/ITransferManager.sol";
import {IERC721} from "./interfaces/IERC721.sol";
import {IERC1155} from "./interfaces/IERC1155.sol";

/**
 * @title TransferManager
 * @notice Core functions of TransferManager contracts for ERC721/ERC1155.
 * @dev Asset type "0" refers to ERC721 transfer functions. Asset type "1" refers to ERC1155 transfer functions.
 * "Safe" transfer functions for ERC721 are not implemented since they introduce added costs to verify if the recipient is a contract that it implements the receiver interface.
 * @author LooksRare protocol team (👀,💎)
 */
contract TransferManager is ITransferManager, OwnableTwoSteps {
    // Whether user has approved operator
    mapping(address => mapping(address => bool)) internal _hasUserApprovedOperator;

    // Whether the operator is in the whitelist
    mapping(address => bool) internal _whitelistedOperators;

    /**
     * @notice Transfer a single item
     * @param collection collection address
     * @param assetType asset type (0 for ERC721, 1 for ERC1155)
     * @param from sender address
     * @param to recipient address
     * @param itemId itemId
     * @param amount amount (it is not used for ERC721)
     */
    function transferSingleItem(
        address collection,
        uint8 assetType,
        address from,
        address to,
        uint256 itemId,
        uint256 amount
    ) external override {
        if (!_isDelegatedTransferValid(from, msg.sender)) {
            revert TransferCallerInvalid();
        }

        if (assetType == 0) {
            _executeERC721Transfer(collection, from, to, itemId);
        } else if (assetType == 1) {
            _executeERC1155Transfer(collection, from, to, itemId, amount);
        } else {
            revert WrongAssetType(assetType);
        }
    }

    /**
     * @notice Transfer batch items in the same collection
     * @param collection collection address
     * @param assetType asset type (0 for ERC721, 1 for ERC1155)
     * @param from sender address
     * @param to recipient address
     * @param itemIds array of itemIds
     * @param amounts array of amounts (it is not used for ERC721)
     */
    function transferBatchItems(
        address collection,
        uint8 assetType,
        address from,
        address to,
        uint256[] calldata itemIds,
        uint256[] calldata amounts
    ) external override {
        if (itemIds.length == 0 || itemIds.length != amounts.length) {
            revert WrongLengths();
        }

        if (from != msg.sender && !_isDelegatedTransferValid(from, msg.sender)) {
            revert TransferCallerInvalid();
        }

        if (assetType == 0) {
            for (uint256 i; i < amounts.length; ) {
                _executeERC721Transfer(collection, from, to, itemIds[i]);
                unchecked {
                    ++i;
                }
            }
        } else if (assetType == 1) {
            _executeERC1155BatchTransfer(collection, from, to, itemIds, amounts);
        } else {
            revert WrongAssetType(assetType);
        }
    }

    /**
     * @notice Transfer batch items across collections
     * @param collections array of collection addresses
     * @param assetTypes array of asset types
     * @param from sender address
     * @param to recipient address
     * @param itemIds array of array of itemIds
     * @param amounts array of array of amounts
     */
    function transferBatchItemsAcrossCollections(
        address[] calldata collections,
        uint8[] calldata assetTypes,
        address from,
        address to,
        uint256[][] calldata itemIds,
        uint256[][] calldata amounts
    ) external override {
        if (
            itemIds.length == 0 ||
            itemIds.length != assetTypes.length ||
            itemIds.length != collections.length ||
            itemIds.length != amounts.length
        ) {
            revert WrongLengths();
        }

        if (from != msg.sender && !_isDelegatedTransferValid(from, msg.sender)) {
            revert TransferCallerInvalid();
        }

        for (uint256 i; i < collections.length; ) {
            if (itemIds[i].length == 0 || itemIds[i].length != amounts[i].length) {
                revert WrongLengths();
            }

            if (assetTypes[i] == 0) {
                for (uint256 j; j < amounts[i].length; ) {
                    _executeERC721Transfer(collections[i], from, to, itemIds[i][j]);
                    unchecked {
                        ++j;
                    }
                }
            } else if (assetTypes[i] == 1) {
                _executeERC1155BatchTransfer(collections[i], from, to, itemIds[i], amounts[i]);
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
     * @param operators array of operator addresses
     * @dev Each operator address must be globally whitelisted to be approved.
     */
    function grantApprovals(address[] calldata operators) external {
        if (operators.length == 0) {
            revert WrongLengths();
        }

        for (uint256 i; i < operators.length; ) {
            if (!_whitelistedOperators[operators[i]]) {
                revert NotWhitelisted();
            }

            if (_hasUserApprovedOperator[msg.sender][operators[i]]) {
                revert AlreadyApproved();
            }

            _hasUserApprovedOperator[msg.sender][operators[i]] = true;

            unchecked {
                ++i;
            }
        }

        emit ApprovalsGranted(msg.sender, operators);
    }

    /**
     * @notice Revoke all approvals for the sender
     * @param operators array of operator addresses
     * @dev Each operator address must be approved at the user level to be revoked.
     */
    function revokeApprovals(address[] calldata operators) external {
        if (operators.length == 0) {
            revert WrongLengths();
        }

        for (uint256 i; i < operators.length; ) {
            if (!_hasUserApprovedOperator[msg.sender][operators[i]]) {
                revert NotApproved();
            }

            delete _hasUserApprovedOperator[msg.sender][operators[i]];
            unchecked {
                ++i;
            }
        }

        emit ApprovalsRemoved(msg.sender, operators);
    }

    /**
     * @notice Whitelist an operator in the system
     * @param operator address of the operator to add
     */
    function whitelistOperator(address operator) external onlyOwner {
        if (_whitelistedOperators[operator]) {
            revert AlreadyWhitelisted();
        }

        _whitelistedOperators[operator] = true;

        emit OperatorWhitelisted(operator);
    }

    /**
     * @notice Remove an operator from the system
     * @param operator address of the operator to remove
     */
    function removeOperator(address operator) external onlyOwner {
        if (!_whitelistedOperators[operator]) {
            revert NotWhitelisted();
        }

        delete _whitelistedOperators[operator];

        emit OperatorRemoved(operator);
    }

    /**
     * @notice Check whether delegated transfer (by an operator) is valid
     * @param user address of the user
     * @param operator address of the operator
     */
    function _isDelegatedTransferValid(address user, address operator) internal view returns (bool) {
        return _whitelistedOperators[operator] && _hasUserApprovedOperator[user][operator];
    }

    /**
     * @notice Execute ERC721 transfer
     * @param collection collection address
     * @param from sender address
     * @param to recipient address
     * @param itemId tokenId
     */
    function _executeERC721Transfer(
        address collection,
        address from,
        address to,
        uint256 itemId
    ) internal {
        IERC721(collection).transferFrom(from, to, itemId);
    }

    /**
     * @notice Execute ERC1155 transfer of single item for a defined amount
     * @param collection collection address
     * @param from sender address
     * @param to recipient address
     * @param itemId tokenId
     * @param amount amount
     */
    function _executeERC1155Transfer(
        address collection,
        address from,
        address to,
        uint256 itemId,
        uint256 amount
    ) internal {
        IERC1155(collection).safeTransferFrom(from, to, itemId, amount, "");
    }

    /**
     * @notice Execute ERC1155 batch transfer of multiple items for a defined set of amounts
     * @param collection collection address
     * @param from sender address
     * @param to recipient address
     * @param itemIds array of tokenIds
     * @param amounts array of amounts
     */
    function _executeERC1155BatchTransfer(
        address collection,
        address from,
        address to,
        uint256[] calldata itemIds,
        uint256[] calldata amounts
    ) internal {
        IERC1155(collection).safeBatchTransferFrom(from, to, itemIds, amounts, "");
    }
}
