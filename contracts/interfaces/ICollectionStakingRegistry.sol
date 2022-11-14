// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title ICollectionStakingRegistry
 * @author LooksRare protocol team (👀,💎)
 */
interface ICollectionStakingRegistry {
    // Custom errors
    error CollectionOwnerAlreadySet(); // There is already a collection owner set in the staking registry
    error NotCollectionOwner(); // Collection owner is not matching the criteria set to claim the ownership
    error TierRebateTooHigh(); // Tier rebate is too high
    error WrongCollectionOwner(); // Caller is not the collection owner
    error WrongLengths(); // Wrong length for arrays in a function
    error WrongRebateBasisPoint(); // Wrong rebate basis point for the tier
    error WrongStakeAmountForTier(); // Wrong stake amount for the tier

    // Custom events
    event CollectionWithdraw(address collection, address collectionManager);
    event CollectionUpdate(
        address collection,
        address collectionManager,
        address rebateReceiver,
        uint16 rebateBp,
        uint256 stakeAmount
    );

    event NewTier(uint256 tierIndex, uint16 rebateBp, uint256 stakeAmount);

    // Custom structs
    struct CollectionInfo {
        address collectionManager;
        address rebateReceiver;
        uint16 rebateBp;
        uint256 stake;
    }

    struct Tier {
        uint16 rebateBp; // Rebate basis point at the tier (e.g., 25 = 0.25)
        uint160 stake; // @dev uint160 covers the entire supply of LOOKS
    }

    function viewProtocolFeeRebate(address collection) external returns (address rebateReceiver, uint16 rebateBp);
}
