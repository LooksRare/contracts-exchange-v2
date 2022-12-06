// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IStrategyManager} from "../../contracts/interfaces/IStrategyManager.sol";
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
            bytes4 strategySelectorTakerAsk,
            bytes4 strategySelectorTakerBid,
            address strategyImplementation
        ) = looksRareProtocol.strategyInfo(strategyId);

        assertFalse(strategyIsActive);
        assertEq(strategyStandardProtocolFee, standardProtocolFee);
        assertEq(strategyMinTotalFee, minTotalFee);
        assertEq(strategyMaxProtocolFee, _maxProtocolFee);
        assertEq(strategySelectorTakerAsk, _emptyBytes4);
        assertEq(strategySelectorTakerBid, _emptyBytes4);
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
            bytes4 strategySelectorTakerAsk,
            bytes4 strategySelectorTakerBid,
            address strategyImplementation
        ) = looksRareProtocol.strategyInfo(strategyId);

        assertTrue(strategyIsActive);
        assertEq(strategyStandardProtocolFee, standardProtocolFee);
        assertEq(strategyMinTotalFee, minTotalFee);
        assertEq(strategyMaxProtocolFee, _maxProtocolFee);
        assertEq(strategySelectorTakerAsk, _emptyBytes4);
        assertEq(strategySelectorTakerBid, _emptyBytes4);
        assertEq(strategyImplementation, address(0));
    }

    function testUpdateStrategyStrategyNotUsed() public asPrankedUser(_owner) {
        vm.expectRevert(StrategyNotUsed.selector);
        looksRareProtocol.updateStrategy(69, 250, 250, true);
    }

    /**
     * Owner functions for strategy additions/updates revert as expected under multiple cases
     */
    function testOwnerRevertionsForWrongParametersAddStrategy() public asPrankedUser(_owner) {
        uint16 standardProtocolFee = 250;
        uint16 minTotalFee = 300;
        uint16 maxProtocolFee = 300;
        address implementation = address(0);

        // 1. Strategy does not exist but maxProtocolFee is lower than standardProtocolFee
        maxProtocolFee = standardProtocolFee - 1;
        vm.expectRevert(abi.encodeWithSelector(IStrategyManager.StrategyProtocolFeeTooHigh.selector));
        looksRareProtocol.addStrategy(
            standardProtocolFee,
            minTotalFee,
            maxProtocolFee,
            _emptyBytes4,
            _emptyBytes4,
            implementation
        );

        // 2. Strategy does not exist but maxProtocolFee is lower than minTotalFee
        maxProtocolFee = minTotalFee - 1;
        vm.expectRevert(abi.encodeWithSelector(IStrategyManager.StrategyProtocolFeeTooHigh.selector));
        looksRareProtocol.addStrategy(
            standardProtocolFee,
            minTotalFee,
            maxProtocolFee,
            _emptyBytes4,
            _emptyBytes4,
            implementation
        );

        // 3. Strategy does not exist but maxProtocolFee is higher than _MAX_PROTOCOL_FEE
        maxProtocolFee = 5000 + 1;
        vm.expectRevert(abi.encodeWithSelector(IStrategyManager.StrategyProtocolFeeTooHigh.selector));
        looksRareProtocol.addStrategy(
            standardProtocolFee,
            minTotalFee,
            maxProtocolFee,
            _emptyBytes4,
            _emptyBytes4,
            implementation
        );
    }
}
