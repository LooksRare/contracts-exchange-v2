// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// LooksRare unopinionated libraries
import {OwnableTwoSteps} from "@looksrare/contracts-libs/contracts/OwnableTwoSteps.sol";
import {ReentrancyGuard} from "@looksrare/contracts-libs/contracts/ReentrancyGuard.sol";
import {LowLevelERC20Transfer} from "@looksrare/contracts-libs/contracts/lowLevelCallers/LowLevelERC20Transfer.sol";

// Interfaces
import {ICriteriaStakingRegistry} from "./interfaces/ICriteriaStakingRegistry.sol";
import {ICollectionStakingRegistry} from "./interfaces/ICollectionStakingRegistry.sol";

/**
 * @title CollectionStakingRegistry
 * @notice This contract manages the LOOKS stakes for collections.
 * @author LooksRare protocol team (👀,💎)
 */
contract CollectionStakingRegistry is
    LowLevelERC20Transfer,
    ICollectionStakingRegistry,
    OwnableTwoSteps,
    ReentrancyGuard
{
    // Address of the LooksRare token
    address public immutable looksRareToken;

    // Criteria staking contract
    ICriteriaStakingRegistry public criteriaStakingRegistry;

    // Collection info
    mapping(address => CollectionInfo) public collectionInfo;

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
        tier[1] = Tier({rebatePercent: 2500, stake: 0});
    }

    /**
     * @notice This function allows to claim/modify the ownership of a collection and the stakes associated with a collection.
     * @param collection Address of the collection
     * @param targetTier Target tier (e.g., 0, 1)
     * @param collectionManager Address of the collection manager
     * @param rebateReceiver Address of the rebate receiver
     * @param rebatePercentOfTier Rebate percent (e.g., 2500 = 25%) at the target tier
     * @param stakeAmountOfTier Total stake amount (in LOOKS) required at the target tier
     * @dev If the stakeAmount is lower than current amount staked, the user receives the difference in LOOKS.
     *      If the stakeAmount is higher than the current amount staked, the user transfers the difference in LOOKS.
     *      If the stakeAmount is equal to the current amount staked, the user doesn't transfer/receiver any LOOKS.
     */
    function claimCollectionOwnershipAndSetTier(
        address collection,
        uint256 targetTier,
        address collectionManager,
        address rebateReceiver,
        uint16 rebatePercentOfTier,
        uint256 stakeAmountOfTier
    ) external nonReentrant {
        address currentCollectionManager = collectionInfo[collection].collectionManager;

        if (currentCollectionManager == address(0)) {
            if (!criteriaStakingRegistry.verifyCollectionOwner(collection, msg.sender)) {
                revert NotCollectionOwner();
            }
        } else if (currentCollectionManager != msg.sender) {
            revert WrongCollectionOwner();
        }

        if (rebatePercentOfTier != tier[targetTier].rebatePercent) revert WrongRebatePercentForTier();
        if (stakeAmountOfTier != tier[targetTier].stake) revert WrongStakeAmountForTier();

        uint256 currentCollectionStake = collectionInfo[collection].stake;

        if (currentCollectionStake < stakeAmountOfTier) {
            _executeERC20TransferFrom(
                looksRareToken,
                msg.sender,
                address(this),
                stakeAmountOfTier - currentCollectionStake
            );
        } else if (currentCollectionStake > stakeAmountOfTier) {
            _executeERC20DirectTransfer(looksRareToken, msg.sender, currentCollectionStake - stakeAmountOfTier);
        }

        collectionInfo[collection] = CollectionInfo({
            collectionManager: collectionManager,
            rebateReceiver: rebateReceiver,
            rebatePercent: rebatePercentOfTier,
            stake: stakeAmountOfTier
        });

        emit CollectionUpdate(collection, collectionManager, rebateReceiver, rebatePercentOfTier, stakeAmountOfTier);
    }

    /**
     * @notice Withdraw all LOOKS staked and exit the rebate program
     * @param collection Address of the collection
     */
    function withdrawAll(address collection) external nonReentrant {
        if (collectionInfo[collection].collectionManager != msg.sender) revert WrongCollectionOwner();

        uint256 currentCollectionStake = collectionInfo[collection].stake;

        delete collectionInfo[collection];
        collectionInfo[collection].collectionManager = msg.sender;

        if (currentCollectionStake != 0) {
            _executeERC20DirectTransfer(looksRareToken, msg.sender, currentCollectionStake);
        }

        emit CollectionWithdraw(collection, msg.sender);
    }

    /**
     * @notice Set collection owners
     * @param collections Addresses of collections
     * @param collectionManagers Addresses of collection managers
     * @dev Only callable by owner.
     */
    function setCollectionOwners(address[] calldata collections, address[] calldata collectionManagers)
        external
        onlyOwner
    {
        uint256 length = collections.length;

        if (collectionManagers.length != length || length == 0) revert WrongLengths();

        for (uint256 i; i < length; ) {
            collectionInfo[collections[i]].collectionManager = collectionManagers[i];

            emit CollectionUpdate(
                collections[i],
                collectionManagers[i],
                collectionInfo[collections[i]].rebateReceiver,
                collectionInfo[collections[i]].rebatePercent,
                collectionInfo[collections[i]].stake
            );

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Adjust tier
     * @param tierIndex Index of the tier
     * @param newTier Tier information
     * @dev Only callable by owner.
     */
    function adjustTier(uint256 tierIndex, Tier calldata newTier) external onlyOwner {
        if (newTier.rebatePercent < 10000) revert TierRebateTooHigh();
        tier[tierIndex] = newTier;
        emit NewTier(tierIndex, newTier.rebatePercent, newTier.stake);
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
        return (collectionInfo[collection].rebateReceiver, collectionInfo[collection].rebatePercent);
    }
}
