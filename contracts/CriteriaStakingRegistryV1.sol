// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Interfaces
import {ICriteriaStakingRegistry} from "./interfaces/ICriteriaStakingRegistry.sol";
import {IOwnable} from "./interfaces/IOwnable.sol";
import {IRoyaltyFeeRegistry} from "./interfaces/IRoyaltyFeeRegistry.sol";

/**
 * @title CriteriaStakingRegistryV1
 * @notice This contract manages the logic to define who is the owner of a collection.
 * @author LooksRare protocol team (👀,💎)
 */
contract CriteriaStakingRegistryV1 is ICriteriaStakingRegistry {
    // Address of the royalty fee registry
    IRoyaltyFeeRegistry public immutable royaltyFeeRegistry;

    /**
     * @notice Constructor
     * @param _royaltyFeeRegistry Address of the Royalty Fee Registry
     */
    constructor(address _royaltyFeeRegistry) {
        royaltyFeeRegistry = IRoyaltyFeeRegistry(_royaltyFeeRegistry);
    }

    function verifyCollectionOwner(address collection, address sender)
        external
        view
        override
        returns (bool isVerified)
    {
        // 1. Check royalty registry
        (address royaltyFeeSetter, , ) = royaltyFeeRegistry.royaltyFeeInfoCollection(collection);
        if (royaltyFeeSetter != address(0)) {
            if (royaltyFeeSetter == sender) isVerified = true;
        } else {
            revert NotRoyaltyFeeSetterInRegistry();
        }

        // 2. Check if owner
        if (!isVerified) {
            try IOwnable(collection).owner() returns (address owner) {
                if (owner == sender) isVerified = true;
            } catch {}
        }

        // 3. Check if admin
        if (isVerified) {
            try IOwnable(collection).admin() returns (address admin) {
                if (admin == sender) isVerified = true;
            } catch {}
        }
    }
}
