// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title IBaseStrategy
 * @author LooksRare protocol team (👀,💎)
 */
interface IBaseStrategy {
    /**
     * @notice This function acts as a safety check for the protocol's owner when adding new execution strategies.
     * @return isStrategy Whether it is a strategy
     */
    function isLooksRareV2Strategy() external pure returns (bool isStrategy);
}
