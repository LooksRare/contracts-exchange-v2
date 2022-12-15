// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Libraries
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";

// Mocks and other tests
import {ProtocolBase} from "./ProtocolBase.t.sol";
import {MockERC20} from "../mock/MockERC20.sol";

contract AffiliateOrdersTest is ProtocolBase {
    // Affiliate rate
    uint256 internal _affiliateRate = 2_000;
    uint256 private constant price = 1 ether; // Fixed price of sale

    function _calculateAffiliateFee(
        uint256 originalAmount,
        uint256 tierRate
    ) private pure returns (uint256 affiliateFee) {
        affiliateFee = (originalAmount * tierRate) / (10_000 * 10_000);
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

        uint256 itemId = 0; // TokenId

        // Mint asset
        mockERC721.mint(makerUser, itemId);

        // Prepare the order hash
        OrderStructs.MakerAsk memory makerAsk = _createSingleItemMakerAskOrder({
            askNonce: 0,
            subsetNonce: 0,
            strategyId: 0, // Standard sale for fixed price
            assetType: 0, // ERC721,
            orderNonce: 0,
            collection: address(mockERC721),
            currency: address(0), // ETH,
            signer: makerUser,
            minPrice: price,
            itemId: itemId
        });

        // Sign order
        bytes memory signature = _signMakerAsk(makerAsk, makerUserPK);

        // Taker user actions
        vm.startPrank(takerUser);

        // Prepare the taker bid
        OrderStructs.TakerBid memory takerBid = OrderStructs.TakerBid(
            takerUser,
            makerAsk.minPrice,
            makerAsk.itemIds,
            makerAsk.amounts,
            abi.encode()
        );

        {
            uint256 gasLeft = gasleft();

            // Execute taker bid transaction
            looksRareProtocol.executeTakerBid{value: price}(
                takerBid,
                makerAsk,
                signature,
                _emptyMerkleTree,
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
        assertEq(address(makerUser).balance, _initialETHBalanceUser + (price * (10_000 - _minTotalFee)) / 10_000);
        // Affiliate user receives 20% of protocol fee
        uint256 affiliateFee = _calculateAffiliateFee(price * _minTotalFee, _affiliateRate);
        assertEq(address(_affiliate).balance, _initialETHBalanceAffiliate + affiliateFee);
        // Owner receives 80% of protocol fee
        assertEq(address(_owner).balance, _initialETHBalanceOwner + ((price * _minTotalFee) / 10_000 - affiliateFee));
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

        uint256 numberPurchases = 8;
        uint256 faultyTokenId = numberPurchases - 1;

        OrderStructs.MakerAsk[] memory makerAsks = new OrderStructs.MakerAsk[](numberPurchases);
        OrderStructs.TakerBid[] memory takerBids = new OrderStructs.TakerBid[](numberPurchases);
        bytes[] memory signatures = new bytes[](numberPurchases);

        for (uint256 i; i < numberPurchases; i++) {
            // Mint asset
            mockERC721.mint(makerUser, i);

            // Prepare the order hash
            makerAsks[i] = _createSingleItemMakerAskOrder({
                askNonce: 0,
                subsetNonce: 0,
                strategyId: 0, // Standard sale for fixed price
                assetType: 0, // ERC721,
                orderNonce: i,
                collection: address(mockERC721),
                currency: address(0), // ETH,
                signer: makerUser,
                minPrice: price,
                itemId: i // (0, 1, etc.)
            });

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
            OrderStructs.MerkleTree[] memory merkleTrees = new OrderStructs.MerkleTree[](numberPurchases);

            // Execute taker bid transaction
            looksRareProtocol.executeMultipleTakerBids{value: price * numberPurchases}(
                takerBids,
                makerAsks,
                signatures,
                merkleTrees,
                _affiliate,
                false
            );
        }

        vm.stopPrank();

        for (uint256 i; i < faultyTokenId; i++) {
            // Taker user has received the first two assets
            assertEq(mockERC721.ownerOf(i), takerUser);
            // Verify the first two nonces are marked as executed
            assertEq(looksRareProtocol.userOrderNonce(makerUser, i), MAGIC_VALUE_NONCE_EXECUTED);
        }

        // Taker user has not received the asset
        assertEq(mockERC721.ownerOf(faultyTokenId), randomUser);
        // Verify the nonce is NOT marked as executed
        assertEq(looksRareProtocol.userOrderNonce(makerUser, faultyTokenId), bytes32(0));
        // Taker bid user pays the whole price
        assertEq(address(takerUser).balance, _initialETHBalanceUser - 1 - ((numberPurchases - 1) * price));
        // Maker ask user receives 98% of the whole price (2% protocol)
        assertEq(
            address(makerUser).balance,
            _initialETHBalanceUser + ((price * 9_800) * (numberPurchases - 1)) / 10_000
        );
        // Affiliate user receives 20% of protocol fee
        uint256 affiliateFee = _calculateAffiliateFee((numberPurchases - 1) * price * _minTotalFee, _affiliateRate);
        assertEq(address(_affiliate).balance, _initialETHBalanceAffiliate + affiliateFee);
        // Owner receives 80% of protocol fee
        assertEq(
            address(_owner).balance,
            _initialETHBalanceOwner + (((numberPurchases - 1) * (price * _minTotalFee)) / 10_000 - affiliateFee)
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

        uint256 itemId = 0; // TokenId

        // Prepare the order hash
        OrderStructs.MakerBid memory makerBid = _createSingleItemMakerBidOrder({
            bidNonce: 0,
            subsetNonce: 0,
            strategyId: 0, // Standard sale for fixed price
            assetType: 0, // ERC721,
            orderNonce: 0,
            collection: address(mockERC721),
            currency: address(weth),
            signer: makerUser,
            maxPrice: price,
            itemId: itemId
        });

        // Sign order
        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        // Taker user actions
        vm.startPrank(takerUser);

        // Mint asset
        mockERC721.mint(takerUser, itemId);

        // Prepare the taker ask
        OrderStructs.TakerAsk memory takerAsk = OrderStructs.TakerAsk(
            takerUser,
            makerBid.maxPrice,
            makerBid.itemIds,
            makerBid.amounts,
            abi.encode()
        );

        {
            uint256 gasLeft = gasleft();

            // Execute taker ask transaction
            looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _emptyMerkleTree, _affiliate);
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
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser + (price * 9_800) / 10_000);
        // Affiliate user receives 20% of protocol fee
        uint256 affiliateFee = _calculateAffiliateFee(price * _minTotalFee, _affiliateRate);
        assertEq(weth.balanceOf(_affiliate), _initialWETHBalanceAffiliate + affiliateFee);
        // Owner receives 80% of protocol fee
        assertEq(weth.balanceOf(_owner), _initialWETHBalanceOwner + ((price * _minTotalFee) / 10_000 - affiliateFee));
        // Verify the nonce is marked as executed
        assertEq(looksRareProtocol.userOrderNonce(makerUser, makerBid.orderNonce), MAGIC_VALUE_NONCE_EXECUTED);
    }
}
