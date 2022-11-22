// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// LooksRare unopinionated libraries
import {IERC2981} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC2981.sol";
import {OwnableTwoSteps} from "@looksrare/contracts-libs/contracts/OwnableTwoSteps.sol";

// Interfaces
import {ICreatorFeeManager} from "./interfaces/ICreatorFeeManager.sol";
import {IRoyaltyFeeRegistry} from "./interfaces/IRoyaltyFeeRegistry.sol";

/**
 * @title CreatorFeeManagerV2B
 * @notice It distributes the proper royalties.
 */
contract CreatorFeeManagerV2B is OwnableTwoSteps, ICreatorFeeManager {
    event NewMaximumRoyaltyFeeBp(uint256 maximumRoyaltyFeeBp);
    error MaximumRoyaltyFeeBpTooHigh();

    // Maximum royalty fee (in basis point)
    uint256 public maximumRoyaltyFeeBp = 2500;

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
     * @notice Update the maximum royalty fee (in bp)
     * @param newMaximumRoyaltyFeeBp New maximum royalty fee (in basis point)
     */
    function updateMaximumRoyaltyFeeBp(uint256 newMaximumRoyaltyFeeBp) external onlyOwner {
        if (newMaximumRoyaltyFeeBp > 10000) revert MaximumRoyaltyFeeBpTooHigh();
        maximumRoyaltyFeeBp = newMaximumRoyaltyFeeBp;

        emit NewMaximumRoyaltyFeeBp(newMaximumRoyaltyFeeBp);
    }

    /**
     * @notice View receiver and creator fee
     * @param collection Collection address
     * @param price Transaction price
     * @param itemIds Array of item ids
     */
    function viewCreatorFee(
        address collection,
        uint256 price,
        uint256[] memory itemIds
    ) external view returns (address receiver, uint256 creatorFee) {
        // Check if there is a royalty info in the system
        (receiver, creatorFee) = royaltyFeeRegistry.royaltyInfo(collection, price);

        if (receiver == address(0)) {
            if (IERC2981(collection).supportsInterface(IERC2981.royaltyInfo.selector)) {
                uint256 length = itemIds.length;

                for (uint256 i; i < length; ) {
                    (bool status, bytes memory data) = collection.staticcall(
                        abi.encodeWithSelector(IERC2981.royaltyInfo.selector, itemIds[i], price)
                    );
                    if (status) {
                        (address newReceiver, uint256 newCreatorFee) = abi.decode(data, (address, uint256));

                        if (i == 0) {
                            receiver = newReceiver;
                            creatorFee = newCreatorFee;
                        } else {
                            if (newReceiver != receiver || newCreatorFee != creatorFee) {
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

        // Do a downward adjustment if necessary
        if (receiver != address(0)) {
            uint256 maximumCreatorFee = price * maximumRoyaltyFeeBp;
            creatorFee = maximumCreatorFee > creatorFee ? creatorFee : maximumCreatorFee;
        }
    }
}
