// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title ICreatorFeeManager
 * @author LooksRare protocol team (👀,💎)
 */
interface ICreatorFeeManager {
    function viewCreatorFee(
        address collection,
        uint256 price,
        uint256[] memory itemIds
    ) external view returns (address recipient, uint256 creatorFee);
}
