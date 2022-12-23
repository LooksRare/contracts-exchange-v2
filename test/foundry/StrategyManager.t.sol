// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

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
        uint16 standardProtocolFeeBp = 299;
        uint16 minTotalFeeBp = 250;
        bool isActive = false;

        vm.expectEmit(false, false, false, false);
        emit StrategyUpdated(strategyId, isActive, standardProtocolFeeBp, minTotalFeeBp);
        looksRareProtocol.updateStrategy(strategyId, standardProtocolFeeBp, minTotalFeeBp, isActive);

        (
            bool strategyIsActive,
            uint16 strategyStandardProtocolFee,
            uint16 strategyMinTotalFee,
            uint16 strategyMaxProtocolFee,
            bytes4 strategySelector,
            bool strategyIsMakerBid,
            address strategyImplementation
        ) = looksRareProtocol.strategyInfo(strategyId);

        assertFalse(strategyIsActive);
        assertEq(strategyStandardProtocolFee, standardProtocolFeeBp);
        assertEq(strategyMinTotalFee, minTotalFeeBp);
        assertEq(strategyMaxProtocolFee, _maxProtocolFeeBp);
        assertEq(strategySelector, _emptyBytes4);
        assertFalse(strategyIsMakerBid);
        assertEq(strategyImplementation, address(0));
    }

    /**
     * Owner can change protocol fee and deactivate royalty
     */
    function testOwnerCanChangeStrategyProtocolFeeAndDeactivateRoyalty() public asPrankedUser(_owner) {
        uint256 strategyId = 0;
        uint16 standardProtocolFeeBp = 250;
        uint16 minTotalFeeBp = 250;
        bool isActive = true;

        vm.expectEmit(false, false, false, false);
        emit StrategyUpdated(strategyId, isActive, standardProtocolFeeBp, minTotalFeeBp);
        looksRareProtocol.updateStrategy(strategyId, standardProtocolFeeBp, minTotalFeeBp, isActive);

        (
            bool strategyIsActive,
            uint16 strategyStandardProtocolFee,
            uint16 strategyMinTotalFee,
            uint16 strategyMaxProtocolFee,
            bytes4 strategySelector,
            bool strategyIsMakerBid,
            address strategyImplementation
        ) = looksRareProtocol.strategyInfo(strategyId);

        assertTrue(strategyIsActive);
        assertEq(strategyStandardProtocolFee, standardProtocolFeeBp);
        assertEq(strategyMinTotalFee, minTotalFeeBp);
        assertEq(strategyMaxProtocolFee, _maxProtocolFeeBp);
        assertEq(strategySelector, _emptyBytes4);
        assertFalse(strategyIsMakerBid);
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
            uint16 maxProtocolFeeBp,
            ,
            ,

        ) = looksRareProtocol.strategyInfo(0);

        // 1. newStandardProtocolFee is higher than maxProtocolFeeBp
        uint16 newStandardProtocolFee = maxProtocolFeeBp + 1;
        uint16 newMinTotalFee = currentMinTotalFee;
        vm.expectRevert(StrategyProtocolFeeTooHigh.selector);
        looksRareProtocol.updateStrategy(0, newStandardProtocolFee, newMinTotalFee, true);

        // 2. newMinTotalFee is higher than maxProtocolFeeBp
        newStandardProtocolFee = currentStandardProtocolFee;
        newMinTotalFee = maxProtocolFeeBp + 1;
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
        uint16 standardProtocolFeeBp = 250;
        uint16 minTotalFeeBp = 300;
        uint16 maxProtocolFeeBp = 300;
        address implementation = address(0);

        // 1. standardProtocolFeeBp is higher than maxProtocolFeeBp
        maxProtocolFeeBp = standardProtocolFeeBp - 1;
        vm.expectRevert(abi.encodeWithSelector(IStrategyManager.StrategyProtocolFeeTooHigh.selector));
        looksRareProtocol.addStrategy(
            standardProtocolFeeBp,
            minTotalFeeBp,
            maxProtocolFeeBp,
            _emptyBytes4,
            true,
            implementation
        );

        // 2. minTotalFeeBp is higher than maxProtocolFeeBp
        maxProtocolFeeBp = minTotalFeeBp - 1;
        vm.expectRevert(abi.encodeWithSelector(IStrategyManager.StrategyProtocolFeeTooHigh.selector));
        looksRareProtocol.addStrategy(
            standardProtocolFeeBp,
            minTotalFeeBp,
            maxProtocolFeeBp,
            _emptyBytes4,
            true,
            implementation
        );

        // 3. maxProtocolFeeBp is higher than _MAX_PROTOCOL_FEE
        maxProtocolFeeBp = 5000 + 1;
        vm.expectRevert(abi.encodeWithSelector(IStrategyManager.StrategyProtocolFeeTooHigh.selector));
        looksRareProtocol.addStrategy(
            standardProtocolFeeBp,
            minTotalFeeBp,
            maxProtocolFeeBp,
            _emptyBytes4,
            true,
            implementation
        );
    }

    function testAddStrategyNoSelector() public asPrankedUser(_owner) {
        vm.expectRevert(IStrategyManager.StrategyHasNoSelector.selector);
        looksRareProtocol.addStrategy(
            _standardProtocolFeeBp,
            _minTotalFeeBp,
            _maxProtocolFeeBp,
            _emptyBytes4,
            true,
            address(0)
        );
    }
}
