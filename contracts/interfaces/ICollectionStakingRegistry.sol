// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title ICollectionStakingRegistry
 * @author LooksRare protocol team (👀,💎)
 */
interface ICollectionStakingRegistry {
    // Custom errors
    error CollectionOwnerAlreadySet();
    error NotCollectionOwner(); // Collection owner is not matching the criteria set to claim the ownership
    error WrongCollectionOwner(); // Caller is not the collection owner
    error WrongRebatePercentForTier();
    error WrongStakeAmountForTier();

    // Custom events
    event CollectionUpdate(
        address collectionManager,
        address rebateReceiver,
        uint16 rebatePercent,
        uint256 stakeAmount
    );

    event NewTier(uint256 tierIndex, uint16 rebatePercent, uint256 stakeAmount);

    // Custom structs
    struct CollectionInfo {
        address collectionManager;
        address rebateReceiver;
        uint16 rebatePercent;
        uint256 stake;
    }

    struct Tier {
        uint16 rebatePercent;
        uint160 stake; // @dev uint160 covers the entire supply of LOOKS
    }

    function viewProtocolFeeRebate(address collection) external returns (address rebateReceiver, uint16 rebatePercent);
}
