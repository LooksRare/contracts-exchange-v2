// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {RoyaltyFeeRegistry} from "@looksrare/contracts-exchange-v1/contracts/royaltyFeeHelpers/royaltyFeeRegistry.sol";
import {OwnableTwoSteps} from "@looksrare/contracts-libs/contracts/OwnableTwoSteps.sol";
import {LooksRareProtocol} from "../../contracts/LooksRareProtocol.sol";
import {TransferManager} from "../../contracts/TransferManager.sol";
import {ReferralStaking} from "../../contracts/ReferralStaking.sol";
import {TestHelpers} from "./TestHelpers.sol";
import {MockERC20} from "./utils/MockERC20.sol";

contract ReferralStakingTest is TestHelpers {
    MockERC20 public mockERC20;
    RoyaltyFeeRegistry public royaltyFeeRegistry;
    TransferManager public transferManager;
    LooksRareProtocol public looksRareProtocol;
    ReferralStaking public referralStaking;

    address owner = address(1);
    address user = address(2);

    function setUp() public {
        vm.startPrank(owner);

        royaltyFeeRegistry = new RoyaltyFeeRegistry(9500);
        transferManager = new TransferManager();
        looksRareProtocol = new LooksRareProtocol(address(transferManager), address(royaltyFeeRegistry));
        mockERC20 = new MockERC20();
        referralStaking = new ReferralStaking(address(looksRareProtocol), address(mockERC20));

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

    function testOwnerOnly() public asPrankedUser(user) {
        // Make sure that owner functions can't be used by a user
        vm.expectRevert(OwnableTwoSteps.NotOwner.selector);
        referralStaking.registerReferrer(user, 0);

        vm.expectRevert(OwnableTwoSteps.NotOwner.selector);
        referralStaking.unregisterReferrer(user);

        vm.expectRevert(OwnableTwoSteps.NotOwner.selector);
        referralStaking.setTier(1, 1000, 10 ether);
    }

    function testSetTierAndGetTier() public asPrankedUser(owner) {
        // Test initial state after setup
        assertEq(referralStaking.numberOfTiers(), 2, "Wrong number of tiers");
        assertEq(referralStaking.viewTier(0).rate, 1000, "Wrong tier value");
        assertEq(referralStaking.viewTier(0).stake, 10 ether, "Wrong tier value");
        assertEq(referralStaking.viewTier(1).rate, 2000, "Wrong tier value");
        assertEq(referralStaking.viewTier(1).stake, 20 ether, "Wrong tier value");

        // Add a new tier
        referralStaking.setTier(2, 3000, 30 ether);
        assertEq(referralStaking.numberOfTiers(), 3, "Wrong number of tiers");
        assertEq(referralStaking.viewTier(2).rate, 3000, "Wrong tier value");
        assertEq(referralStaking.viewTier(2).stake, 30 ether, "Wrong tier value");

        // Update existing tier
        referralStaking.setTier(2, 3500, 35 ether);
        assertEq(referralStaking.numberOfTiers(), 3, "Wrong number of tiers");
        assertEq(referralStaking.viewTier(2).rate, 3500, "Wrong tier value");
        assertEq(referralStaking.viewTier(2).stake, 35 ether, "Wrong tier value");

        // Add tier at invalid index
        vm.expectRevert("Use an existing index to update a tier, or use numberOfTiers to create a new tier");
        referralStaking.setTier(4, 1000, 30 ether);
    }

    function testRegisterUnregister() public asPrankedUser(owner) {
        // Use wrong tier id
        vm.expectRevert(ReferralStaking.StakingTierDoesntExist.selector);
        referralStaking.registerReferrer(user, 2);

        // Register and unregister
        referralStaking.registerReferrer(user, 0);
        referralStaking.unregisterReferrer(user);
    }

    function testDepositWithdraw() public asPrankedUser(user) {
        // Withdraw without depositing first
        vm.expectRevert(ReferralStaking.NoFundsStaked.selector);
        referralStaking.withdrawAll();

        // Deposit for non existing tier
        vm.expectRevert(ReferralStaking.StakingTierDoesntExist.selector);
        referralStaking.deposit(100, 1 ether);

        // Deposit invalid amount
        vm.expectRevert(ReferralStaking.WrongDepositAmount.selector);
        referralStaking.deposit(0, 1 ether);

        // Deposit valid amount
        referralStaking.deposit(0, 10 ether);
        assertEq(referralStaking.viewUserStake(user), 10 ether);
        assertEq(mockERC20.balanceOf(address(referralStaking)), 10 ether);

        // Withdraw everything
        referralStaking.withdrawAll();
        assertEq(referralStaking.viewUserStake(user), 0);
    }

    function testIncreaseDeposit() public asPrankedUser(user) {
        // Deposit and increase stake
        referralStaking.deposit(0, 10 ether);

        // Deposit on the wrong tier
        vm.expectRevert(ReferralStaking.WrongDepositAmount.selector);
        referralStaking.deposit(0, 10 ether);

        // Deposit the wrong amount (needs +10 for the next level)
        vm.expectRevert(ReferralStaking.WrongDepositAmount.selector);
        referralStaking.deposit(1, 20 ether);

        // Increase stake
        referralStaking.deposit(1, 10 ether);
        assertEq(referralStaking.viewUserStake(user), 20 ether);

        // Withdraw everything
        referralStaking.withdrawAll();
        assertEq(referralStaking.viewUserStake(user), 0);
    }

    function testDowngrade() public {
        // Add a new tier for the purpose of this test
        vm.startPrank(owner);
        referralStaking.setTier(2, 3000, 30 ether);
        vm.stopPrank();

        vm.startPrank(user);
        referralStaking.deposit(1, 20 ether);

        // Downgrade to a non existing tier
        vm.expectRevert(ReferralStaking.StakingTierDoesntExist.selector);
        referralStaking.downgrade(3);

        // Downgrade to a higher tier
        vm.expectRevert(ReferralStaking.TierTooHigh.selector);
        referralStaking.downgrade(2);

        // Downgrade to the current tier
        vm.expectRevert(ReferralStaking.TierTooHigh.selector);
        referralStaking.downgrade(1);

        // Downgrade
        referralStaking.downgrade(0);
        assertEq(referralStaking.viewUserStake(user), 10 ether);

        // Withdraw everything
        referralStaking.withdrawAll();
        assertEq(referralStaking.viewUserStake(user), 0);

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

        // Withdraw unused tokens
        vm.startPrank(user);
        referralStaking.downgrade(1);
        assertEq(referralStaking.viewUserStake(user), 15 ether);
        vm.stopPrank();
    }
}
