// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Libraries and interfaces
import {ITransferSelectorNFT} from "../../contracts/interfaces/ITransferSelectorNFT.sol";
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";

// Base test
import {ProtocolBase} from "./ProtocolBase.t.sol";

contract DelegationRecipientsTakerTest is ProtocolBase {
    // Fixed price of sale
    uint256 private constant price = 1 ether;

    /**
     * One ERC721 is sold through a taker ask using WETH and the proceeds of the sale goes to a random recipient.
     */
    function testTakerAskERC721WithRoyaltiesFromRegistry() public {
        address randomRecipientSaleProceeds = address(420);

        _setUpUsers();
        _setupRegistryRoyalties(address(mockERC721), _standardRoyaltyFee);

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

        // Verify maker bid order
        _isMakerBidOrderValid(makerBid, signature);

        // Mint asset
        mockERC721.mint(takerUser, itemId);

        // Prepare the taker ask
        OrderStructs.TakerAsk memory takerAsk = OrderStructs.TakerAsk(
            randomRecipientSaleProceeds,
            makerBid.maxPrice,
            makerBid.itemIds,
            makerBid.amounts,
            abi.encode()
        );

        // Execute taker ask transaction
        vm.prank(takerUser);

        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(itemId), makerUser);
        // Maker bid user pays the whole price
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser - price);
        // Random recipient user receives 98% of the whole price and taker user receives nothing.
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser);
        assertEq(weth.balanceOf(randomRecipientSaleProceeds), (price * 9_800) / 10_000);

        // Royalty recipient receives 0.5% of the whole price
        assertEq(
            weth.balanceOf(_royaltyRecipient),
            _initialWETHBalanceRoyaltyRecipient + (price * _standardRoyaltyFee) / 10_000
        );
        // Verify the nonce is marked as executed
        assertEq(looksRareProtocol.userOrderNonce(makerUser, makerBid.orderNonce), MAGIC_VALUE_ORDER_NONCE_EXECUTED);
    }

    /**
     * One ERC721 is sold through a taker bid and the NFT transfer goes to a random recipient.
     */
    function testTakerBidERC721WithRoyaltiesFromRegistry() public {
        address randomRecipientNFT = address(420);

        _setUpUsers();
        _setupRegistryRoyalties(address(mockERC721), _standardRoyaltyFee);

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

        // Verify validity of maker ask order
        _isMakerAskOrderValid(makerAsk, signature);

        // Prepare the taker bid
        OrderStructs.TakerBid memory takerBid = OrderStructs.TakerBid(
            randomRecipientNFT,
            makerAsk.minPrice,
            makerAsk.itemIds,
            makerAsk.amounts,
            abi.encode()
        );

        // Execute taker bid transaction
        vm.prank(takerUser);

        looksRareProtocol.executeTakerBid{value: price}(
            takerBid,
            makerAsk,
            signature,
            _EMPTY_MERKLE_TREE,
            _EMPTY_AFFILIATE
        );

        // Random recipient user has received the asset
        assertEq(mockERC721.ownerOf(itemId), randomRecipientNFT);
        // Taker bid user pays the whole price
        assertEq(address(takerUser).balance, _initialETHBalanceUser - price);
        // Maker ask user receives 98% of the whole price (2%)
        assertEq(address(makerUser).balance, _initialETHBalanceUser + (price * 9_800) / 10_000);
        // Royalty recipient receives 0.5% of the whole price
        assertEq(
            address(_royaltyRecipient).balance,
            _initialETHBalanceRoyaltyRecipient + (price * _standardRoyaltyFee) / 10_000
        );
        // No leftover in the balance of the contract
        assertEq(address(looksRareProtocol).balance, 0);
        // Verify the nonce is marked as executed
        assertEq(looksRareProtocol.userOrderNonce(makerUser, makerAsk.orderNonce), MAGIC_VALUE_ORDER_NONCE_EXECUTED);
    }
}
