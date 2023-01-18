// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// LooksRare libraries
import {IOwnableTwoSteps} from "@looksrare/contracts-libs/contracts/interfaces/IOwnableTwoSteps.sol";

// Strategies
import {BaseStrategyChainlinkPriceLatency} from "../../../../contracts/executionStrategies/Chainlink/BaseStrategyChainlinkPriceLatency.sol";

// Other tests
import {ProtocolBase} from "../../ProtocolBase.t.sol";

contract ChainlinkMaximumLatencyTest is ProtocolBase {
    event MaxLatencyUpdated(uint256 newMaxLatency);

    function _testSetMaximumLatency(address _strategy) internal {
        BaseStrategyChainlinkPriceLatency strategy = BaseStrategyChainlinkPriceLatency(_strategy);

        vm.expectEmit(true, false, false, true);
        emit MaxLatencyUpdated(86_400);
        vm.prank(_owner);
        strategy.updateMaxLatency(86_400);

        assertEq(strategy.maxLatency(), 86_400);
    }

    function _testSetMaximumLatencyLatencyToleranceTooHigh(address _strategy) internal {
        BaseStrategyChainlinkPriceLatency strategy = BaseStrategyChainlinkPriceLatency(_strategy);

        vm.expectRevert(BaseStrategyChainlinkPriceLatency.LatencyToleranceTooHigh.selector);
        vm.prank(_owner);
        strategy.updateMaxLatency(86_401);
    }

    function _testSetMaximumLatencyNotOwner(address _strategy) internal {
        BaseStrategyChainlinkPriceLatency strategy = BaseStrategyChainlinkPriceLatency(_strategy);

        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        strategy.updateMaxLatency(86_400);
    }
}
