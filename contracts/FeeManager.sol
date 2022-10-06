// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

// LooksRare unopinionated libraries
import {OwnableTwoSteps} from "@looksrare/contracts-libs/contracts/OwnableTwoSteps.sol";
import {IERC165} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC165.sol";
import {IERC2981} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC2981.sol";

// Interfaces
import {IFeeManager} from "./interfaces/IFeeManager.sol";
import {IRoyaltyFeeRegistry} from "./interfaces/IRoyaltyFeeRegistry.sol";

/**
 * @title FeeManager
 * @notice This contract handles the fee logic for determining the royalty fee and recipients for protocol fee and royalty fee (if any).
 *         It allows the owner to update the royalty fee registry and the protocol fee recipient.
 * @author LooksRare protocol team (👀,💎)
 */
contract FeeManager is IFeeManager, OwnableTwoSteps {
    // Protocol fee recipient
    address public protocolFeeRecipient;

    // Royalty fee registry
    IRoyaltyFeeRegistry public royaltyFeeRegistry;

    /**
     * @notice Constructor
     * @param _royaltyFeeRegistry Royalty fee registry address
     */
    constructor(address _royaltyFeeRegistry) {
        royaltyFeeRegistry = IRoyaltyFeeRegistry(_royaltyFeeRegistry);
    }

    /**
     * @notice Set protocol fee recipient
     * @param newProtocolFeeRecipient New protocol fee recipient address
     */
    function setProtocolFeeRecipient(address newProtocolFeeRecipient) external onlyOwner {
        protocolFeeRecipient = newProtocolFeeRecipient;
        emit NewProtocolFeeRecipient(newProtocolFeeRecipient);
    }

    /**
     * @notice Set royalty fee registry
     * @param newRoyaltyFeeRegistry New royalty fee registry address
     */
    function setRoyaltyFeeRegistry(address newRoyaltyFeeRegistry) external onlyOwner {
        royaltyFeeRegistry = IRoyaltyFeeRegistry(newRoyaltyFeeRegistry);
        emit NewRoyaltyFeeRegistry(newRoyaltyFeeRegistry);
    }

    /**
     * @notice Get royalty recipient and amount for a collection, set of itemIds, and gross sale amount.
     * @param collection Collection address
     * @param itemIds Array of itemIds
     * @param amount Price amount of the sale
     * @return royaltyRecipient Royalty recipient address
     * @return royaltyAmount Amount to pay in royalties to the royalty recipient
     * @dev There are two onchain sources for the royalty fee to distribute.
     *      1. RoyaltyFeeRegistry: It is an onchain registry where royalty fee is defined across all items of a collection.
     *      2. ERC2981: The NFT Royalty Standard where royalty fee is defined at a tokenId level for each item of a collection.
     *      The onchain logic looks up the registry first. If it doesn't find anything, it checks if a collection is ERC2981.
     *      If so, it fetches the proper royalty information for the itemId.
     *      For a bundle that contains multiple itemIds (for a collection using ERC2981), if the royalty fee/recipient differ among the itemIds
     *      part of the bundle, the trade reverts.
     */
    function _getRoyaltyRecipientAndAmount(
        address collection,
        uint256[] memory itemIds,
        uint256 amount
    ) internal view returns (address royaltyRecipient, uint256 royaltyAmount) {
        // 1. Royalty fee registry
        (royaltyRecipient, royaltyAmount) = royaltyFeeRegistry.royaltyInfo(collection, amount);

        // 2. ERC2981 logic
        if (royaltyRecipient == address(0)) {
            if (royaltyAmount == 0) {
                (bool status, bytes memory data) = collection.staticcall(
                    abi.encodeWithSelector(IERC2981.royaltyInfo.selector, itemIds[0], amount)
                );

                if (status) {
                    (royaltyRecipient, royaltyAmount) = abi.decode(data, (address, uint256));

                    // Specific logic if bundle
                    uint256 itemIdsLength = itemIds.length;
                    if (itemIdsLength > 1) {
                        for (uint256 i = 1; i < itemIdsLength; ) {
                            (address royaltyRecipientForToken, uint256 royaltyAmountForToken) = IERC2981(collection)
                                .royaltyInfo(itemIds[i], amount);

                            if (royaltyRecipientForToken != royaltyRecipient || royaltyAmount != royaltyAmountForToken)
                                revert BundleEIP2981NotAllowed(collection, itemIds);

                            unchecked {
                                ++i;
                            }
                        }
                    }
                }
            }
        }
    }
}
