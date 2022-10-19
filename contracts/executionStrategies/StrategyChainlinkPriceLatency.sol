// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {StrategyBase} from "./StrategyBase.sol";

/**
 * @title StrategyChainlinkPriceLatency
 * @notice This contract allows the owner to define the maximum acceptable Chainlink price latency.
 * @author LooksRare protocol team (👀,💎)
 */
abstract contract StrategyChainlinkPriceLatency is StrategyBase {
    /**
     * @notice Maximum latency accepted after which
     *         the execution strategy rejects the retrieved price
     */
    uint256 public maximumLatency;

    /**
     * @notice Emitted when the maximum Chainlink price latency is updated
     * @param maximumLatency Maximum Chainlink price latency
     */
    event MaximumLatencyUpdated(uint256 maximumLatency);

    error InvalidChainlinkPrice();
    error LatencyToleranceTooHigh();

    /**
     * @notice Set maximum Chainlink price latency. It cannot be higher than 3,600
     *         as Chainlink will at least update the price every 3,600 seconds, provided
     *         ETH's price does not deviate more than 0.5%.
     * @dev Function only callable by contract owner
     * @param _maximumLatency Maximum Chainlink price latency
     */
    function setMaximumLatency(uint256 _maximumLatency) external onlyOwner {
        if (_maximumLatency > 3600) revert LatencyToleranceTooHigh();
        maximumLatency = _maximumLatency;
        emit MaximumLatencyUpdated(_maximumLatency);
    }
}
