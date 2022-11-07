// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IOwnable
 * @notice This interface is used for the logic used to determine the collection owner for the CollectionStakingRegistry.
 * @author LooksRare protocol team (👀,💎)
 */
interface IOwnable {
    function owner() external view returns (address);

    function admin() external view returns (address);
}
