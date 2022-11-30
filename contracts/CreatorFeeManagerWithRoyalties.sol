// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// LooksRare unopinionated libraries
import {IERC2981} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC2981.sol";
import {OwnableTwoSteps} from "@looksrare/contracts-libs/contracts/OwnableTwoSteps.sol";

// Interfaces
import {ICreatorFeeManager} from "./interfaces/ICreatorFeeManager.sol";
import {IRoyaltyFeeRegistry} from "./interfaces/IRoyaltyFeeRegistry.sol";

/**
 * @title CreatorFeeManagerWithRoyalties
 * @notice It distributes the proper royalties.
 */
contract CreatorFeeManagerWithRoyalties is OwnableTwoSteps, ICreatorFeeManager {
    error CreatorFeeTooHigh(address collection);
    error MaximumCreatorFeeBpTooHigh();
    event NewMaximumCreatorFeeBp(uint256 maximumCreatorFeeBp);

    // Royalty fee registry
    IRoyaltyFeeRegistry public immutable royaltyFeeRegistry;

    // Maximum creator fee (in basis point)
    uint256 public maximumCreatorFeeBp = 1_000;

    /**
     * @notice Constructor
     * @param _royaltyFeeRegistry Address of the Royalty Fee Registry
     */
    constructor(address _royaltyFeeRegistry) {
        royaltyFeeRegistry = IRoyaltyFeeRegistry(_royaltyFeeRegistry);
    }

    /**
     * @notice Update the maximum creator fee (in bp)
     * @param newMaximumCreatorFeeBp New maximum creator fee (in basis point)
     */
    function updateMaximumCreatorFeeBp(uint256 newMaximumCreatorFeeBp) external onlyOwner {
        if (newMaximumCreatorFeeBp > 10_000) revert MaximumCreatorFeeBpTooHigh();
        maximumCreatorFeeBp = newMaximumCreatorFeeBp;

        emit NewMaximumCreatorFeeBp(newMaximumCreatorFeeBp);
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

        // Revert if creator fee is too high
        if (receiver != address(0)) {
            uint256 maximumCreatorFee = (price * maximumCreatorFeeBp) / 10_000;

            if (creatorFee > maximumCreatorFee) {
                revert CreatorFeeTooHigh(collection);
            }
        }
    }
}
