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

    function _testSetMaximumLatency(address _strategy, uint256 _maxLatency) internal {
        BaseStrategyChainlinkPriceLatency strategy = BaseStrategyChainlinkPriceLatency(_strategy);
        vm.assume(_maxLatency <= strategy.absoluteMaxLatency());

        vm.expectEmit(true, false, false, true);
        emit MaxLatencyUpdated(_maxLatency);
        vm.prank(_owner);
        strategy.updateMaxLatency(_maxLatency);

        assertEq(strategy.maxLatency(), _maxLatency);
    }

    function _testSetMaximumLatencyLatencyToleranceTooHigh(address _strategy, uint256 _maxLatency) internal {
        BaseStrategyChainlinkPriceLatency strategy = BaseStrategyChainlinkPriceLatency(_strategy);
        vm.assume(_maxLatency > strategy.absoluteMaxLatency());

        vm.expectRevert(BaseStrategyChainlinkPriceLatency.LatencyToleranceTooHigh.selector);
        vm.prank(_owner);
        strategy.updateMaxLatency(_maxLatency);
    }

    function _testSetMaximumLatencyNotOwner(address _strategy) internal {
        BaseStrategyChainlinkPriceLatency strategy = BaseStrategyChainlinkPriceLatency(_strategy);
        uint256 absoluteMaxLatency = strategy.absoluteMaxLatency();

        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        strategy.updateMaxLatency(absoluteMaxLatency);
    }
}
