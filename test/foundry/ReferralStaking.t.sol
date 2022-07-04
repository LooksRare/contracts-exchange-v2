// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {RoyaltyFeeRegistry} from "@looksrare/contracts-exchange-v1/contracts/royaltyFeeHelpers/royaltyFeeRegistry.sol";
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

        vm.stopPrank();

        uint256 amountErc20 = 100 ether;
        mockERC20.mint(address(1), amountErc20);
        mockERC20.approve(address(referralStaking), amountErc20);
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
}
