// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// LooksRare unopinionated libraries
import {OwnableTwoSteps} from "@looksrare/contracts-libs/contracts/OwnableTwoSteps.sol";

/**
 * @title StrategyChainlinkPriceLatency
 * @notice This contract allows the owner to define the maximum acceptable Chainlink price latency.
 * @author LooksRare protocol team (👀,💎)
 */
contract StrategyChainlinkPriceLatency is OwnableTwoSteps {
    /**
     * @notice Constructor
     * @param _owner Owner address
     */
    constructor(address _owner) OwnableTwoSteps(_owner) {}

    /**
     * @notice Maximum latency accepted after which
     *         the execution strategy rejects the retrieved price
     */
    uint256 public maxLatency;

    /**
     * @notice Emitted when the maximum Chainlink price latency is updated
     * @param maxLatency Maximum Chainlink price latency
     */
    event MaximumLatencyUpdated(uint256 maxLatency);

    error LatencyToleranceTooHigh();
    error PriceNotRecentEnough();

    /**
     * @notice Set maximum Chainlink price latency. It cannot be higher than 3,600
     *         as Chainlink will at least update the price every 3,600 seconds, provided
     *         ETH's price does not deviate more than 0.5%.
     * @dev Function only callable by contract owner
     * @param _maxLatency Maximum Chainlink price latency
     */
    function setMaximumLatency(uint256 _maxLatency) external onlyOwner {
        if (_maxLatency > 3_600) revert LatencyToleranceTooHigh();
        maxLatency = _maxLatency;
        emit MaximumLatencyUpdated(_maxLatency);
    }
}
