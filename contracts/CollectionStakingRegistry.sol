// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// LooksRare unopinionated libraries
import {OwnableTwoSteps} from "@looksrare/contracts-libs/contracts/OwnableTwoSteps.sol";

// Interfaces
import {ICollectionStakingRegistry} from "./interfaces/ICollectionStakingRegistry.sol";

/**
 * @title CollectionStakingRegistry
 * @notice This contract manages the stakes of the collection.
 * @author LooksRare protocol team (👀,💎)
 */
contract CollectionStakingRegistry is ICollectionStakingRegistry, OwnableTwoSteps {
    // Collection stake
    mapping(address => CollectionStake) public collectionStake;

    // Tier
    mapping(uint256 => Tier) public tier;

    // Address of the LooksRare token
    address public immutable looksRareToken;

    /**
     * @notice Constructor
     * @param _looksRareToken Address of the LooksRareToken
     */
    constructor(address _looksRareToken) {
        looksRareToken = _looksRareToken;
        tier[0] = Tier({rebatePercent: 2500, stake: 0});
    }

    /**
     * @notice TODO
     */
    function setTier(address collection, uint256 targetTier) external {
        collectionStake[collection] = CollectionStake({
            collectionManager: msg.sender,
            rebateReceiver: msg.sender,
            rebatePercent: tier[targetTier].rebatePercent,
            stake: tier[targetTier].stake
        });
    }

    /**
     * @notice View protocol fee rebate
     * @param collection Address of the collection
     * @return rebateReceiver Address of the rebate receiver
     * @return rebatePercent Address of the rebate percent (e.g., 2500 -> 25%)
     */
    function viewProtocolFeeRebate(address collection)
        external
        view
        override
        returns (address rebateReceiver, uint16 rebatePercent)
    {
        return (collectionStake[collection].rebateReceiver, collectionStake[collection].rebatePercent);
    }
}
