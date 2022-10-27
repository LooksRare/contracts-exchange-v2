// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";
import {ReferralStaking} from "../../contracts/ReferralStaking.sol";
import {ProtocolBase} from "./ProtocolBase.t.sol";
import {IReferralStaking} from "../../contracts/interfaces/IReferralStaking.sol";
import {MockERC20} from "../mock/MockERC20.sol";

contract ReferralOrdersTest is ProtocolBase {
    ReferralStaking public referralStaking;
    MockERC20 public mockERC20; // It is used as LOOKS for this test

    // Tiers for this test file
    uint16 internal _referralTier0 = 1000;
    uint16 internal _referralTier1 = 2000;
    uint256 internal _tier0Cost = 10 ether;
    uint256 internal _tier1Cost = 20 ether;

    function _calculateReferralFee(uint256 originalAmount, uint256 tierRate)
        private
        pure
        returns (uint256 referralFee)
    {
        return (originalAmount * tierRate) / (10000 * 10000);
    }

    function _setUpReferralStaking() private asPrankedUser(_owner) {
        mockERC20 = new MockERC20();
        referralStaking = new ReferralStaking(address(looksRareProtocol), address(mockERC20), _timelock);
        referralStaking.setTier(0, _referralTier0, _tier0Cost);
        referralStaking.setTier(1, _referralTier1, _tier1Cost);
        looksRareProtocol.updateReferralController(address(referralStaking));
        looksRareProtocol.updateReferralProgramStatus(true);
    }

    function _setUpReferrer() private asPrankedUser(_referrer) {
        vm.deal(_referrer, _initialETHBalanceReferrer + _initialWETHBalanceReferrer);
        weth.deposit{value: _initialWETHBalanceReferrer}();
        mockERC20.mint(_referrer, _tier1Cost);
        mockERC20.approve(address(referralStaking), type(uint256).max);
        referralStaking.upgrade(1, _referralTier1, _tier1Cost);
    }

    /**
     * TakerBid matches makerAsk. Protocol fee is set, no royalties, referrer is set.
     */
    function testTakerBidERC721WithReferralButWithoutRoyalty() public {
        _setUpUsers();
        _setUpReferralStaking();
        _setUpReferrer();

        price = 1 ether; // Fixed price of sale
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
                makerAsk.minPrice,
                makerAsk.itemIds,
                makerAsk.amounts,
                emptyAdditionalRecipients,
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
                _referrer
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
        assertEq(address(_referrer).balance, _initialETHBalanceReferrer + referralFee);
        // Owner receives 80% of protocol fee
        assertEq(
            address(_owner).balance,
            _initialETHBalanceOwner + ((price * _standardProtocolFee) / 10000 - referralFee)
        );
        // No leftover in the balance of the contract
        assertEq(address(looksRareProtocol).balance, 0);
        // Verify the nonce is marked as executed
        assertTrue(looksRareProtocol.userOrderNonce(makerUser, makerAsk.orderNonce));
    }

    /**
     * Multiple takerBids match makerAsk orders. Protocol fee is set, no royalties, referrer is set.
     */
    function testMultipleTakerBidsERC721WithReferralButWithoutRoyalty() public {
        _setUpUsers();
        _setUpReferralStaking();
        _setUpReferrer();

        price = 1 ether;
        uint256 numberPurchases = 8;
        uint256 faultyTokenId = numberPurchases - 1;
        uint16 minNetRatio = 9800;

        OrderStructs.MakerAsk[] memory makerAsks = new OrderStructs.MakerAsk[](numberPurchases);
        OrderStructs.TakerBid[] memory takerBids = new OrderStructs.TakerBid[](numberPurchases);
        bytes[] memory signatures = new bytes[](numberPurchases);

        for (uint256 i; i < numberPurchases; i++) {
            // Mint asset
            mockERC721.mint(makerUser, i);

            // Prepare the order hash
            makerAsks[i] = _createSingleItemMakerAskOrder(
                0, // askNonce
                0, // subsetNonce
                0, // strategyId (Standard sale for fixed price)
                0, // assetType ERC721,
                uint112(i), // orderNonce
                address(mockERC721),
                address(0), // ETH,
                makerUser,
                price, // Fixed
                i // itemId (0, 1, etc.)
            );

            // Sign order
            signatures[i] = _signMakerAsk(makerAsks[i], makerUserPK);

            takerBids[i] = OrderStructs.TakerBid(
                takerUser,
                makerAsks[i].minPrice,
                makerAsks[i].itemIds,
                makerAsks[i].amounts,
                emptyAdditionalRecipients,
                abi.encode()
            );
        }

        // Transfer tokenId=2 to random user
        address randomUser = address(55);

        vm.prank(makerUser);
        mockERC721.transferFrom(makerUser, randomUser, faultyTokenId);

        // Taker user actions
        vm.startPrank(takerUser);

        {
            // Other execution parameters
            OrderStructs.MerkleRoot[] memory merkleRoots = new OrderStructs.MerkleRoot[](numberPurchases);
            bytes32[][] memory merkleProofs = new bytes32[][](numberPurchases);

            // Execute taker bid transaction
            looksRareProtocol.executeMultipleTakerBids{value: price * numberPurchases}(
                takerBids,
                makerAsks,
                signatures,
                merkleRoots,
                merkleProofs,
                _referrer,
                false
            );
        }

        vm.stopPrank();

        for (uint256 i; i < faultyTokenId; i++) {
            // Taker user has received the first two assets
            assertEq(mockERC721.ownerOf(i), takerUser);
            // Verify the first two nonces are marked as executed
            assertTrue(looksRareProtocol.userOrderNonce(makerUser, uint112(i)));
        }

        // Taker user has not received the asset
        assertEq(mockERC721.ownerOf(faultyTokenId), randomUser);
        // Verify the nonce is NOT marked as executed
        assertFalse(looksRareProtocol.userOrderNonce(makerUser, uint112(faultyTokenId)));
        // Taker bid user pays the whole price
        assertEq(address(takerUser).balance, _initialETHBalanceUser - ((numberPurchases - 1) * price));
        // Maker ask user receives 98% of the whole price (2% protocol)
        assertEq(
            address(makerUser).balance,
            _initialETHBalanceUser + ((price * minNetRatio) * (numberPurchases - 1)) / 10000
        );
        // Referral user receives 20% of protocol fee
        uint256 referralFee = _calculateReferralFee(
            (numberPurchases - 1) * price * _standardProtocolFee,
            _referralTier1
        );
        assertEq(address(_referrer).balance, _initialETHBalanceReferrer + referralFee);
        // Owner receives 80% of protocol fee
        assertEq(
            address(_owner).balance,
            _initialETHBalanceOwner + (((numberPurchases - 1) * (price * _standardProtocolFee)) / 10000 - referralFee)
        );
        // No leftover in the balance of the contract
        assertEq(address(looksRareProtocol).balance, 0);
    }

    /**
     * TakerAsk matches makerBid. Protocol fee is set, no royalties, referrer is set.
     */
    function testTakerAskERC721WithReferralButWithoutRoyalty() public {
        _setUpUsers();
        _setUpReferralStaking();
        _setUpReferrer();

        price = 1 ether; // Fixed price of sale
        uint256 itemId = 0; // TokenId
        uint16 minNetRatio = 10000 - _standardProtocolFee;

        {
            // Prepare the order hash
            makerBid = _createSingleItemMakerBidOrder(
                0, // askNonce
                0, // subsetNonce
                0, // strategyId (Standard sale for fixed price)
                0, // assetType ERC721,
                0, // orderNonce
                address(mockERC721),
                address(weth),
                makerUser,
                price,
                itemId
            );

            // Sign order
            signature = _signMakerBid(makerBid, makerUserPK);
        }

        // Taker user actions
        vm.startPrank(takerUser);

        {
            // Mint asset
            mockERC721.mint(takerUser, itemId);

            // Prepare the taker ask
            takerAsk = OrderStructs.TakerAsk(
                takerUser,
                makerBid.maxPrice,
                makerBid.itemIds,
                makerBid.amounts,
                abi.encode()
            );
        }

        {
            uint256 gasLeft = gasleft();

            // Execute taker ask transaction
            looksRareProtocol.executeTakerAsk(
                takerAsk,
                makerBid,
                signature,
                _emptyMerkleRoot,
                _emptyMerkleProof,
                _referrer
            );
            emit log_named_uint(
                "TakerAsk // ERC721 // Protocol Fee with Referral // No Royalties",
                gasLeft - gasleft()
            );
        }

        vm.stopPrank();
        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(itemId), makerUser);
        // Maker bid user pays the whole price
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser - price);
        // Taker ask user receives 98% of whole price (protocol fee)
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser + (price * minNetRatio) / 10000);
        // Referral user receives 20% of protocol fee
        uint256 referralFee = _calculateReferralFee(price * _standardProtocolFee, _referralTier1);
        assertEq(weth.balanceOf(_referrer), _initialWETHBalanceReferrer + referralFee);
        // Owner receives 80% of protocol fee
        assertEq(
            weth.balanceOf(_owner),
            _initialWETHBalanceOwner + ((price * _standardProtocolFee) / 10000 - referralFee)
        );
        // Verify the nonce is marked as executed
        assertTrue(looksRareProtocol.userOrderNonce(makerUser, makerBid.orderNonce));
    }
}
