// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title ICollectionStakingRegistry
 * @author LooksRare protocol team (👀,💎)
 */
interface ICollectionStakingRegistry {
    struct CollectionStake {
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
