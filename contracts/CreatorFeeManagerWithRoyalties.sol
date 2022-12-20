// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// LooksRare unopinionated libraries
import {IERC2981} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC2981.sol";

// Interfaces
import {ICreatorFeeManager} from "./interfaces/ICreatorFeeManager.sol";
import {IRoyaltyFeeRegistry} from "./interfaces/IRoyaltyFeeRegistry.sol";

/**
 * @title CreatorFeeManagerWithRoyalties
 * @notice It distributes royalties.
 */
contract CreatorFeeManagerWithRoyalties is ICreatorFeeManager {
    error CreatorFeeTooHigh(address collection);

    // Royalty fee registry
    IRoyaltyFeeRegistry public immutable royaltyFeeRegistry;

    /**
     * @notice Constructor
     * @param _royaltyFeeRegistry Address of the Royalty Fee Registry
     */
    constructor(address _royaltyFeeRegistry) {
        royaltyFeeRegistry = IRoyaltyFeeRegistry(_royaltyFeeRegistry);
    }

    /**
     * @inheritdoc ICreatorFeeManager
     * @dev There are two onchain sources for the royalty fee to distribute.
     *      1. RoyaltyFeeRegistry: It is an onchain registry where royalty fee is defined across all items of a collection.
     *      2. ERC2981: The NFT Royalty Standard where royalty fee is defined at a tokenId level for each item of a collection.
     *      The onchain logic looks up the registry first. If it doesn't find anything, it checks if a collection is ERC2981.
     *      If so, it fetches the proper royalty information for the itemId.
     *      For a bundle that contains multiple itemIds (for a collection using ERC2981), if the royalty fee/recipient differ among the itemIds
     *      part of the bundle, the trade reverts.
     *      This contract DOES NOT enforce any restriction for extremely high creator fee, not verifies the creator fee fetched is inferior to 10,000.
     *      If any contract relies on it to build an on-chain royalty logic, the contract should implement protection against (1) high
     *      royalties or (2) potential unexpected royalty changes that can occur.
     */
    function viewCreatorFeeInfo(
        address collection,
        uint256 price,
        uint256[] memory itemIds
    ) external view returns (address creator, uint256 creatorFeeBp) {
        // Check if there is a royalty info in the system
        (creator, creatorFeeBp) = royaltyFeeRegistry.royaltyInfo(collection, price);

        if (creator == address(0)) {
            if (IERC2981(collection).supportsInterface(IERC2981.royaltyInfo.selector)) {
                uint256 length = itemIds.length;

                for (uint256 i; i < length; ) {
                    (bool status, bytes memory data) = collection.staticcall(
                        abi.encodeWithSelector(IERC2981.royaltyInfo.selector, itemIds[i], price)
                    );
                    if (status) {
                        (address newCreator, uint256 newCreatorFeeBp) = abi.decode(data, (address, uint256));

                        if (i == 0) {
                            creator = newCreator;
                            creatorFeeBp = newCreatorFeeBp;
                        } else {
                            if (newCreator != creator || newCreatorFeeBp != creatorFeeBp) {
                                revert BundleEIP2981NotAllowed(collection);
                            }
                        }
                    }
                    unchecked {
                        ++i;
                    }
                }
            }
        }
    }
}
