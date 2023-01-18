// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Libraries and interfaces
import {IReentrancyGuard} from "@looksrare/contracts-libs/contracts/interfaces/IReentrancyGuard.sol";
import {ITransferSelectorNFT} from "../../contracts/interfaces/ITransferSelectorNFT.sol";
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";

// Base test
import {ProtocolBase} from "./ProtocolBase.t.sol";

// Mocks and other utils
import {PotentiallyMaliciousERC1271Wallet} from "./utils/PotentiallyMaliciousERC1271Wallet.sol";

contract ERC1271WalletReentrancyGuardTest is ProtocolBase {
    uint256 private constant price = 1 ether; // Fixed price of sale
    uint256 private constant itemId = 0;
    bytes private constant signature = new bytes(0);

    PotentiallyMaliciousERC1271Wallet private potentiallyMaliciousERC1271Wallet;

    function setUp() public override {
        super.setUp();
        _setUpUser(takerUser);
        _setupRegistryRoyalties(address(mockERC721), _standardRoyaltyFee);

        potentiallyMaliciousERC1271Wallet = new PotentiallyMaliciousERC1271Wallet(address(looksRareProtocol));
        _setUpUser(address(potentiallyMaliciousERC1271Wallet));
    }

    /**
     * One ERC721 (where royalties come from the registry) is sold through a taker bid
     */
    function testTakerBidReentrancy() public {
        potentiallyMaliciousERC1271Wallet.setFunctionToReenter(
            PotentiallyMaliciousERC1271Wallet.FunctionToReenter.ExecuteTakerBid
        );

        // Mint asset
        mockERC721.mint(address(potentiallyMaliciousERC1271Wallet), itemId);

        // Prepare the order hash
        OrderStructs.MakerAsk memory makerAsk = _createSingleItemMakerAskOrder({
            askNonce: 0,
            subsetNonce: 0,
            strategyId: 0, // Standard sale for fixed price
            assetType: 0, // ERC721
            orderNonce: 0,
            collection: address(mockERC721),
            currency: address(0), // ETH
            signer: address(potentiallyMaliciousERC1271Wallet),
            minPrice: price,
            itemId: itemId
        });

        // Prepare the taker bid
        OrderStructs.TakerBid memory takerBid = OrderStructs.TakerBid(
            takerUser,
            makerAsk.minPrice,
            makerAsk.itemIds,
            makerAsk.amounts,
            abi.encode()
        );

        vm.expectRevert(IReentrancyGuard.ReentrancyFail.selector);
        vm.startPrank(takerUser);
        looksRareProtocol.executeTakerBid{value: price}(
            takerBid,
            makerAsk,
            signature,
            _EMPTY_MERKLE_TREE,
            _EMPTY_AFFILIATE
        );

        // Remove re-entrancy
        potentiallyMaliciousERC1271Wallet.setFunctionToReenter(
            PotentiallyMaliciousERC1271Wallet.FunctionToReenter.None
        );

        looksRareProtocol.executeTakerBid{value: price}(
            takerBid,
            makerAsk,
            signature,
            _EMPTY_MERKLE_TREE,
            _EMPTY_AFFILIATE
        );

        assertEq(mockERC721.ownerOf(itemId), takerUser);

        vm.stopPrank();
    }

    function testTakerAskReentrancy() public {
        potentiallyMaliciousERC1271Wallet.setFunctionToReenter(
            PotentiallyMaliciousERC1271Wallet.FunctionToReenter.ExecuteTakerAsk
        );

        // Prepare the order hash
        OrderStructs.MakerBid memory makerBid = _createSingleItemMakerBidOrder({
            bidNonce: 0,
            subsetNonce: 0,
            strategyId: 0, // Standard sale for fixed price
            assetType: 0, // ERC721
            orderNonce: 0,
            collection: address(mockERC721),
            currency: address(weth),
            signer: address(potentiallyMaliciousERC1271Wallet),
            maxPrice: price,
            itemId: itemId
        });

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

        vm.expectRevert(IReentrancyGuard.ReentrancyFail.selector);
        // Execute taker ask transaction
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);

        // Remove re-entrancy
        potentiallyMaliciousERC1271Wallet.setFunctionToReenter(
            PotentiallyMaliciousERC1271Wallet.FunctionToReenter.None
        );

        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);

        assertEq(mockERC721.ownerOf(itemId), address(potentiallyMaliciousERC1271Wallet));

        vm.stopPrank();
    }

    function testExecuteMultipleTakerBidsReentrancy() public {
        potentiallyMaliciousERC1271Wallet.setFunctionToReenter(
            PotentiallyMaliciousERC1271Wallet.FunctionToReenter.ExecuteMultipleTakerBids
        );

        uint256 numberPurchases = 3;

        OrderStructs.MakerAsk[] memory makerAsks = new OrderStructs.MakerAsk[](numberPurchases);
        OrderStructs.TakerBid[] memory takerBids = new OrderStructs.TakerBid[](numberPurchases);
        bytes[] memory signatures = new bytes[](numberPurchases);

        for (uint256 i; i < numberPurchases; i++) {
            // Mint asset
            mockERC721.mint(address(potentiallyMaliciousERC1271Wallet), i);

            // Prepare the order hash
            makerAsks[i] = _createSingleItemMakerAskOrder({
                askNonce: 0,
                subsetNonce: 0,
                strategyId: 0, // Standard sale for fixed price
                assetType: 0, // ERC721
                orderNonce: i,
                collection: address(mockERC721),
                currency: address(0), // ETH
                signer: address(potentiallyMaliciousERC1271Wallet),
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

        // Other execution parameters
        OrderStructs.MerkleTree[] memory merkleTrees = new OrderStructs.MerkleTree[](numberPurchases);

        vm.expectRevert(IReentrancyGuard.ReentrancyFail.selector);
        vm.startPrank(takerUser);
        looksRareProtocol.executeMultipleTakerBids{value: price * numberPurchases}(
            takerBids,
            makerAsks,
            signatures,
            merkleTrees,
            _EMPTY_AFFILIATE,
            false
        );

        // Remove re-entrancy
        potentiallyMaliciousERC1271Wallet.setFunctionToReenter(
            PotentiallyMaliciousERC1271Wallet.FunctionToReenter.None
        );

        looksRareProtocol.executeMultipleTakerBids{value: price * numberPurchases}(
            takerBids,
            makerAsks,
            signatures,
            merkleTrees,
            _EMPTY_AFFILIATE,
            false
        );

        assertEq(mockERC721.ownerOf(0), takerUser);
        assertEq(mockERC721.ownerOf(1), takerUser);
        assertEq(mockERC721.ownerOf(2), takerUser);

        vm.stopPrank();
    }
}
