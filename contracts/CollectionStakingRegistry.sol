// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// LooksRare unopinionated libraries
import {OwnableTwoSteps} from "@looksrare/contracts-libs/contracts/OwnableTwoSteps.sol";

// Interfaces
import {ICriteriaStakingRegistry} from "./interfaces/ICriteriaStakingRegistry.sol";
import {ICollectionStakingRegistry} from "./interfaces/ICollectionStakingRegistry.sol";

/**
 * @title CollectionStakingRegistry
 * @notice This contract manages the LOOKS stakes of the collection.
 * @author LooksRare protocol team (👀,💎)
 */
contract CollectionStakingRegistry is ICollectionStakingRegistry, OwnableTwoSteps {
    // Address of the LooksRare token
    address public immutable looksRareToken;

    // Criteria staking contract
    ICriteriaStakingRegistry public criteriaStakingRegistry;

    // Collection stake
    mapping(address => CollectionStake) public collectionStake;

    // Tier
    mapping(uint256 => Tier) public tier;

    /**
     * @notice Constructor
     * @param _looksRareToken Address of the LooksRare token
     * @param _criteriaStakingRegistry Address of the criteria staking contract
     */
    constructor(address _looksRareToken, address _criteriaStakingRegistry) {
        looksRareToken = _looksRareToken;
        criteriaStakingRegistry = ICriteriaStakingRegistry(_criteriaStakingRegistry);
        tier[0] = Tier({rebatePercent: 2500, stake: 0});
    }

    /**
     * @notice TODO
     */
    function adjustTier(address collection, uint256 targetTier) external {
        _checkSender(collection, msg.sender);

        collectionStake[collection] = CollectionStake({
            collectionManager: msg.sender,
            rebateReceiver: msg.sender,
            rebatePercent: tier[targetTier].rebatePercent,
            stake: tier[targetTier].stake
        });
    }

    /**
     * @notice TODO
     */
    function withdrawAll(address collection) external {
        //
    }

    function _checkSender(address collection, address sender) private view {
        if (sender != collectionStake[collection].collectionManager) {
            if (!criteriaStakingRegistry.verifyCollectionOwner(collection, sender)) {
                revert("Wrong criteria");
            }
        }
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
