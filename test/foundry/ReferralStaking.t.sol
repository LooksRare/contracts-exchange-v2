// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {RoyaltyFeeRegistry} from "@looksrare/contracts-exchange-v1/contracts/royaltyFeeHelpers/RoyaltyFeeRegistry.sol";
import {OwnableTwoSteps} from "@looksrare/contracts-libs/contracts/OwnableTwoSteps.sol";
import {LooksRareProtocol} from "../../contracts/LooksRareProtocol.sol";
import {TransferManager} from "../../contracts/TransferManager.sol";
import {ReferralStaking} from "../../contracts/ReferralStaking.sol";
import {IReferralStaking} from "../../contracts/interfaces/IReferralStaking.sol";
import {TestHelpers} from "./utils/TestHelpers.sol";
import {MockERC20} from "../mock/MockERC20.sol";

contract ReferralStakingTest is TestHelpers, IReferralStaking {
    MockERC20 public mockERC20;
    RoyaltyFeeRegistry public royaltyFeeRegistry;
    TransferManager public transferManager;
    LooksRareProtocol public looksRareProtocol;
    ReferralStaking public referralStaking;

    address owner = address(1);
    address user = address(2);

    uint256 constant timelock = 120;

    function setUp() public {
        vm.startPrank(owner);

        royaltyFeeRegistry = new RoyaltyFeeRegistry(9500);
        transferManager = new TransferManager();
        looksRareProtocol = new LooksRareProtocol(address(transferManager), address(royaltyFeeRegistry));
        mockERC20 = new MockERC20();
        referralStaking = new ReferralStaking(address(looksRareProtocol), address(mockERC20), timelock);

        referralStaking.setTier(0, 1000, 10 ether);
        referralStaking.setTier(1, 2000, 20 ether);
        looksRareProtocol.updateReferralController(address(referralStaking));

        vm.stopPrank();

        vm.startPrank(user);

        uint256 amountErc20 = 100 ether;
        mockERC20.mint(user, amountErc20);
        mockERC20.approve(address(referralStaking), amountErc20);

        vm.stopPrank();
    }

    // Owner functions

    function testOwnerOnly() public asPrankedUser(user) {
        // Make sure that owner functions can't be used by a user
        vm.expectRevert(OwnableTwoSteps.NotOwner.selector);
        referralStaking.registerReferrer(user, 0);

        vm.expectRevert(OwnableTwoSteps.NotOwner.selector);
        referralStaking.unregisterReferrer(user);

        vm.expectRevert(OwnableTwoSteps.NotOwner.selector);
        referralStaking.setTier(1, 1000, 10 ether);

        vm.expectRevert(OwnableTwoSteps.NotOwner.selector);
        referralStaking.setTimelockPeriod(60);

        vm.expectRevert(OwnableTwoSteps.NotOwner.selector);
        referralStaking.removeLastTier();
    }

    function testSetTierAndGetTier() public asPrankedUser(owner) {
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
        vm.startPrank(owner);

        // Use wrong tier id
        vm.expectRevert(IReferralStaking.StakingTierDoesntExist.selector);
        referralStaking.registerReferrer(user, 2);

        // Register and unregister
        referralStaking.registerReferrer(user, 0);
        referralStaking.unregisterReferrer(user);

        vm.stopPrank();

        // User deposit first, and can't be registered after
        vm.startPrank(user);
        referralStaking.deposit(0, 10 ether);
        vm.stopPrank();

        vm.startPrank(owner);
        vm.expectRevert(IReferralStaking.UserAlreadyStaking.selector);
        referralStaking.registerReferrer(user, 0);
        vm.stopPrank();
    }

    function testSetTimelock() public asPrankedUser(owner) {
        // Set a timelock out of boundaries
        vm.expectRevert("Time lock too high");
        referralStaking.setTimelockPeriod(31 days);

        // Assert previous timelock, and the setter
        assertEq(referralStaking.timelockPeriod(), timelock);
        vm.expectEmit(false, false, false, true);
        emit UpdateTimelock(60);
        referralStaking.setTimelockPeriod(60);
        assertEq(referralStaking.timelockPeriod(), 60);

        // Test the getter returning the timelock
        (uint256 lastDepositTimestamp, uint256 timelockPeriod) = referralStaking.viewUserTimelock(user);
        assertEq(lastDepositTimestamp, 0);
        assertEq(timelockPeriod, 60);
    }

    // Public functions

    function testDepositWithdraw() public asPrankedUser(user) {
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
        emit Deposit(user, 0);
        referralStaking.deposit(0, 10 ether);
        assertEq(referralStaking.viewUserStake(user), 10 ether);
        assertEq(mockERC20.balanceOf(address(referralStaking)), 10 ether);
        (uint256 lastDepositTimestamp, ) = referralStaking.viewUserTimelock(user);
        assertEq(lastDepositTimestamp, block.timestamp);

        // Withdraw before the end of the timelock
        vm.expectRevert(IReferralStaking.FundsTimelocked.selector);
        referralStaking.withdrawAll();
        vm.warp(block.timestamp + timelock - 1);
        vm.expectRevert(IReferralStaking.FundsTimelocked.selector);
        referralStaking.withdrawAll();

        // Withdraw everything
        vm.warp(block.timestamp + timelock);
        vm.expectEmit(false, false, false, true);
        emit WithdrawAll(user);
        referralStaking.withdrawAll();
        assertEq(referralStaking.viewUserStake(user), 0);
        assertEq(mockERC20.balanceOf(address(referralStaking)), 0);
    }

    function testIncreaseDeposit() public asPrankedUser(user) {
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
        assertEq(referralStaking.viewUserStake(user), 20 ether);
        assertEq(mockERC20.balanceOf(address(referralStaking)), 20 ether);
    }

    function testDowngrade() public {
        // Add a new tier for the purpose of this test
        vm.startPrank(owner);
        referralStaking.setTier(2, 3000, 30 ether);
        vm.stopPrank();

        vm.startPrank(user);
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

        // Downgrade before the end of the timelock
        vm.expectRevert(IReferralStaking.FundsTimelocked.selector);
        referralStaking.downgrade(0);
        vm.warp(block.timestamp + timelock - 1);
        vm.expectRevert(IReferralStaking.FundsTimelocked.selector);
        referralStaking.downgrade(0);

        // Downgrade
        vm.warp(block.timestamp + timelock);
        vm.expectEmit(false, false, false, true);
        emit Downgrade(user, 0);
        referralStaking.downgrade(0);
        assertEq(referralStaking.viewUserStake(user), 10 ether);
        assertEq(mockERC20.balanceOf(address(referralStaking)), 10 ether);

        vm.stopPrank();
    }

    function testUpdateTierAndDowngrade() public {
        // Initial deposit
        vm.startPrank(user);
        referralStaking.deposit(1, 20 ether);
        vm.stopPrank();

        // Reduce staking requirements
        vm.startPrank(owner);
        referralStaking.setTier(1, 2000, 15 ether);
        vm.stopPrank();

        vm.startPrank(user);

        // Withdraw unused tokens
        vm.warp(block.timestamp + timelock);
        referralStaking.downgrade(1);
        assertEq(referralStaking.viewUserStake(user), 15 ether);
        assertEq(mockERC20.balanceOf(address(referralStaking)), 15 ether);

        vm.stopPrank();
    }
}
