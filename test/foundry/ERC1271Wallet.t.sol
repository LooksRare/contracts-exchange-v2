// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Libraries and interfaces
import {IReentrancyGuard} from "@looksrare/contracts-libs/contracts/interfaces/IReentrancyGuard.sol";
import {ITransferSelectorNFT} from "../../contracts/interfaces/ITransferSelectorNFT.sol";
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";

// Base test
import {ProtocolBase} from "./ProtocolBase.t.sol";

// Mocks and other utils
import {MaliciousERC1271Wallet} from "./utils/MaliciousERC1271Wallet.sol";
import {ERC1271WalletMock} from "openzeppelin-contracts/contracts/mocks/ERC1271WalletMock.sol";

contract ERC1271WalletTest is ProtocolBase {
    uint256 private constant price = 1 ether; // Fixed price of sale
    uint256 private constant itemId = 0;
    bytes private constant _EMPTY_SIGNATURE = new bytes(0);

    MaliciousERC1271Wallet private maliciousERC1271Wallet;

    function setUp() public override {
        super.setUp();
        _setUpUser(takerUser);
        _setupRegistryRoyalties(address(mockERC721), _standardRoyaltyFee);

        maliciousERC1271Wallet = new MaliciousERC1271Wallet(address(looksRareProtocol));
        _setUpUser(address(maliciousERC1271Wallet));
    }

    /**
     * One ERC721 (where royalties come from the registry) is sold through a taker bid
     */
    function testTakerBidReentrancy() public {
        maliciousERC1271Wallet.setFunctionToReenter(MaliciousERC1271Wallet.FunctionToReenter.ExecuteTakerBid);

        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _takerBidSetup(
            address(maliciousERC1271Wallet)
        );

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
        ERC1271WalletMock wallet = new ERC1271WalletMock(address(makerUser));
        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _takerBidSetup(
            address(wallet)
        );

        bytes memory signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.startPrank(address(wallet));
        mockERC721.setApprovalForAll(address(transferManager), true);
        transferManager.grantApprovals(operators);
        vm.stopPrank();

        vm.prank(takerUser);
        looksRareProtocol.executeTakerBid{value: price}(
            takerBid,
            makerAsk,
            signature,
            _EMPTY_MERKLE_TREE,
            _EMPTY_AFFILIATE
        );

        assertEq(mockERC721.ownerOf(itemId), takerUser);
    }

    function testTakerAskReentrancy() public {
        maliciousERC1271Wallet.setFunctionToReenter(MaliciousERC1271Wallet.FunctionToReenter.ExecuteTakerAsk);

        (OrderStructs.TakerAsk memory takerAsk, OrderStructs.MakerBid memory makerBid) = _takerAskSetup(
            address(maliciousERC1271Wallet)
        );

        vm.expectRevert(IReentrancyGuard.ReentrancyFail.selector);
        vm.prank(takerUser);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, _EMPTY_SIGNATURE, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function testTakerAskNoReentrancy() public {
        ERC1271WalletMock wallet = new ERC1271WalletMock(address(makerUser));
        (OrderStructs.TakerAsk memory takerAsk, OrderStructs.MakerBid memory makerBid) = _takerAskSetup(
            address(wallet)
        );

        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        // Wallet needs to hold WETH and have given WETH approval
        deal(address(weth), address(wallet), price);
        vm.prank(address(wallet));
        weth.approve(address(looksRareProtocol), price);

        vm.prank(takerUser);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);

        assertEq(mockERC721.ownerOf(itemId), address(wallet));
    }

    uint256 private constant numberPurchases = 3;

    function testExecuteMultipleTakerBidsReentrancy() public {
        maliciousERC1271Wallet.setFunctionToReenter(MaliciousERC1271Wallet.FunctionToReenter.ExecuteMultipleTakerBids);

        (
            OrderStructs.MakerAsk[] memory makerAsks,
            OrderStructs.TakerBid[] memory takerBids,
            OrderStructs.MerkleTree[] memory merkleTrees,
            bytes[] memory signatures
        ) = _multipleTakerBidsSetup(address(maliciousERC1271Wallet));

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
        ERC1271WalletMock wallet = new ERC1271WalletMock(address(makerUser));

        (
            OrderStructs.MakerAsk[] memory makerAsks,
            OrderStructs.TakerBid[] memory takerBids,
            OrderStructs.MerkleTree[] memory merkleTrees,
            bytes[] memory signatures
        ) = _multipleTakerBidsSetup(address(wallet));

        vm.startPrank(address(wallet));
        mockERC721.setApprovalForAll(address(transferManager), true);
        transferManager.grantApprovals(operators);
        vm.stopPrank();

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

    function _takerBidSetup(
        address signer
    ) private returns (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) {
        // Mint asset
        mockERC721.mint(signer, itemId);

        // Prepare the order hash
        makerAsk = _createSingleItemMakerAskOrder({
            askNonce: 0,
            subsetNonce: 0,
            strategyId: 0, // Standard sale for fixed price
            assetType: 0, // ERC721
            orderNonce: 0,
            collection: address(mockERC721),
            currency: address(0), // ETH
            signer: signer,
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

    function _takerAskSetup(
        address signer
    ) private returns (OrderStructs.TakerAsk memory takerAsk, OrderStructs.MakerBid memory makerBid) {
        // Prepare the order hash
        makerBid = _createSingleItemMakerBidOrder({
            bidNonce: 0,
            subsetNonce: 0,
            strategyId: 0, // Standard sale for fixed price
            assetType: 0, // ERC721
            orderNonce: 0,
            collection: address(mockERC721),
            currency: address(weth),
            signer: signer,
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

    function _multipleTakerBidsSetup(
        address signer
    )
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
            mockERC721.mint(signer, i);

            // Prepare the order hash
            makerAsks[i] = _createSingleItemMakerAskOrder({
                askNonce: 0,
                subsetNonce: 0,
                strategyId: 0, // Standard sale for fixed price
                assetType: 0, // ERC721
                orderNonce: i,
                collection: address(mockERC721),
                currency: address(0), // ETH
                signer: signer,
                minPrice: price,
                itemId: i // 0, 1, etc.
            });

            signatures[i] = _signMakerAsk(makerAsks[i], makerUserPK);

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
