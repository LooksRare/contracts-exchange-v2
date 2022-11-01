// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title ICollectionStakingRegistry
 * @author LooksRare protocol team (👀,💎)
 */
interface ICollectionStakingRegistry {
    function viewProtocolFeeRebate(address collection) external returns (address rebateReceiver, uint16 rebatePercent);
}
