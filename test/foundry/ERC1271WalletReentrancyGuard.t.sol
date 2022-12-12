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
    MaliciousERC1271Wallet maliciousERC1271Wallet;

    function setUp() public override {
        super.setUp();
        maliciousERC1271Wallet = new MaliciousERC1271Wallet(address(looksRareProtocol));
        _setUpUser(address(maliciousERC1271Wallet));
        _setUpUser(takerUser);
        _setupRegistryRoyalties(address(mockERC721), _standardRoyaltyFee);
    }

    /**
     * One ERC721 (where royalties come from the registry) is sold through a taker bid
     */
    function testTakerBidReentrancy() public {
        maliciousERC1271Wallet.setFunctionToReenter(MaliciousERC1271Wallet.FunctionToReenter.ExecuteTakerBid);

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
                address(maliciousERC1271Wallet),
                price,
                itemId
            );

            signature = new bytes(0);
        }

        // Taker user actions
        vm.startPrank(takerUser);

        // Prepare the taker bid
        takerBid = OrderStructs.TakerBid(
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
        maliciousERC1271Wallet.setFunctionToReenter(MaliciousERC1271Wallet.FunctionToReenter.ExecuteTakerAsk);

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
                address(maliciousERC1271Wallet),
                price,
                itemId
            );

            signature = new bytes(0);
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

        vm.expectRevert(IReentrancyGuard.ReentrancyFail.selector);
        // Execute taker ask transaction
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _emptyMerkleTree, _emptyAffiliate);

        vm.stopPrank();
    }

    // /**
    //  * Three ERC721 are sold through 3 taker bids in one transaction with non-atomicity.
    //  */
    // function testThreeTakerBidsERC721() public {
    //     _setUpUsers();

    //     uint256 numberPurchases = 3;
    //     price = 1 ether;

    //     OrderStructs.MakerAsk[] memory makerAsks = new OrderStructs.MakerAsk[](numberPurchases);
    //     OrderStructs.TakerBid[] memory takerBids = new OrderStructs.TakerBid[](numberPurchases);
    //     bytes[] memory signatures = new bytes[](numberPurchases);

    //     for (uint256 i; i < numberPurchases; i++) {
    //         // Mint asset
    //         mockERC721.mint(makerUser, i);

    //         // Prepare the order hash
    //         makerAsks[i] = _createSingleItemMakerAskOrder(
    //             0, // askNonce
    //             0, // subsetNonce
    //             0, // strategyId (Standard sale for fixed price)
    //             0, // assetType ERC721,
    //             i, // orderNonce
    //             address(mockERC721),
    //             address(0), // ETH,
    //             makerUser,
    //             price, // Fixed
    //             i // itemId (0, 1, etc.)
    //         );

    //         // Sign order
    //         signatures[i] = _signMakerAsk(makerAsks[i], makerUserPK);

    //         takerBids[i] = OrderStructs.TakerBid(
    //             takerUser,
    //             makerAsks[i].minPrice,
    //             makerAsks[i].itemIds,
    //             makerAsks[i].amounts,
    //             abi.encode()
    //         );
    //     }

    //     // Taker user actions
    //     vm.startPrank(takerUser);

    //     {
    //         // Other execution parameters
    //         OrderStructs.MerkleTree[] memory merkleTrees = new OrderStructs.MerkleTree[](numberPurchases);

    //         uint256 gasLeft = gasleft();

    //         // Execute taker bid transaction
    //         looksRareProtocol.executeMultipleTakerBids{value: price * numberPurchases}(
    //             takerBids,
    //             makerAsks,
    //             signatures,
    //             merkleTrees,
    //             _emptyAffiliate,
    //             false
    //         );
    //         emit log_named_uint(
    //             "TakerBid (3 items) // Non-atomic // ERC721 // Protocol Fee // No Royalties",
    //             gasLeft - gasleft()
    //         );
    //     }

    //     vm.stopPrank();

    //     for (uint256 i; i < numberPurchases; i++) {
    //         // Taker user has received the asset
    //         assertEq(mockERC721.ownerOf(i), takerUser);
    //         // Verify the nonce is marked as executed
    //         assertEq(looksRareProtocol.userOrderNonce(makerUser, i), MAGIC_VALUE_NONCE_EXECUTED);
    //     }
    //     // Taker bid user pays the whole price
    //     assertEq(address(takerUser).balance, _initialETHBalanceUser - (numberPurchases * price));
    //     // Maker ask user receives 98% of the whole price (2% protocol)
    //     assertEq(address(makerUser).balance, _initialETHBalanceUser + ((price * 9_800) * numberPurchases) / 10_000);
    //     // No leftover in the balance of the contract
    //     assertEq(address(looksRareProtocol).balance, 0);
    // }

    // /**
    //  * Transaction cannot go through if atomic, goes through if non-atomic (fund returns to buyer).
    //  */
    // function testThreeTakerBidsERC721OneFails() public {
    //     _setUpUsers();

    //     uint256 numberPurchases = 3;
    //     price = 1 ether;
    //     uint256 faultyTokenId = numberPurchases - 1;

    //     OrderStructs.MakerAsk[] memory makerAsks = new OrderStructs.MakerAsk[](numberPurchases);
    //     OrderStructs.TakerBid[] memory takerBids = new OrderStructs.TakerBid[](numberPurchases);
    //     bytes[] memory signatures = new bytes[](numberPurchases);

    //     for (uint256 i; i < numberPurchases; i++) {
    //         // Mint asset
    //         mockERC721.mint(makerUser, i);

    //         // Prepare the order hash
    //         makerAsks[i] = _createSingleItemMakerAskOrder(
    //             0, // askNonce
    //             0, // subsetNonce
    //             0, // strategyId (Standard sale for fixed price)
    //             0, // assetType ERC721,
    //             i, // orderNonce
    //             address(mockERC721),
    //             address(0), // ETH,
    //             makerUser,
    //             price, // Fixed
    //             i // itemId (0, 1, etc.)
    //         );

    //         // Sign order
    //         signatures[i] = _signMakerAsk(makerAsks[i], makerUserPK);

    //         takerBids[i] = OrderStructs.TakerBid(
    //             takerUser,
    //             makerAsks[i].minPrice,
    //             makerAsks[i].itemIds,
    //             makerAsks[i].amounts,
    //             abi.encode()
    //         );
    //     }

    //     // Transfer tokenId=2 to random user
    //     address randomUser = address(55);
    //     vm.prank(makerUser);
    //     mockERC721.transferFrom(makerUser, randomUser, faultyTokenId);

    //     // Taker user actions
    //     vm.startPrank(takerUser);

    //     /**
    //      * 1. The whole purchase fails if execution is atomic
    //      */
    //     {
    //         // Other execution parameters
    //         OrderStructs.MerkleTree[] memory merkleTrees = new OrderStructs.MerkleTree[](numberPurchases);

    //         // NFTTransferFail(address collection, uint8 assetType);
    //         vm.expectRevert(
    //             abi.encodeWithSelector(
    //                 ITransferSelectorNFT.NFTTransferFail.selector,
    //                 makerAsks[faultyTokenId].collection,
    //                 uint8(0)
    //             )
    //         );
    //         looksRareProtocol.executeMultipleTakerBids{value: price * numberPurchases}(
    //             takerBids,
    //             makerAsks,
    //             signatures,
    //             merkleTrees,
    //             _emptyAffiliate,
    //             true
    //         );
    //     }

    //     /**
    //      * 2. The whole purchase doesn't fail if execution is not-atomic
    //      */
    //     {
    //         // Other execution parameters
    //         OrderStructs.MerkleTree[] memory merkleTrees = new OrderStructs.MerkleTree[](numberPurchases);

    //         // Execute taker bid transaction
    //         looksRareProtocol.executeMultipleTakerBids{value: price * numberPurchases}(
    //             takerBids,
    //             makerAsks,
    //             signatures,
    //             merkleTrees,
    //             _emptyAffiliate,
    //             false
    //         );
    //     }

    //     vm.stopPrank();

    //     for (uint256 i; i < faultyTokenId; i++) {
    //         // Taker user has received the first two assets
    //         assertEq(mockERC721.ownerOf(i), takerUser);
    //         // Verify the first two nonces are marked as executed
    //         assertEq(looksRareProtocol.userOrderNonce(makerUser, i), MAGIC_VALUE_NONCE_EXECUTED);
    //     }

    //     // Taker user has not received the asset
    //     assertEq(mockERC721.ownerOf(faultyTokenId), randomUser);
    //     // Verify the nonce is NOT marked as executed
    //     assertEq(looksRareProtocol.userOrderNonce(makerUser, faultyTokenId), bytes32(0));
    //     // Taker bid user pays the whole price
    //     assertEq(address(takerUser).balance, _initialETHBalanceUser - 1 - ((numberPurchases - 1) * price));
    //     // Maker ask user receives 98% of the whole price (2% protocol)
    //     assertEq(
    //         address(makerUser).balance,
    //         _initialETHBalanceUser + ((price * 9_800) * (numberPurchases - 1)) / 10_000
    //     );
    //     // 1 wei left in the balance of the contract
    //     assertEq(address(looksRareProtocol).balance, 1);
    // }
}
