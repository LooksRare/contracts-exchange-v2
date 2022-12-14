// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Libraries and interfaces
import {IReentrancyGuard} from "@looksrare/contracts-libs/contracts/interfaces/IReentrancyGuard.sol";
import {ITransferSelectorNFT} from "../../contracts/interfaces/ITransferSelectorNFT.sol";
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";

// Base test
import {ProtocolBase} from "./ProtocolBase.t.sol";

// Mocks and other utils
import {MaliciousERC1271Wallet} from "./utils/MaliciousERC1271Wallet.sol";

contract ERC1271WalletReentrancyGuardTest is ProtocolBase {
    function setUp() public override {
        super.setUp();
        _setUpUser(takerUser);
        _setupRegistryRoyalties(address(mockERC721), _standardRoyaltyFee);
    }

    /**
     * One ERC721 (where royalties come from the registry) is sold through a taker bid
     */
    function testTakerBidReentrancy() public {
        MaliciousERC1271Wallet maliciousERC1271Wallet = new MaliciousERC1271Wallet(address(looksRareProtocol));
        _setUpUser(address(maliciousERC1271Wallet));
        maliciousERC1271Wallet.setFunctionToReenter(MaliciousERC1271Wallet.FunctionToReenter.ExecuteTakerBid);

        price = 1 ether; // Fixed price of sale
        uint256 itemId = 0; // TokenId

        // Mint asset
        mockERC721.mint(makerUser, itemId);

        // Prepare the order hash
        OrderStructs.MakerAsk memory makerAsk = _createSingleItemMakerAskOrder({
            askNonce: 0,
            subsetNonce: 0, // subsetNonce
            strategyId: 0, // Standard sale for fixed price
            assetType: 0, // ERC721,
            orderNonce: 0, // orderNonce
            collection: address(mockERC721),
            currency: address(0), // ETH,
            signer: address(maliciousERC1271Wallet),
            minPrice: price,
            itemId: itemId
        });

        signature = new bytes(0);

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

        vm.expectRevert(IReentrancyGuard.ReentrancyFail.selector);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerBid{value: price}(
            takerBid,
            makerAsk,
            signature,
            _emptyMerkleTree,
            _emptyAffiliate
        );

        vm.stopPrank();
    }

    function testTakerAskReentrancy() public {
        MaliciousERC1271Wallet maliciousERC1271Wallet = new MaliciousERC1271Wallet(address(looksRareProtocol));
        _setUpUser(address(maliciousERC1271Wallet));
        maliciousERC1271Wallet.setFunctionToReenter(MaliciousERC1271Wallet.FunctionToReenter.ExecuteTakerAsk);

        price = 1 ether; // Fixed price of sale
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
            signer: address(maliciousERC1271Wallet),
            maxPrice: price,
            itemId: itemId
        });

        signature = new bytes(0);

        // Taker user actions
        vm.startPrank(takerUser);

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

        vm.expectRevert(IReentrancyGuard.ReentrancyFail.selector);
        // Execute taker ask transaction
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _emptyMerkleTree, _emptyAffiliate);

        vm.stopPrank();
    }

    function testExecuteMultipleTakerBidsReentrancy() public {
        MaliciousERC1271Wallet maliciousERC1271Wallet = new MaliciousERC1271Wallet(address(looksRareProtocol));
        _setUpUser(address(maliciousERC1271Wallet));
        maliciousERC1271Wallet.setFunctionToReenter(MaliciousERC1271Wallet.FunctionToReenter.ExecuteMultipleTakerBids);

        uint256 numberPurchases = 3;
        price = 1 ether;

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
                assetType: 0, // ERC721
                orderNonce: i,
                collection: address(mockERC721),
                currency: address(0), // ETH,
                signer: address(maliciousERC1271Wallet),
                minPrice: price,
                itemId: i // 0, 1, etc.
            });

            signatures[i] = new bytes(0);

            takerBids[i] = OrderStructs.TakerBid(
                takerUser,
                makerAsks[i].minPrice,
                makerAsks[i].itemIds,
                makerAsks[i].amounts,
                abi.encode()
            );
        }

        // Taker user actions
        vm.startPrank(takerUser);

        {
            // Other execution parameters
            OrderStructs.MerkleTree[] memory merkleTrees = new OrderStructs.MerkleTree[](numberPurchases);

            vm.expectRevert(IReentrancyGuard.ReentrancyFail.selector);
            // Execute taker bid transaction
            looksRareProtocol.executeMultipleTakerBids{value: price * numberPurchases}(
                takerBids,
                makerAsks,
                signatures,
                merkleTrees,
                _emptyAffiliate,
                false
            );
        }

        vm.stopPrank();
    }
}
