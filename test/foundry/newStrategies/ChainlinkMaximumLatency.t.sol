// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// LooksRare libraries
import {IOwnableTwoSteps} from "@looksrare/contracts-libs/contracts/interfaces/IOwnableTwoSteps.sol";

// Strategies
import {StrategyChainlinkPriceLatency} from "../../../contracts/executionStrategies/StrategyChainlinkPriceLatency.sol";

// Other tests
import {ProtocolBase} from "../ProtocolBase.t.sol";

contract ChainlinkMaximumLatencyTest is ProtocolBase {
    event MaximumLatencyUpdated(uint256 maximumLatency);

    function _testSetMaximumLatency(address _strategy) internal {
        StrategyChainlinkPriceLatency strategy = StrategyChainlinkPriceLatency(_strategy);

        vm.expectEmit(true, false, false, true);
        emit MaximumLatencyUpdated(3600);
        vm.prank(_owner);
        strategy.setMaximumLatency(3600);

        assertEq(strategy.maximumLatency(), 3600);
    }

    function _testSetMaximumLatencyLatencyToleranceTooHigh(address _strategy) internal {
        StrategyChainlinkPriceLatency strategy = StrategyChainlinkPriceLatency(_strategy);

        vm.expectRevert(StrategyChainlinkPriceLatency.LatencyToleranceTooHigh.selector);
        vm.prank(_owner);
        strategy.setMaximumLatency(3601);
    }

    function _testSetMaximumLatencyNotOwner(address _strategy) internal {
        StrategyChainlinkPriceLatency strategy = StrategyChainlinkPriceLatency(_strategy);

        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        strategy.setMaximumLatency(3600);
    }
}
