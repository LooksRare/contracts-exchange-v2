// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// LooksRare unopinionated libraries
import {OwnableTwoSteps} from "@looksrare/contracts-libs/contracts/OwnableTwoSteps.sol";
import {LowLevelERC721Transfer} from "@looksrare/contracts-libs/contracts/lowLevelCallers/LowLevelERC721Transfer.sol";
import {LowLevelERC1155Transfer} from "@looksrare/contracts-libs/contracts/lowLevelCallers/LowLevelERC1155Transfer.sol";

// Interfaces and errors
import {ITransferManager} from "./interfaces/ITransferManager.sol";
import {WrongAssetType, LengthsInvalid} from "./errors/SharedErrors.sol";

// Constants
import {ASSET_TYPE_ERC721, ASSET_TYPE_ERC1155} from "./constants/NumericConstants.sol";

/**
 * @title TransferManager
 * @notice This contract provides the transfer functions for ERC721/ERC1155 for contracts that require them.
 *         Asset type "0" refers to ERC721 transfer functions.
 *         Asset type "1" refers to ERC1155 transfer functions.
 * @dev "Safe" transfer functions for ERC721 are not implemented since they come with added gas costs
 *       to verify if the recipient is a contract as it requires verifying the receiver interface is valid.
 * @author LooksRare protocol team (👀,💎)
 */
contract TransferManager is ITransferManager, LowLevelERC721Transfer, LowLevelERC1155Transfer, OwnableTwoSteps {
    /**
     * @notice This returns whether the user has approved the operator address.
     * The first address is the user and the second address is the operator (e.g. LooksRareProtocol).
     */
    mapping(address => mapping(address => bool)) public hasUserApprovedOperator;

    /**
     * @notice This returns whether the operator address is whitelisted by this contract's owner.
     */
    mapping(address => bool) public isOperatorWhitelisted;

    /**
     * @notice Constructor
     * @param _owner Owner address
     */
    constructor(address _owner) OwnableTwoSteps(_owner) {}

    /**
     * @notice This function transfers items for a single ERC721 collection.
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
        if (length == 0) {
            revert LengthsInvalid();
        }

        _isOperatorValidForTransfer(from, msg.sender);

        for (uint256 i; i < length; ) {
            _executeERC721TransferFrom(collection, from, to, itemIds[i]);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice This function transfers items for a single ERC1155 collection.
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

        if (length == 0 || amounts.length != length) {
            revert LengthsInvalid();
        }

        _isOperatorValidForTransfer(from, msg.sender);

        if (length == 1) {
            _executeERC1155SafeTransferFrom(collection, from, to, itemIds[0], amounts[0]);
        } else {
            _executeERC1155SafeBatchTransferFrom(collection, from, to, itemIds, amounts);
        }
    }

    /**
     * @notice This function transfers items across an array of collections that can be both ERC721 and ERC1155.
     * @param items Array of BatchTransferItem
     * @param from Sender address
     * @param to Recipient address
     * @dev If assetType for ERC721 is used, amounts aren't used.
     */
    function transferBatchItemsAcrossCollections(
        BatchTransferItem[] calldata items,
        address from,
        address to
    ) external {
        uint256 itemsLength = items.length;

        if (itemsLength == 0) {
            revert LengthsInvalid();
        }

        if (from != msg.sender) {
            _isOperatorValidForTransfer(from, msg.sender);
        }

        for (uint256 i; i < itemsLength; ) {
            uint256 itemIdsLengthForSingleCollection = items[i].itemIds.length;
            if (itemIdsLengthForSingleCollection == 0 || items[i].amounts.length != itemIdsLengthForSingleCollection) {
                revert LengthsInvalid();
            }

            uint256 assetType = items[i].assetType;
            if (assetType == ASSET_TYPE_ERC721) {
                for (uint256 j; j < itemIdsLengthForSingleCollection; ) {
                    _executeERC721TransferFrom(items[i].collection, from, to, items[i].itemIds[j]);
                    unchecked {
                        ++j;
                    }
                }
            } else if (assetType == ASSET_TYPE_ERC1155) {
                _executeERC1155SafeBatchTransferFrom(items[i].collection, from, to, items[i].itemIds, items[i].amounts);
            } else {
                revert WrongAssetType(assetType);
            }

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice This function allows a user to grant approvals for an array of operators.
     *         Users cannot grant approvals if the operator is not whitelisted by this contract's owner.
     * @param operators Array of operator addresses
     * @dev Each operator address must be globally whitelisted to be approved.
     */
    function grantApprovals(address[] calldata operators) external {
        uint256 length = operators.length;

        if (length == 0) {
            revert LengthsInvalid();
        }

        for (uint256 i; i < length; ) {
            address operator = operators[i];

            if (!isOperatorWhitelisted[operator]) {
                revert NotWhitelisted();
            }

            if (hasUserApprovedOperator[msg.sender][operator]) {
                revert AlreadyApproved();
            }

            hasUserApprovedOperator[msg.sender][operator] = true;

            unchecked {
                ++i;
            }
        }

        emit ApprovalsGranted(msg.sender, operators);
    }

    /**
     * @notice This function allows a user to revoke existing approvals for an array of operators.
     * @param operators Array of operator addresses
     * @dev Each operator address must be approved at the user level to be revoked.
     */
    function revokeApprovals(address[] calldata operators) external {
        uint256 length = operators.length;
        if (length == 0) {
            revert LengthsInvalid();
        }

        for (uint256 i; i < length; ) {
            address operator = operators[i];

            if (!hasUserApprovedOperator[msg.sender][operator]) {
                revert NotApproved();
            }

            delete hasUserApprovedOperator[msg.sender][operator];
            unchecked {
                ++i;
            }
        }

        emit ApprovalsRemoved(msg.sender, operators);
    }

    /**
     * @notice This function allows the user to whitelist an operator in this transfer system.
     * @param operator Operator address to add
     * @dev Only callable by owner.
     */
    function whitelistOperator(address operator) external onlyOwner {
        if (isOperatorWhitelisted[operator]) {
            revert AlreadyWhitelisted();
        }

        isOperatorWhitelisted[operator] = true;

        emit OperatorWhitelisted(operator);
    }

    /**
     * @notice This function allows the user to remove an operator in this transfer system.
     * @param operator Operator address to remove
     * @dev Only callable by owner.
     */
    function removeOperator(address operator) external onlyOwner {
        if (!isOperatorWhitelisted[operator]) {
            revert NotWhitelisted();
        }

        delete isOperatorWhitelisted[operator];

        emit OperatorRemoved(operator);
    }

    /**
     * @notice This function is internal and verifies whether the transfer
     *         (by an operator on behalf of a user) is valid. If not, it reverts.
     * @param user User address
     * @param operator Operator address
     */
    function _isOperatorValidForTransfer(address user, address operator) private view {
        if (isOperatorWhitelisted[operator] && hasUserApprovedOperator[user][operator]) {
            return;
        }

        revert TransferCallerInvalid();
    }
}
