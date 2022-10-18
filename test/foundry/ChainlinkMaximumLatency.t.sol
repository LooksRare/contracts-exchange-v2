// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IOwnableTwoSteps} from "@looksrare/contracts-libs/contracts/interfaces/IOwnableTwoSteps.sol";
import {ProtocolBase} from "./ProtocolBase.t.sol";

interface IStrategy {
    error LatencyToleranceTooHigh();

    function maximumLatency() external view returns (uint256);

    function setMaximumLatency(uint256 maximumLatency) external;
}

contract ChainlinkMaximumLatencyTest is ProtocolBase {
    event MaximumLatencyUpdated(uint256 maximumLatency);

    function _testSetMaximumLatency(address _strategy) internal {
        IStrategy strategy = IStrategy(_strategy);

        vm.expectEmit(true, false, false, true);
        emit MaximumLatencyUpdated(3600);
        vm.prank(_owner);
        strategy.setMaximumLatency(3600);

        assertEq(strategy.maximumLatency(), 3600);
    }

    function _testSetMaximumLatencyLatencyToleranceTooHigh(address _strategy) internal {
        IStrategy strategy = IStrategy(_strategy);

        vm.expectRevert(IStrategy.LatencyToleranceTooHigh.selector);
        vm.prank(_owner);
        strategy.setMaximumLatency(3601);
    }

    function _testSetMaximumLatencyNotOwner(address _strategy) internal {
        IStrategy strategy = IStrategy(_strategy);

        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        strategy.setMaximumLatency(3600);
    }
}
