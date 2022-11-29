// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title InvalidChainlinkPriceFeed
 */
contract InvalidChainlinkPriceFeed {
    uint256 zeroPrice;

    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        roundId = 1;
        answer = zeroPrice == 1 ? int256(0) : -1;
        startedAt = block.timestamp;
        updatedAt = block.timestamp;
        answeredInRound = 1;
    }
}
