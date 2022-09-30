// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IOwnableTwoSteps, OwnableTwoSteps} from "@looksrare/contracts-libs/contracts/OwnableTwoSteps.sol";

import {LooksRareProtocol} from "../../contracts/LooksRareProtocol.sol";
import {TransferManager} from "../../contracts/TransferManager.sol";
import {IReferralStaking, ReferralStaking} from "../../contracts/ReferralStaking.sol";
import {MockERC20} from "../mock/MockERC20.sol";
import {MockRoyaltyFeeRegistry} from "../mock/MockRoyaltyFeeRegistry.sol";
import {TestHelpers} from "./utils/TestHelpers.sol";
import {TestParameters} from "./utils/TestParameters.sol";

contract ReferralStakingTest is TestHelpers, TestParameters, IReferralStaking, IOwnableTwoSteps {
    MockERC20 public mockERC20;
    MockRoyaltyFeeRegistry public royaltyFeeRegistry;
    TransferManager public transferManager;
    LooksRareProtocol public looksRareProtocol;
    ReferralStaking public referralStaking;

    function setUp() public {
        vm.startPrank(_owner);
        royaltyFeeRegistry = new MockRoyaltyFeeRegistry(9500);
        transferManager = new TransferManager();
        looksRareProtocol = new LooksRareProtocol(address(transferManager), address(royaltyFeeRegistry));
        mockERC20 = new MockERC20();
        referralStaking = new ReferralStaking(address(looksRareProtocol), address(mockERC20), _timelock);

        referralStaking.setTier(0, 1000, 10 ether);
        referralStaking.setTier(1, 2000, 20 ether);
        looksRareProtocol.updateReferralController(address(referralStaking));
        vm.stopPrank();

        vm.startPrank(_referrer);
        uint256 amountErc20 = 100 ether;
        mockERC20.mint(_referrer, amountErc20);
        mockERC20.approve(address(referralStaking), amountErc20);
        vm.stopPrank();
    }

    // Owner functions

    function testOwnerOnly() public asPrankedUser(_referrer) {
        // Make sure that owner functions can't be used by a _referrer
        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        referralStaking.registerReferrer(_referrer, 0);

        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        referralStaking.unregisterReferrer(_referrer);

        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        referralStaking.setTier(1, 1000, 10 ether);

        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        referralStaking.setTimelockPeriod(60);

        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        referralStaking.removeLastTier();
    }

    function testSetTierAndGetTier() public asPrankedUser(_owner) {
        // Test initial state after setup
        assertEq(referralStaking.numberOfTiers(), 2, "Wrong number of tiers");
        assertEq(referralStaking.viewTier(0).rate, 1000, "Wrong tier value");
        assertEq(referralStaking.viewTier(0).stake, 10 ether, "Wrong tier value");
        assertEq(referralStaking.viewTier(1).rate, 2000, "Wrong tier value");
        assertEq(referralStaking.viewTier(1).stake, 20 ether, "Wrong tier value");

        // Add a new tier
        vm.expectEmit(false, false, false, true);
        emit NewTier(2, 3000, 30 ether);
        referralStaking.setTier(2, 3000, 30 ether);
        assertEq(referralStaking.numberOfTiers(), 3, "Wrong number of tiers");
        assertEq(referralStaking.viewTier(2).rate, 3000, "Wrong tier value");
        assertEq(referralStaking.viewTier(2).stake, 30 ether, "Wrong tier value");

        // Update existing tier
        referralStaking.setTier(2, 3500, 35 ether);
        assertEq(referralStaking.numberOfTiers(), 3, "Wrong number of tiers");
        assertEq(referralStaking.viewTier(2).rate, 3500, "Wrong tier value");
        assertEq(referralStaking.viewTier(2).stake, 35 ether, "Wrong tier value");

        // Remove last tier
        vm.expectEmit(false, false, false, true);
        emit LastTierRemoved();
        referralStaking.removeLastTier();
        assertEq(referralStaking.numberOfTiers(), 2, "Wrong number of tiers");

        // Add tier at invalid index
        vm.expectRevert("Use an existing index to update a tier, or use numberOfTiers to create a new tier");
        referralStaking.setTier(4, 1000, 30 ether);
    }

    function testRegisterUnregister() public {
        vm.startPrank(_owner);

        // Use wrong tier id
        vm.expectRevert(IReferralStaking.StakingTierDoesntExist.selector);
        referralStaking.registerReferrer(_referrer, 2);

        // Register and unregister
        referralStaking.registerReferrer(_referrer, 0);
        referralStaking.unregisterReferrer(_referrer);

        vm.stopPrank();

        // User deposit first, and can't be registered after
        vm.startPrank(_referrer);
        referralStaking.deposit(0, 10 ether);
        vm.stopPrank();

        vm.startPrank(_owner);
        vm.expectRevert(IReferralStaking.UserAlreadyStaking.selector);
        referralStaking.registerReferrer(_referrer, 0);
        vm.stopPrank();
    }

    function testSetTimelock() public asPrankedUser(_owner) {
        // Set a _timelock out of boundaries
        vm.expectRevert("Time lock too high");
        referralStaking.setTimelockPeriod(31 days);

        // Assert previous _timelock, and the setter
        assertEq(referralStaking.timelockPeriod(), _timelock);
        vm.expectEmit(false, false, false, true);
        emit UpdateTimelock(60);
        referralStaking.setTimelockPeriod(60);
        assertEq(referralStaking.timelockPeriod(), 60);

        // Test the getter returning the _timelock
        (uint256 lastDepositTimestamp, uint256 timelockPeriod) = referralStaking.viewUserTimelock(_referrer);
        assertEq(lastDepositTimestamp, 0);
        assertEq(timelockPeriod, 60);
    }

    // Public functions

    function testDepositWithdraw() public asPrankedUser(_referrer) {
        // Withdraw without depositing first
        vm.expectRevert(IReferralStaking.NoFundsStaked.selector);
        referralStaking.withdrawAll();

        // Deposit for non existing tier
        vm.expectRevert(IReferralStaking.StakingTierDoesntExist.selector);
        referralStaking.deposit(100, 1 ether);

        // Deposit invalid amount
        vm.expectRevert(IReferralStaking.WrongDepositAmount.selector);
        referralStaking.deposit(0, 1 ether);

        // Deposit valid amount
        vm.expectEmit(false, false, false, true);
        emit Deposit(_referrer, 0);
        referralStaking.deposit(0, 10 ether);
        assertEq(referralStaking.viewUserStake(_referrer), 10 ether);
        assertEq(mockERC20.balanceOf(address(referralStaking)), 10 ether);
        (uint256 lastDepositTimestamp, ) = referralStaking.viewUserTimelock(_referrer);
        assertEq(lastDepositTimestamp, block.timestamp);

        // Withdraw before the end of the _timelock
        vm.expectRevert(IReferralStaking.FundsTimelocked.selector);
        referralStaking.withdrawAll();
        vm.warp(block.timestamp + _timelock - 1);
        vm.expectRevert(IReferralStaking.FundsTimelocked.selector);
        referralStaking.withdrawAll();

        // Withdraw everything
        vm.warp(block.timestamp + _timelock);
        vm.expectEmit(false, false, false, true);
        emit WithdrawAll(_referrer);
        referralStaking.withdrawAll();
        assertEq(referralStaking.viewUserStake(_referrer), 0);
        assertEq(mockERC20.balanceOf(address(referralStaking)), 0);
    }

    function testIncreaseDeposit() public asPrankedUser(_referrer) {
        // Deposit and increase stake
        referralStaking.deposit(0, 10 ether);

        // Deposit on the wrong tier
        vm.expectRevert(IReferralStaking.WrongDepositAmount.selector);
        referralStaking.deposit(0, 10 ether);

        // Deposit the wrong amount (needs +10 for the next level)
        vm.expectRevert(IReferralStaking.WrongDepositAmount.selector);
        referralStaking.deposit(1, 20 ether);

        // Increase stake
        referralStaking.deposit(1, 10 ether);
        assertEq(referralStaking.viewUserStake(_referrer), 20 ether);
        assertEq(mockERC20.balanceOf(address(referralStaking)), 20 ether);
    }

    function testDowngrade() public {
        // Add a new tier for the purpose of this test
        vm.startPrank(_owner);
        referralStaking.setTier(2, 3000, 30 ether);
        vm.stopPrank();

        vm.startPrank(_referrer);
        referralStaking.deposit(1, 20 ether);

        // Downgrade to a non existing tier
        vm.expectRevert(IReferralStaking.StakingTierDoesntExist.selector);
        referralStaking.downgrade(3);

        // Downgrade to a higher tier
        vm.expectRevert(IReferralStaking.TierTooHigh.selector);
        referralStaking.downgrade(2);

        // Downgrade to the current tier
        vm.expectRevert(IReferralStaking.TierTooHigh.selector);
        referralStaking.downgrade(1);

        // Downgrade before the end of the _timelock
        vm.expectRevert(IReferralStaking.FundsTimelocked.selector);
        referralStaking.downgrade(0);
        vm.warp(block.timestamp + _timelock - 1);
        vm.expectRevert(IReferralStaking.FundsTimelocked.selector);
        referralStaking.downgrade(0);

        // Downgrade
        vm.warp(block.timestamp + _timelock);
        vm.expectEmit(false, false, false, true);
        emit Downgrade(_referrer, 0);
        referralStaking.downgrade(0);
        assertEq(referralStaking.viewUserStake(_referrer), 10 ether);
        assertEq(mockERC20.balanceOf(address(referralStaking)), 10 ether);

        vm.stopPrank();
    }

    function testUpdateTierAndDowngrade() public {
        // Initial deposit
        vm.startPrank(_referrer);
        referralStaking.deposit(1, 20 ether);
        vm.stopPrank();

        // Reduce staking requirements
        vm.startPrank(_owner);
        referralStaking.setTier(1, 2000, 15 ether);
        vm.stopPrank();

        vm.startPrank(_referrer);

        // Withdraw unused tokens
        vm.warp(block.timestamp + _timelock);
        referralStaking.downgrade(1);
        assertEq(referralStaking.viewUserStake(_referrer), 15 ether);
        assertEq(mockERC20.balanceOf(address(referralStaking)), 15 ether);

        vm.stopPrank();
    }
}
