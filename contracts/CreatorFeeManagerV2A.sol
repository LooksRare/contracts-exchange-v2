// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IERC2981} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC2981.sol";

// Interfaces
import {ICreatorFeeManager} from "./interfaces/ICreatorFeeManager.sol";
import {IRoyaltyFeeRegistry} from "./interfaces/IRoyaltyFeeRegistry.sol";

/**
 * @title CreatorFeeManagerV2A
 * @notice It distributes a royalty rebate.
 */
contract CreatorFeeManagerV2A is ICreatorFeeManager {
    // Standard royalty fee (in basis point)
    uint256 public constant STANDARD_ROYALTY_FEE_BP = 50;

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
     * @notice View receiver and creator fee
     * @param collection Collection address
     * @param price Trade price
     */
    function viewCreatorFee(
        address collection,
        uint256 price,
        uint256[] memory itemIds
    ) external view returns (address receiver, uint256 creatorFee) {
        // Check if there is a royalty info in the system
        (receiver, ) = royaltyFeeRegistry.royaltyInfo(collection, price);

        if (receiver == address(0)) {
            // interfaceId of 0x2a55205a
            if (IERC2981(collection).supportsInterface(0x2a55205a)) {
                uint256 length = itemIds.length;

                for (uint256 i; i < length; ) {
                    (bool status, bytes memory data) = collection.staticcall(
                        abi.encodeWithSelector(IERC2981.royaltyInfo.selector, itemIds[i], price)
                    );
                    if (status) {
                        address newReceiver;
                        (newReceiver, ) = abi.decode(data, (address, uint256));

                        if (i == 0) {
                            if (newReceiver == address(0)) break;

                            receiver = newReceiver;
                        } else {
                            if (newReceiver != receiver) {
                                receiver = address(0);
                                break;
                            }
                        }
                    }
                }
            }
        }

        // A fixed royalty fee is applied
        if (receiver != address(0)) {
            creatorFee = (STANDARD_ROYALTY_FEE_BP * price) / 10000;
        }
    }
}
