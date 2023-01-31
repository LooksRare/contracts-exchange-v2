// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title ITransferManager
 * @author LooksRare protocol team (👀,💎)
 */
interface ITransferManager {
    /**
     * @dev Struct only used for transferBatchItemsAcrossCollections
     * @param collection Collection address
     * @param assetType 0 for ERC721, 1 for ERC1155
     * @param itemids Array of item IDs to be transferred
     * @param amounts Array of transfer amounts
     */
    struct BatchTransferItem {
        address collection;
        uint256 assetType;
        uint256[] itemIds;
        uint256[] amounts;
    }

    /**
     * @notice It is emitted if new operators are added to the user's whitelist.
     * @param user Address of the user
     * @param operators Array of operator addresses
     */
    event ApprovalsGranted(address user, address[] operators);

    /**
     * @notice It is emitted if existing operators are removed from the user's whitelist.
     * @param user Address of the user
     * @param operators Array of operator addresses
     */
    event ApprovalsRemoved(address user, address[] operators);

    /**
     * @notice It is emitted if an existing operator is removed from the whitelist.
     * @param operator Operator address
     */
    event OperatorRemoved(address operator);

    /**
     * @notice It is emitted if a new operator is added to the whitelist.
     * @param operator Operator address
     */
    event OperatorWhitelisted(address operator);

    /**
     * @notice It is returned if the transfer caller is already approved by the user.
     */
    error AlreadyApproved();

    /**
     * @notice It is returned if the transfer caller is already whitelisted by the owner.
     */
    error AlreadyWhitelisted();

    /**
     * @notice It is returned if the transfer caller to approve isn't approved by the user.
     */
    error NotApproved();

    /**
     * @notice It is returned if the transfer caller to approve isn't whitelisted by the owner.
     */
    error NotWhitelisted();

    /**
     * @notice It is returned if the transfer caller is invalid
     */
    error TransferCallerInvalid();
}
