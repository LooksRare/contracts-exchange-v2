// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Interfaces
import {IStrategyManager} from "../../contracts/interfaces/IStrategyManager.sol";

// Base test
import {ProtocolBase} from "./ProtocolBase.t.sol";

contract StrategyManagerTest is ProtocolBase, IStrategyManager {
    /**
     * Owner can discontinue strategy
     */
    function testOwnerCanDiscontinueStrategy() public asPrankedUser(_owner) {
        uint256 strategyId = 0;
        uint16 standardProtocolFee = 299;
        uint16 minTotalFee = 250;
        bool isActive = false;

        vm.expectEmit(false, false, false, false);
        emit StrategyUpdated(strategyId, isActive, standardProtocolFee, minTotalFee);
        looksRareProtocol.updateStrategy(strategyId, standardProtocolFee, minTotalFee, isActive);

        (
            bool strategyIsActive,
            uint16 strategyStandardProtocolFee,
            uint16 strategyMinTotalFee,
            uint16 strategyMaxProtocolFee,
            bytes4 strategySelector,
            bool isTakerBid,
            address strategyImplementation
        ) = looksRareProtocol.strategyInfo(strategyId);

        assertFalse(strategyIsActive);
        assertEq(strategyStandardProtocolFee, standardProtocolFee);
        assertEq(strategyMinTotalFee, minTotalFee);
        assertEq(strategyMaxProtocolFee, _maxProtocolFee);
        assertEq(strategySelector, _emptyBytes4);
        assertFalse(isTakerBid);
        assertEq(strategyImplementation, address(0));
    }

    /**
     * Owner can change protocol fee and deactivate royalty
     */
    function testOwnerCanChangeStrategyProtocolFeeAndDeactivateRoyalty() public asPrankedUser(_owner) {
        uint256 strategyId = 0;
        uint16 standardProtocolFee = 250;
        uint16 minTotalFee = 250;
        bool isActive = true;

        vm.expectEmit(false, false, false, false);
        emit StrategyUpdated(strategyId, isActive, standardProtocolFee, minTotalFee);
        looksRareProtocol.updateStrategy(strategyId, standardProtocolFee, minTotalFee, isActive);

        (
            bool strategyIsActive,
            uint16 strategyStandardProtocolFee,
            uint16 strategyMinTotalFee,
            uint16 strategyMaxProtocolFee,
            bytes4 strategySelector,
            bool isTakerBid,
            address strategyImplementation
        ) = looksRareProtocol.strategyInfo(strategyId);

        assertTrue(strategyIsActive);
        assertEq(strategyStandardProtocolFee, standardProtocolFee);
        assertEq(strategyMinTotalFee, minTotalFee);
        assertEq(strategyMaxProtocolFee, _maxProtocolFee);
        assertEq(strategySelector, _emptyBytes4);
        assertFalse(isTakerBid);
        assertEq(strategyImplementation, address(0));
    }

    /**
     * Owner functions for strategy updates revert as expected under multiple revertion scenarios
     */
    function testOwnerRevertionsForWrongParametersUpdateStrategy() public asPrankedUser(_owner) {
        (
            ,
            uint16 currentStandardProtocolFee,
            uint16 currentMinTotalFee,
            uint16 maxProtocolFee,
            ,
            ,

        ) = looksRareProtocol.strategyInfo(0);

        // 1. newStandardProtocolFee is higher than maxProtocolFee
        uint16 newStandardProtocolFee = maxProtocolFee + 1;
        uint16 newMinTotalFee = currentMinTotalFee;
        vm.expectRevert(StrategyProtocolFeeTooHigh.selector);
        looksRareProtocol.updateStrategy(0, newStandardProtocolFee, newMinTotalFee, true);

        // 2. newMinTotalFee is higher than maxProtocolFee
        newStandardProtocolFee = currentStandardProtocolFee;
        newMinTotalFee = maxProtocolFee + 1;
        vm.expectRevert(StrategyProtocolFeeTooHigh.selector);
        looksRareProtocol.updateStrategy(0, newStandardProtocolFee, newMinTotalFee, true);

        // 3. It reverts if strategy doesn't exist
        uint256 countStrategies = looksRareProtocol.countStrategies();
        vm.expectRevert(StrategyNotUsed.selector);
        looksRareProtocol.updateStrategy(countStrategies, currentStandardProtocolFee, currentMinTotalFee, true);
    }

    /**
     * Owner functions for strategy additions revert as expected under multiple revertion scenarios
     */
    function testOwnerRevertionsForWrongParametersAddStrategy() public asPrankedUser(_owner) {
        uint16 standardProtocolFee = 250;
        uint16 minTotalFee = 300;
        uint16 maxProtocolFee = 300;
        address implementation = address(0);

        // 1. standardProtocolFee is higher than maxProtocolFee
        maxProtocolFee = standardProtocolFee - 1;
        vm.expectRevert(abi.encodeWithSelector(IStrategyManager.StrategyProtocolFeeTooHigh.selector));
        looksRareProtocol.addStrategy(
            standardProtocolFee,
            minTotalFee,
            maxProtocolFee,
            _emptyBytes4,
            false,
            implementation
        );

        // 2. minTotalFee is higher than maxProtocolFee
        maxProtocolFee = minTotalFee - 1;
        vm.expectRevert(abi.encodeWithSelector(IStrategyManager.StrategyProtocolFeeTooHigh.selector));
        looksRareProtocol.addStrategy(
            standardProtocolFee,
            minTotalFee,
            maxProtocolFee,
            _emptyBytes4,
            false,
            implementation
        );

        // 3. maxProtocolFee is higher than _MAX_PROTOCOL_FEE
        maxProtocolFee = 5000 + 1;
        vm.expectRevert(abi.encodeWithSelector(IStrategyManager.StrategyProtocolFeeTooHigh.selector));
        looksRareProtocol.addStrategy(
            standardProtocolFee,
            minTotalFee,
            maxProtocolFee,
            _emptyBytes4,
            false,
            implementation
        );
    }

    function testAddStrategyNoSelector() public asPrankedUser(_owner) {
        vm.expectRevert(IStrategyManager.StrategyHasNoSelector.selector);
        looksRareProtocol.addStrategy(
            _standardProtocolFee,
            _minTotalFee,
            _maxProtocolFee,
            _emptyBytes4,
            false,
            address(0)
        );
    }
}
