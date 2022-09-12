// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";
import {ReferralStaking} from "../../contracts/ReferralStaking.sol";
import {ProtocolBase} from "./ProtocolBase.t.sol";
import {IReferralStaking} from "../../contracts/interfaces/IReferralStaking.sol";
import {MockERC20} from "../mock/MockERC20.sol";

contract ReferralOrdersTest is ProtocolBase {
    ReferralStaking public referralStaking;
    MockERC20 public mockERC20;

    // Tiers for this test file
    uint16 internal _referralTier0 = 1000;
    uint16 internal _referralTier1 = 2000;
    uint256 internal _tier0Cost = 10 ether;
    uint256 internal _tier1Cost = 20 ether;

    function _calculateReferralFee(uint256 originalAmount, uint256 tierRate) internal returns (uint256) {
        return (originalAmount * tierRate) / (10000 * 10000);
    }

    function _setUpReferralStaking() public asPrankedUser(_owner) {
        mockERC20 = new MockERC20();
        referralStaking = new ReferralStaking(address(looksRareProtocol), address(mockERC20), _timelock);
        referralStaking.setTier(0, _referralTier0, _tier0Cost);
        referralStaking.setTier(1, _referralTier1, _tier1Cost);
        looksRareProtocol.updateReferralController(address(referralStaking));
        looksRareProtocol.updateReferralProgramStatus(true);
    }

    function _setUpReferrer() public asPrankedUser(_referrerUser) {
        vm.deal(_referrerUser, _initialETHBalanceReferrer + _initialWETHBalanceReferrer);
        weth.deposit{value: _initialWETHBalanceReferrer}();
        mockERC20.mint(_referrerUser, _tier1Cost);
        mockERC20.approve(address(referralStaking), type(uint256).max);
        referralStaking.deposit(1, _tier1Cost);
    }

    /**
     * TakerBid matches makerAsk but protocol fee was discontinued for this strategy using the discount function.
     */
    function testTakerBidERC721WithReferralButWithoutRoyalty() public {
        _setUpUsers();
        _setUpReferralStaking();
        _setUpReferrer();

        uint256 price = 1 ether; // Fixed price of sale
        uint256 itemId = 0; // TokenId
        uint16 minNetRatio = 10000 - _standardProtocolFee;

        {
            // Mint asset
            mockERC721.mint(makerUser, itemId);

            // Prepare the order hash
            makerAsk = _createSingleItemMakerAskOrder(
                0, // askNonce
                0, // subsetNonce
                0, // strategyId (Standard sale for fixed price)
                0, // assetType ERC721,
                0, // orderNonce
                minNetRatio,
                address(mockERC721),
                address(0), // ETH,
                makerUser,
                price,
                itemId
            );

            // Sign order
            signature = _signMakerAsk(makerAsk, makerUserPK);
        }

        // Taker user actions
        vm.startPrank(takerUser);

        {
            // Prepare the taker bid
            takerBid = OrderStructs.TakerBid(
                takerUser,
                makerAsk.minNetRatio,
                makerAsk.minPrice,
                makerAsk.itemIds,
                makerAsk.amounts,
                abi.encode()
            );
        }

        {
            uint256 gasLeft = gasleft();

            // Execute taker bid transaction
            looksRareProtocol.executeTakerBid{value: price}(
                takerBid,
                makerAsk,
                signature,
                _emptyMerkleRoot,
                _emptyMerkleProof,
                _referrerUser
            );
            emit log_named_uint(
                "TakerBid // ERC721 // Protocol Fee with Referral // No Royalties",
                gasLeft - gasleft()
            );
        }

        vm.stopPrank();

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(itemId), takerUser);
        // Taker bid user pays the whole price
        assertEq(address(takerUser).balance, _initialETHBalanceUser - price);
        // Maker ask user receives 98% of the whole price (2% protocol)
        assertEq(address(makerUser).balance, _initialETHBalanceUser + (price * minNetRatio) / 10000);
        // Referral user receives 20% of protocol fee
        uint256 referralFee = _calculateReferralFee(price * _standardProtocolFee, _referralTier1);
        assertEq(address(_referrerUser).balance, _initialETHBalanceReferrer + referralFee);
        // Owner receives 80% of protocol fee
        assertEq(
            address(_owner).balance,
            _initialETHBalanceOwner + ((price * _standardProtocolFee) / 10000 - referralFee)
        );
        // No leftover in the balance of the contract
        assertEq(address(looksRareProtocol).balance, 0);
        // Verify the nonce is marked as executed
        assertTrue(looksRareProtocol.viewUserOrderNonce(makerUser, makerAsk.orderNonce));
    }
}
