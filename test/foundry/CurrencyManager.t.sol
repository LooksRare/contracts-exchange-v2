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

    function testupdateCurrencyWhitelistStatus() public asPrankedUser(_owner) {
        // Set to true
        vm.expectEmit(true, false, false, true);
        emit CurrencyWhitelistStatusUpdated(address(mockERC20), true);
        currencyManager.updateCurrencyWhitelistStatus(address(mockERC20), true);
        assertTrue(currencyManager.isCurrencyWhitelisted(address(mockERC20)) == 1);

        // Set to false
        vm.expectEmit(true, false, false, true);
        emit CurrencyWhitelistStatusUpdated(address(mockERC20), false);
        currencyManager.updateCurrencyWhitelistStatus(address(mockERC20), false);
        assertTrue(currencyManager.isCurrencyWhitelisted(address(mockERC20)) == 0);
    }

    function testupdateCurrencyWhitelistStatusNotOwner() public {
        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        currencyManager.updateCurrencyWhitelistStatus(address(mockERC20), true);
    }
}
