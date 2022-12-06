// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";
import {ProtocolBase} from "./ProtocolBase.t.sol";
import {MockERC20} from "../mock/MockERC20.sol";

contract AffiliateOrdersTest is ProtocolBase {
    MockERC20 public mockERC20; // It is used as LOOKS for this test

    uint256 internal _affiliateRate = 2_000;

    function _calculateAffiliateFee(
        uint256 originalAmount,
        uint256 tierRate
    ) private pure returns (uint256 affiliateFee) {
        return (originalAmount * tierRate) / (10000 * 10000);
    }

    function _setUpAffiliate() private {
        vm.startPrank(_owner);
        looksRareProtocol.updateAffiliateController(_owner);
        looksRareProtocol.updateAffiliateProgramStatus(true);
        looksRareProtocol.updateAffiliateRate(_affiliate, _affiliateRate);
        vm.stopPrank();

        vm.startPrank(_affiliate);
        vm.deal(_affiliate, _initialETHBalanceAffiliate + _initialWETHBalanceAffiliate);
        weth.deposit{value: _initialWETHBalanceAffiliate}();
        vm.stopPrank();
    }

    /**
     * TakerBid matches makerAsk. Protocol fee is set, no royalties, affiliate is set.
     */
    function testTakerBidERC721WithAffiliateButWithoutRoyalty() public {
        _setUpUsers();
        _setUpAffiliate();

        price = 1 ether; // Fixed price of sale
        uint256 itemId = 0; // TokenId

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
                _affiliate
            );
            emit log_named_uint(
                "TakerBid // ERC721 // Protocol Fee with Affiliate // No Royalties",
                gasLeft - gasleft()
            );
        }

        vm.stopPrank();

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(itemId), takerUser);
        // Taker bid user pays the whole price
        assertEq(address(takerUser).balance, _initialETHBalanceUser - price);
        // Maker ask user receives 98% of the whole price (2% protocol)
        assertEq(address(makerUser).balance, _initialETHBalanceUser + (price * (10000 - _minTotalFee)) / 10000);
        // Affiliate user receives 20% of protocol fee
        uint256 affiliateFee = _calculateAffiliateFee(price * _minTotalFee, _affiliateRate);
        assertEq(address(_affiliate).balance, _initialETHBalanceAffiliate + affiliateFee);
        // Owner receives 80% of protocol fee
        assertEq(address(_owner).balance, _initialETHBalanceOwner + ((price * _minTotalFee) / 10000 - affiliateFee));
        // No leftover in the balance of the contract
        assertEq(address(looksRareProtocol).balance, 0);
        // Verify the nonce is marked as executed
        assertEq(looksRareProtocol.userOrderNonce(makerUser, makerAsk.orderNonce), MAGIC_VALUE_NONCE_EXECUTED);
    }

    /**
     * Multiple takerBids match makerAsk orders. Protocol fee is set, no royalties, affiliate is set.
     */
    function testMultipleTakerBidsERC721WithAffiliateButWithoutRoyalty() public {
        _setUpUsers();
        _setUpAffiliate();

        price = 1 ether;
        uint256 numberPurchases = 8;
        uint256 faultyTokenId = numberPurchases - 1;

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
                _affiliate,
                false
            );
        }

        vm.stopPrank();

        for (uint256 i; i < faultyTokenId; i++) {
            // Taker user has received the first two assets
            assertEq(mockERC721.ownerOf(i), takerUser);
            // Verify the first two nonces are marked as executed
            assertEq(looksRareProtocol.userOrderNonce(makerUser, uint112(i)), MAGIC_VALUE_NONCE_EXECUTED);
        }

        // Taker user has not received the asset
        assertEq(mockERC721.ownerOf(faultyTokenId), randomUser);
        // Verify the nonce is NOT marked as executed
        assertEq(looksRareProtocol.userOrderNonce(makerUser, uint112(faultyTokenId)), bytes32(0));
        // Taker bid user pays the whole price
        assertEq(address(takerUser).balance, _initialETHBalanceUser - 1 - ((numberPurchases - 1) * price));
        // Maker ask user receives 98% of the whole price (2% protocol)
        assertEq(address(makerUser).balance, _initialETHBalanceUser + ((price * 9800) * (numberPurchases - 1)) / 10000);
        // Affiliate user receives 20% of protocol fee
        uint256 affiliateFee = _calculateAffiliateFee((numberPurchases - 1) * price * _minTotalFee, _affiliateRate);
        assertEq(address(_affiliate).balance, _initialETHBalanceAffiliate + affiliateFee);
        // Owner receives 80% of protocol fee
        assertEq(
            address(_owner).balance,
            _initialETHBalanceOwner + (((numberPurchases - 1) * (price * _minTotalFee)) / 10000 - affiliateFee)
        );
        // Only 1 wei left in the balance of the contract
        assertEq(address(looksRareProtocol).balance, 1);
    }

    /**
     * TakerAsk matches makerBid. Protocol fee is set, no royalties, affiliate is set.
     */
    function testTakerAskERC721WithAffiliateButWithoutRoyalty() public {
        _setUpUsers();
        _setUpAffiliate();

        price = 1 ether; // Fixed price of sale
        uint256 itemId = 0; // TokenId

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
                _affiliate
            );
            emit log_named_uint(
                "TakerAsk // ERC721 // Protocol Fee with Affiliate // No Royalties",
                gasLeft - gasleft()
            );
        }

        vm.stopPrank();
        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(itemId), makerUser);
        // Maker bid user pays the whole price
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser - price);
        // Taker ask user receives 98% of whole price (protocol fee)
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser + (price * 9800) / 10000);
        // Affiliate user receives 20% of protocol fee
        uint256 affiliateFee = _calculateAffiliateFee(price * _minTotalFee, _affiliateRate);
        assertEq(weth.balanceOf(_affiliate), _initialWETHBalanceAffiliate + affiliateFee);
        // Owner receives 80% of protocol fee
        assertEq(weth.balanceOf(_owner), _initialWETHBalanceOwner + ((price * _minTotalFee) / 10000 - affiliateFee));
        // Verify the nonce is marked as executed
        assertEq(looksRareProtocol.userOrderNonce(makerUser, makerBid.orderNonce), MAGIC_VALUE_NONCE_EXECUTED);
    }
}
