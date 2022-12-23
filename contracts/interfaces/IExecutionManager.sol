// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title IExecutionManager
 * @author LooksRare protocol team (👀,💎)
 */
interface IExecutionManager {
    /**
     * @notice It is returned if the creator fee (in basis point) is too high
     */
    error CreatorFeeBpTooHigh();

    /**
     * @notice It is returned if there is no selector for maker bid for a given strategyId
     */
    error NoSelectorForMakerBid();

    /**
     * @notice It is returned if there is no selector for maker ask for a given strategyId
     */
    error NoSelectorForMakerAsk();

    /**
     * @notice It is returned if the current block timestamp is not between start and end times in the maker order.
     */
    error OutsideOfTimeRange();

    /**
     * @notice It is returned if the strategyId has no implementation
     * @dev It would be returned if there is no implementation address while the strategyId is strictly greater than 0.
     */
    error StrategyNotAvailable(uint256 strategyId);

    /**
     * @notice It is issued when there is a new creator fee manager
     * @param creatorFeeManager Address of the new creator fee manager
     */
    event NewCreatorFeeManager(address creatorFeeManager);

    /**
     * @notice It is issued when there is a new maximum creator fee (in basis point)
     * @param maximumCreatorFeeBp New maximum creator fee (in basis point)
     */
    event NewMaximumCreatorFeeBp(uint256 maximumCreatorFeeBp);

    /**
     * @notice It is issued when there is a new protocol fee recipient address
     * @param protocolFeeRecipient Address of the new protocol fee recipient
     */
    event NewProtocolFeeRecipient(address protocolFeeRecipient);
}
