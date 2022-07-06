// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {RoyaltyFeeRegistry} from "@looksrare/contracts-exchange-v1/contracts/royaltyFeeHelpers/royaltyFeeRegistry.sol";
import {LooksRareProtocol} from "../../contracts/LooksRareProtocol.sol";
import {TransferManager} from "../../contracts/TransferManager.sol";
import {ReferralStaking} from "../../contracts/ReferralStaking.sol";
import {TestHelpers} from "./TestHelpers.sol";
import {MockERC20} from "./utils/MockERC20.sol";

// Test cases TODO
// Deposit -> WithdrawAll
// Deposit -> Increase deposit -> WithdrawAll
// Deposit -> Increase deposit -> Downgrade -> WithdrawAll
// Deposit -> Update tier -> Downgrade -> WithdrawAll
// registerReferrer -> unregisterReferrer

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
}
