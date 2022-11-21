// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IOwnableTwoSteps} from "@looksrare/contracts-libs/contracts/interfaces/IOwnableTwoSteps.sol";
import {TestHelpers} from "./utils/TestHelpers.sol";
import {TestParameters} from "./utils/TestParameters.sol";
import {CurrencyManager} from "../../contracts/CurrencyManager.sol";
import {ICurrencyManager} from "../../contracts/interfaces/ICurrencyManager.sol";
import {MockERC20} from "../mock/MockERC20.sol";

contract CurrencyManagerTest is TestHelpers, TestParameters, ICurrencyManager {
    CurrencyManager private currencyManager;
    MockERC20 private mockERC20;

    function setUp() public asPrankedUser(_owner) {
        currencyManager = new CurrencyManager();
        mockERC20 = new MockERC20();
    }

    function testAddCurrency() public asPrankedUser(_owner) {
        vm.expectEmit(true, false, false, true);
        emit CurrencyWhitelisted(address(mockERC20));
        currencyManager.addCurrency(address(mockERC20));
        assertTrue(currencyManager.isCurrencyWhitelisted(address(mockERC20)));
    }

    function testAddCurrencyNotOwner() public {
        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        currencyManager.addCurrency(address(mockERC20));
    }

    function testAddCurrencyNotContract() public asPrankedUser(_owner) {
        vm.expectRevert(abi.encodeWithSelector(ICurrencyManager.CurrencyNotContract.selector, address(1)));
        currencyManager.addCurrency(address(1));
    }

    function testAddCurrencyAlreadyWhitelisted() public asPrankedUser(_owner) {
        currencyManager.addCurrency(address(mockERC20));
        assertTrue(currencyManager.isCurrencyWhitelisted(address(mockERC20)));

        vm.expectRevert(
            abi.encodeWithSelector(ICurrencyManager.CurrencyAlreadyWhitelisted.selector, address(mockERC20))
        );
        currencyManager.addCurrency(address(mockERC20));
    }

    function testRemoveCurrency() public asPrankedUser(_owner) {
        currencyManager.addCurrency(address(mockERC20));

        vm.expectEmit(true, false, false, true);
        emit CurrencyRemoved(address(mockERC20));
        currencyManager.removeCurrency(address(mockERC20));
        assertTrue(!currencyManager.isCurrencyWhitelisted(address(mockERC20)));
    }

    function testRemoveCurrencyNotOwner() public {
        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        currencyManager.removeCurrency(address(mockERC20));
    }

    function testRemoveCurrencyNotWhitelisted() public asPrankedUser(_owner) {
        vm.expectRevert(abi.encodeWithSelector(ICurrencyManager.CurrencyNotWhitelisted.selector, address(mockERC20)));
        currencyManager.removeCurrency(address(mockERC20));
    }
}
