// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Interfaces
import {ICreatorFeeManager} from "./interfaces/ICreatorFeeManager.sol";
import {IRoyaltyFeeRegistry} from "./interfaces/IRoyaltyFeeRegistry.sol";

/**
 * @title CreatorFeeManagerZero
 * @notice This contract returns the creator fee address and the creator rebate amount as 0.
 * @author LooksRare protocol team (👀,💎)
 */
contract CreatorFeeManagerZero is ICreatorFeeManager {
    /**
     * @notice Royalty fee registry interface.
     */
    IRoyaltyFeeRegistry public immutable royaltyFeeRegistry;

    /**
     * @notice Constructor
     * @param _royaltyFeeRegistry Royalty fee registry address.
     */
    constructor(address _royaltyFeeRegistry) {
        royaltyFeeRegistry = IRoyaltyFeeRegistry(_royaltyFeeRegistry);
    }

    /**
     * @inheritdoc ICreatorFeeManager
     */
    function viewCreatorFeeInfo(
        address,
        uint256,
        uint256[] memory
    ) external pure returns (address creator, uint256 creatorFeeAmount) {
        // Default to address(0) and 0
    }
}
