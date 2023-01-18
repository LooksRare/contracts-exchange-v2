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

contract ERC1271WalletTest is ProtocolBase {
    uint256 private constant price = 1 ether; // Fixed price of sale
    uint256 private constant itemId = 0;
    bytes private constant _EMPTY_SIGNATURE = new bytes(0);

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

        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _takerBidSetup();

        vm.expectRevert(IReentrancyGuard.ReentrancyFail.selector);
        vm.prank(takerUser);
        looksRareProtocol.executeTakerBid{value: price}(
            takerBid,
            makerAsk,
            _EMPTY_SIGNATURE,
            _EMPTY_MERKLE_TREE,
            _EMPTY_AFFILIATE
        );
    }

    function testTakerBidNoReentrancy() public {
        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _takerBidSetup();

        potentiallyMaliciousERC1271Wallet.setFunctionToReenter(
            PotentiallyMaliciousERC1271Wallet.FunctionToReenter.None
        );

        vm.prank(takerUser);
        looksRareProtocol.executeTakerBid{value: price}(
            takerBid,
            makerAsk,
            _EMPTY_SIGNATURE,
            _EMPTY_MERKLE_TREE,
            _EMPTY_AFFILIATE
        );

        assertEq(mockERC721.ownerOf(itemId), takerUser);
    }

    function testTakerAskReentrancy() public {
        potentiallyMaliciousERC1271Wallet.setFunctionToReenter(
            PotentiallyMaliciousERC1271Wallet.FunctionToReenter.ExecuteTakerAsk
        );

        (OrderStructs.TakerAsk memory takerAsk, OrderStructs.MakerBid memory makerBid) = _takerAskSetup();

        vm.expectRevert(IReentrancyGuard.ReentrancyFail.selector);
        vm.prank(takerUser);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, _EMPTY_SIGNATURE, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function testTakerAskNoReentrancy() public {
        potentiallyMaliciousERC1271Wallet.setFunctionToReenter(
            PotentiallyMaliciousERC1271Wallet.FunctionToReenter.None
        );

        (OrderStructs.TakerAsk memory takerAsk, OrderStructs.MakerBid memory makerBid) = _takerAskSetup();

        vm.prank(takerUser);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, _EMPTY_SIGNATURE, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);

        assertEq(mockERC721.ownerOf(itemId), address(potentiallyMaliciousERC1271Wallet));
    }

    uint256 private constant numberPurchases = 3;

    function testExecuteMultipleTakerBidsReentrancy() public {
        potentiallyMaliciousERC1271Wallet.setFunctionToReenter(
            PotentiallyMaliciousERC1271Wallet.FunctionToReenter.ExecuteMultipleTakerBids
        );

        (
            OrderStructs.MakerAsk[] memory makerAsks,
            OrderStructs.TakerBid[] memory takerBids,
            OrderStructs.MerkleTree[] memory merkleTrees,
            bytes[] memory signatures
        ) = _multipleTakerBidsSetup();

        vm.expectRevert(IReentrancyGuard.ReentrancyFail.selector);
        vm.prank(takerUser);
        looksRareProtocol.executeMultipleTakerBids{value: price * numberPurchases}(
            takerBids,
            makerAsks,
            signatures,
            merkleTrees,
            _EMPTY_AFFILIATE,
            false
        );
    }

    function testExecuteMultipleTakerBidsNoReentrancy() public {
        potentiallyMaliciousERC1271Wallet.setFunctionToReenter(
            PotentiallyMaliciousERC1271Wallet.FunctionToReenter.None
        );

        (
            OrderStructs.MakerAsk[] memory makerAsks,
            OrderStructs.TakerBid[] memory takerBids,
            OrderStructs.MerkleTree[] memory merkleTrees,
            bytes[] memory signatures
        ) = _multipleTakerBidsSetup();

        vm.prank(takerUser);
        looksRareProtocol.executeMultipleTakerBids{value: price * numberPurchases}(
            takerBids,
            makerAsks,
            signatures,
            merkleTrees,
            _EMPTY_AFFILIATE,
            false
        );

        for (uint256 i; i < numberPurchases; i++) {
            assertEq(mockERC721.ownerOf(i), takerUser);
        }
    }

    function _takerBidSetup()
        private
        returns (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid)
    {
        // Mint asset
        mockERC721.mint(address(potentiallyMaliciousERC1271Wallet), itemId);

        // Prepare the order hash
        makerAsk = _createSingleItemMakerAskOrder({
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
        takerBid = OrderStructs.TakerBid(
            takerUser,
            makerAsk.minPrice,
            makerAsk.itemIds,
            makerAsk.amounts,
            abi.encode()
        );
    }

    function _takerAskSetup()
        private
        returns (OrderStructs.TakerAsk memory takerAsk, OrderStructs.MakerBid memory makerBid)
    {
        // Prepare the order hash
        makerBid = _createSingleItemMakerBidOrder({
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

    function _multipleTakerBidsSetup()
        private
        returns (
            OrderStructs.MakerAsk[] memory makerAsks,
            OrderStructs.TakerBid[] memory takerBids,
            OrderStructs.MerkleTree[] memory merkleTrees,
            bytes[] memory signatures
        )
    {
        makerAsks = new OrderStructs.MakerAsk[](numberPurchases);
        takerBids = new OrderStructs.TakerBid[](numberPurchases);
        signatures = new bytes[](numberPurchases);

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

            signatures[i] = _EMPTY_SIGNATURE;

            takerBids[i] = OrderStructs.TakerBid(
                takerUser,
                makerAsks[i].minPrice,
                makerAsks[i].itemIds,
                makerAsks[i].amounts,
                abi.encode()
            );
        }

        // Other execution parameters
        merkleTrees = new OrderStructs.MerkleTree[](numberPurchases);
    }
}
