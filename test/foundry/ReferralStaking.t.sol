// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {RoyaltyFeeRegistry} from "@looksrare/contracts-exchange-v1/contracts/royaltyFeeHelpers/RoyaltyFeeRegistry.sol";
import {IOwnableTwoSteps, OwnableTwoSteps} from "@looksrare/contracts-libs/contracts/OwnableTwoSteps.sol";
import {IERC20} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC20.sol";

import {LooksRareProtocol} from "../../contracts/LooksRareProtocol.sol";
import {TransferManager} from "../../contracts/TransferManager.sol";
import {IReferralStaking, ReferralStaking} from "../../contracts/ReferralStaking.sol";
import {MockERC20} from "../mock/MockERC20.sol";
import {TestHelpers} from "./utils/TestHelpers.sol";
import {TestParameters} from "./utils/TestParameters.sol";

contract ReferralTestParameters {
    // IERC20 Transfer event
    event Transfer(address indexed from, address indexed to, uint256 value);

    uint16 internal _tier0Rate = 1000;
    uint16 internal _tier1Rate = 2000;
    uint256 internal _tier0Stake = 10 ether;
    uint256 internal _tier1Stake = 20 ether;
}

contract ReferralStakingTest is
    TestHelpers,
    TestParameters,
    ReferralTestParameters,
    IReferralStaking,
    IOwnableTwoSteps
{
    MockERC20 public mockERC20;
    RoyaltyFeeRegistry public royaltyFeeRegistry;
    TransferManager public transferManager;
    LooksRareProtocol public looksRareProtocol;
    ReferralStaking public referralStaking;

    function setUp() public {
        vm.startPrank(_owner);
        royaltyFeeRegistry = new RoyaltyFeeRegistry(9500);
        transferManager = new TransferManager();
        looksRareProtocol = new LooksRareProtocol(address(transferManager), address(royaltyFeeRegistry));
        mockERC20 = new MockERC20();
        referralStaking = new ReferralStaking(address(looksRareProtocol), address(mockERC20), _timelock);

        referralStaking.setTier(0, _tier0Rate, _tier0Stake);
        referralStaking.setTier(1, _tier1Rate, _tier1Stake);
        looksRareProtocol.updateReferralController(address(referralStaking));
        vm.stopPrank();

        uint256 amountErc20 = 100 ether;
        mockERC20.mint(_referrer, amountErc20);
        vm.prank(_referrer);
        mockERC20.approve(address(referralStaking), amountErc20);
    }

    // Owner functions

    function testOwnerOnly() public asPrankedUser(_referrer) {
        // Make sure that owner functions can't be used by a _referrer
        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        referralStaking.updateReferrerRate(_referrer, 0);

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
        assertEq(referralStaking.viewTier(0).rate, _tier0Rate, "Wrong tier value");
        assertEq(referralStaking.viewTier(0).stake, _tier0Stake, "Wrong tier value");
        assertEq(referralStaking.viewTier(1).rate, _tier1Rate, "Wrong tier value");
        assertEq(referralStaking.viewTier(1).stake, _tier1Stake, "Wrong tier value");

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
        referralStaking.updateReferrerRate(_referrer, 2);

        // Register and unregister
        referralStaking.setTier(1, 1000, 30 ether);
        referralStaking.updateReferrerRate(_referrer, 1);
        referralStaking.updateReferrerRate(_referrer, 0);
        referralStaking.removeLastTier();
        vm.stopPrank();
    }

    function testPossibleToSetATierWithNoLOOKS() public {
        uint16 rate = 1000;
        uint16 stake = 0 ether;

        // Tier0 is adjusted for no LOOKS
        vm.prank(_owner);
        referralStaking.setTier(0, rate, stake);

        Tier memory tier = referralStaking.viewTier(0);
        assertEq(tier.stake, stake);
        assertEq(tier.rate, rate);

        // User register without deposit
        vm.startPrank(_referrer);
        referralStaking.upgrade(0, rate, stake);

        UserStatus memory userStatus = referralStaking.viewUserStatus(_referrer);
        assertEq(userStatus.stake, stake);
        assertEq(looksRareProtocol.referrerRates(_referrer), rate);
        assertEq(mockERC20.balanceOf(address(referralStaking)), stake);

        vm.warp(block.timestamp + _timelock);
        referralStaking.withdrawAll();
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
    }

    // Public functions

    function testDepositWithdraw() public asPrankedUser(_referrer) {
        // Withdraw without depositing first
        vm.expectRevert(IReferralStaking.NoFundsStaked.selector);
        referralStaking.withdrawAll();

        // Deposit for non existing tier
        vm.expectRevert(IReferralStaking.StakingTierDoesntExist.selector);
        referralStaking.upgrade(100, 100, 1 ether);

        // Deposit invalid amount
        vm.expectRevert(IReferralStaking.WrongDepositAmount.selector);
        referralStaking.upgrade(0, _tier0Rate, _tier0Stake + 1);
        vm.expectRevert(IReferralStaking.WrongDepositAmount.selector);
        referralStaking.upgrade(0, _tier0Rate, _tier0Stake - 1);

        // Deposit with wrong rate
        vm.expectRevert(IReferralStaking.WrongTierRate.selector);
        referralStaking.upgrade(0, _tier0Rate + 1, _tier0Stake);
        vm.expectRevert(IReferralStaking.WrongTierRate.selector);
        referralStaking.upgrade(0, _tier0Rate - 1, _tier0Stake);

        // Deposit valid amount
        vm.expectEmit(false, false, false, true);
        emit Deposit(_referrer, 0);
        referralStaking.upgrade(0, _tier0Rate, _tier0Stake);
        UserStatus memory userStatus = referralStaking.viewUserStatus(_referrer);
        assertEq(userStatus.stake, _tier0Stake);
        assertEq(mockERC20.balanceOf(address(referralStaking)), _tier0Stake);
        assertEq(userStatus.earliestWithdrawalTimestamp, block.timestamp + _timelock);

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

        userStatus = referralStaking.viewUserStatus(_referrer);
        assertEq(userStatus.stake, 0);
        assertEq(mockERC20.balanceOf(address(referralStaking)), 0);
    }

    function testIncreaseDeposit() public asPrankedUser(_referrer) {
        // Deposit and increase stake
        referralStaking.upgrade(0, _tier0Rate, _tier0Stake);

        // Deposit on the wrong tier
        vm.expectRevert(IReferralStaking.WrongDepositAmount.selector);
        referralStaking.upgrade(0, _tier0Rate, _tier0Stake);

        // Deposit on the wrong rate
        vm.expectRevert(IReferralStaking.WrongTierRate.selector);
        referralStaking.upgrade(1, _tier0Rate, _tier1Stake - _tier0Stake);

        // Deposit the wrong amount (needs +10 for the next level)
        vm.expectRevert(IReferralStaking.WrongDepositAmount.selector);
        referralStaking.upgrade(1, _tier1Rate, _tier1Stake);

        // Increase stake
        vm.expectEmit(true, true, false, true, address(mockERC20));
        emit Transfer(_referrer, address(referralStaking), (_tier1Stake - _tier0Stake));
        referralStaking.upgrade(1, _tier1Rate, _tier1Stake - _tier0Stake);

        UserStatus memory userStatus = referralStaking.viewUserStatus(_referrer);
        assertEq(userStatus.stake, _tier1Stake);
        assertEq(mockERC20.balanceOf(address(referralStaking)), _tier1Stake);
    }

    function testDowngrade() public {
        // Add a new tier for the purpose of this test
        uint16 tier2Rate = 3000;
        uint256 tier2Stake = 30 ether;

        require(tier2Stake > _tier1Stake, "Stake lower than previous tier");

        vm.prank(_owner);
        referralStaking.setTier(2, tier2Rate, tier2Stake);

        vm.startPrank(_referrer);
        referralStaking.upgrade(1, _tier1Rate, _tier1Stake);

        // Downgrade to a non existing tier
        vm.expectRevert(IReferralStaking.StakingTierDoesntExist.selector);
        referralStaking.downgrade(3, tier2Rate);

        // Downgrade to a higher tier
        vm.expectRevert(IReferralStaking.TierTooHigh.selector);
        referralStaking.downgrade(2, tier2Rate);

        // Downgrade to the current tier
        vm.expectRevert(IReferralStaking.TierTooHigh.selector);
        referralStaking.downgrade(1, _tier1Rate);

        // Downgrade before the end of the _timelock
        vm.expectRevert(IReferralStaking.FundsTimelocked.selector);
        referralStaking.downgrade(0, _tier0Rate);
        vm.warp(block.timestamp + _timelock - 1);
        vm.expectRevert(IReferralStaking.FundsTimelocked.selector);
        referralStaking.downgrade(0, _tier0Rate);

        // Downgrade
        vm.warp(block.timestamp + _timelock);
        vm.expectEmit(false, false, false, true);
        emit Downgrade(_referrer, 0);
        referralStaking.downgrade(0, _tier0Rate);
        vm.stopPrank();

        UserStatus memory userStatus = referralStaking.viewUserStatus(_referrer);
        assertEq(userStatus.stake, 10 ether);
        assertEq(mockERC20.balanceOf(address(referralStaking)), 10 ether);
    }

    function testUpdateSameTierAndDowngrade() public {
        uint16 newTier1Rate = 2000;
        uint256 newTier1Stake = 15 ether;

        // Initial deposit
        vm.prank(_referrer);
        referralStaking.upgrade(1, _tier1Rate, _tier1Stake);

        // Reduce staking requirements
        vm.prank(_owner);
        referralStaking.setTier(1, newTier1Rate, newTier1Stake);

        // Withdraw unused tokens
        vm.warp(block.timestamp + _timelock);
        vm.prank(_referrer);
        vm.expectEmit(true, true, false, true, address(mockERC20));
        emit Transfer(address(referralStaking), _referrer, (_tier1Stake - newTier1Stake));
        referralStaking.downgrade(1, newTier1Rate);

        UserStatus memory userStatus = referralStaking.viewUserStatus(_referrer);
        assertEq(userStatus.stake, newTier1Stake);
        assertEq(mockERC20.balanceOf(address(referralStaking)), newTier1Stake);
    }

    function testUpdateSameTierAndUpgrade() public {
        uint16 newTier1Rate = 2000;
        uint256 newTier1Stake = 30 ether;

        // Initial deposit
        vm.prank(_referrer);
        referralStaking.upgrade(1, _tier1Rate, _tier1Stake);

        // Increase staking requirements
        vm.prank(_owner);

        referralStaking.setTier(1, newTier1Rate, newTier1Stake);

        // Deposit more tokens to stay on same tier while increasing rate
        vm.prank(_referrer);
        vm.expectEmit(true, true, false, true, address(mockERC20));
        emit Transfer(_referrer, address(referralStaking), (newTier1Stake - _tier1Stake));
        referralStaking.upgrade(1, newTier1Rate, newTier1Stake - _tier1Stake);

        UserStatus memory userStatus = referralStaking.viewUserStatus(_referrer);
        assertEq(userStatus.stake, newTier1Stake);
        assertEq(mockERC20.balanceOf(address(referralStaking)), newTier1Stake);
    }
}
