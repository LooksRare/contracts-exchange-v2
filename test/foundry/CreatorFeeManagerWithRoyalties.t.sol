// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Libraries and interfaces
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";
import {ICreatorFeeManager} from "../../contracts/interfaces/ICreatorFeeManager.sol";
import {IExecutionManager} from "../../contracts/interfaces/IExecutionManager.sol";

// Core contract
import {CreatorFeeManagerWithRoyalties} from "../../contracts/CreatorFeeManagerWithRoyalties.sol";

// Base test
import {ProtocolBase} from "./ProtocolBase.t.sol";

contract CreatorFeeManagerWithRoyaltiesTest is ProtocolBase {
    CreatorFeeManagerWithRoyalties public creatorFeeManagerWithRoyalties;

    // New protocol fee
    uint16 internal _newProtocolFee = 200;

    // New creator royalty fee
    uint256 internal _newCreatorRoyaltyFee = 300;

    function _setUpRoyaltiesRegistry(uint256 fee) internal {
        vm.prank(_owner);
        royaltyFeeRegistry.updateRoyaltyInfoForCollection(
            address(mockERC721),
            _royaltyRecipient,
            _royaltyRecipient,
            fee
        );
    }

    function setUp() public virtual override {
        super.setUp();
        creatorFeeManagerWithRoyalties = new CreatorFeeManagerWithRoyalties(address(royaltyFeeRegistry));
        vm.startPrank(_owner);
        looksRareProtocol.setCreatorFeeManager(address(creatorFeeManagerWithRoyalties));
        // Set up 2% as protocol fee, which is now equal to minimum fee
        looksRareProtocol.updateStrategy(0, _newProtocolFee, _newProtocolFee, true);
        vm.stopPrank();
    }

    function testCreatorRoyaltiesGetPaidForRoyaltyFeeManager() public {
        _setUpUsers();

        // Adjust royalties
        _setUpRoyaltiesRegistry(_newCreatorRoyaltyFee);

        uint256 price = 1 ether; // Fixed price of sale
        uint256 itemId = 0; // TokenId

        // Prepare the order hash
        OrderStructs.MakerBid memory makerBid = _createSingleItemMakerBidOrder({
            bidNonce: 0,
            subsetNonce: 0,
            strategyId: 0,
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

        // Execute taker ask transaction
        vm.prank(takerUser);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _emptyMerkleTree, _emptyAffiliate);

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(itemId), makerUser);
        // Maker bid user pays the whole price
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser - price);
        // Owner receives 2% of the whole price
        assertEq(weth.balanceOf(_owner), _initialWETHBalanceOwner + (price * _newProtocolFee) / 10_000);
        // Taker ask user receives 95% of the whole price
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser + (price * 9_500) / 10_000);
        // Royalty recipient receives 3% of the whole price
        assertEq(
            weth.balanceOf(_royaltyRecipient),
            _initialWETHBalanceRoyaltyRecipient + (price * _newCreatorRoyaltyFee) / 10_000
        );
        // Verify the nonce is marked as executed
        assertEq(looksRareProtocol.userOrderNonce(makerUser, makerBid.orderNonce), MAGIC_VALUE_NONCE_EXECUTED);
    }

    function testCreatorRoyaltiesGetPaidForERC2981() public {
        uint256 itemId = 0; // TokenId
        uint256 price = 1 ether; // Fixed price of sale

        _setUpUsers();

        // Adjust ERC721 with royalties
        mockERC721WithRoyalties.addCustomRoyaltyInformationForTokenId(itemId, _royaltyRecipient, _newCreatorRoyaltyFee);

        // Prepare the order hash
        OrderStructs.MakerBid memory makerBid = _createSingleItemMakerBidOrder({
            bidNonce: 0,
            subsetNonce: 0,
            strategyId: 0,
            assetType: 0, // ERC721,
            orderNonce: 0,
            collection: address(mockERC721WithRoyalties),
            currency: address(weth),
            signer: makerUser,
            maxPrice: price,
            itemId: itemId
        });

        // Sign order
        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        // Mint asset
        mockERC721WithRoyalties.mint(takerUser, itemId);

        // Prepare the taker ask
        OrderStructs.TakerAsk memory takerAsk = OrderStructs.TakerAsk(
            takerUser,
            makerBid.maxPrice,
            makerBid.itemIds,
            makerBid.amounts,
            abi.encode()
        );

        // Execute taker ask transaction
        vm.prank(takerUser);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _emptyMerkleTree, _emptyAffiliate);

        // Taker user has received the asset
        assertEq(mockERC721WithRoyalties.ownerOf(itemId), makerUser);
        // Owner receives 2% of the whole price
        assertEq(weth.balanceOf(_owner), _initialWETHBalanceOwner + (price * _newProtocolFee) / 10_000);
        // Maker bid user pays the whole price
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser - price);
        // Taker ask user receives 95.5% of the whole price
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser + (price * 9_500) / 10_000);
        // Royalty recipient receives 3% of the whole price
        assertEq(
            weth.balanceOf(_royaltyRecipient),
            _initialWETHBalanceRoyaltyRecipient + (price * _newCreatorRoyaltyFee) / 10_000
        );
        // Verify the nonce is marked as executed
        assertEq(looksRareProtocol.userOrderNonce(makerUser, makerBid.orderNonce), MAGIC_VALUE_NONCE_EXECUTED);
    }

    function testCreatorRoyaltiesGetPaidForRoyaltyFeeManagerWithBundles() public {
        _setUpUsers();

        // Adjust royalties
        _setUpRoyaltiesRegistry(_newCreatorRoyaltyFee);

        uint256 numberItemsInBundle = 5;

        (
            OrderStructs.MakerBid memory makerBid,
            OrderStructs.TakerAsk memory takerAsk
        ) = _createMockMakerBidAndTakerAskWithBundle(address(mockERC721), address(weth), numberItemsInBundle);

        uint256 price = makerBid.maxPrice;

        // Sign the order
        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        // Mint the items
        mockERC721.batchMint(takerUser, makerBid.itemIds);

        // Taker user actions
        vm.prank(takerUser);

        // Execute taker ask transaction
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _emptyMerkleTree, _emptyAffiliate);

        for (uint256 i; i < makerBid.itemIds.length; i++) {
            // Maker user has received all the assets in the bundle
            assertEq(mockERC721.ownerOf(makerBid.itemIds[i]), makerUser);
        }

        // Maker bid user pays the whole price
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser - price);
        // Royalty recipient receives royalties
        assertEq(
            weth.balanceOf(_royaltyRecipient),
            _initialWETHBalanceRoyaltyRecipient + (price * _newCreatorRoyaltyFee) / 10_000
        );
        // Owner receives protocol fee
        assertEq(weth.balanceOf(_owner), _initialWETHBalanceOwner + (price * _newProtocolFee) / 10_000);
        // Taker ask user receives 95% of the whole price
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser + (price * 9_500) / 10_000);
        // Verify the nonce is marked as executed
        assertEq(looksRareProtocol.userOrderNonce(makerUser, makerBid.orderNonce), MAGIC_VALUE_NONCE_EXECUTED);
    }

    function testCreatorRoyaltiesGetPaidForERC2981WithBundles() public {
        _setUpUsers();

        uint256 numberItemsInBundle = 5;

        (
            OrderStructs.MakerBid memory makerBid,
            OrderStructs.TakerAsk memory takerAsk
        ) = _createMockMakerBidAndTakerAskWithBundle(
                address(mockERC721WithRoyalties),
                address(weth),
                numberItemsInBundle
            );

        uint256 price = makerBid.maxPrice;

        // Sign the order
        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        // Mint the items
        mockERC721WithRoyalties.batchMint(takerUser, makerBid.itemIds);

        // Adjust ERC721 with royalties
        for (uint256 i; i < makerBid.itemIds.length; i++) {
            mockERC721WithRoyalties.addCustomRoyaltyInformationForTokenId(
                makerBid.itemIds[i],
                _royaltyRecipient,
                _newCreatorRoyaltyFee
            );
        }

        // Taker user actions
        vm.prank(takerUser);

        // Execute taker ask transaction
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _emptyMerkleTree, _emptyAffiliate);

        // Maker bid user pays the whole price
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser - price);

        // Royalty recipient receives royalties
        assertEq(
            weth.balanceOf(_royaltyRecipient),
            _initialWETHBalanceRoyaltyRecipient + (price * _newCreatorRoyaltyFee) / 10_000
        );
        // Owner receives protocol fee
        assertEq(weth.balanceOf(_owner), _initialWETHBalanceOwner + (price * _newProtocolFee) / 10_000);
        // Taker ask user receives 95% of the whole price
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser + (price * 9_500) / 10_000);
        // Verify the nonce is marked as executed
        assertEq(looksRareProtocol.userOrderNonce(makerUser, makerBid.orderNonce), MAGIC_VALUE_NONCE_EXECUTED);
    }

    function testCreatorRoyaltiesRevertForEIP2981WithBundlesIfInfoDiffer() public {
        _setUpUsers();

        uint256 numberItemsInBundle = 5;

        (
            OrderStructs.MakerBid memory makerBid,
            OrderStructs.TakerAsk memory takerAsk
        ) = _createMockMakerBidAndTakerAskWithBundle(
                address(mockERC721WithRoyalties),
                address(weth),
                numberItemsInBundle
            );

        // Sign the order
        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        // Mint the items
        mockERC721WithRoyalties.batchMint(takerUser, makerBid.itemIds);

        /**
         * 1. Different fee structure but same recipient
         */

        // Adjust ERC721 with royalties
        for (uint256 i; i < makerBid.itemIds.length; i++) {
            mockERC721WithRoyalties.addCustomRoyaltyInformationForTokenId(
                makerBid.itemIds[i],
                _royaltyRecipient,
                _newCreatorRoyaltyFee - i // It is not equal
            );
        }

        // Taker user action should revert
        vm.prank(takerUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICreatorFeeManager.BundleEIP2981NotAllowed.selector,
                address(mockERC721WithRoyalties)
            )
        );

        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _emptyMerkleTree, _emptyAffiliate);

        /**
         * 2. Same fee structure but different recipient
         */

        // Adjust ERC721 with royalties
        for (uint256 i; i < makerBid.itemIds.length; i++) {
            mockERC721WithRoyalties.addCustomRoyaltyInformationForTokenId(
                makerBid.itemIds[i],
                i == 0 ? _royaltyRecipient : address(50),
                _newCreatorRoyaltyFee
            );
        }

        vm.prank(takerUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICreatorFeeManager.BundleEIP2981NotAllowed.selector,
                address(mockERC721WithRoyalties)
            )
        );

        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _emptyMerkleTree, _emptyAffiliate);
    }

    function testCreatorRoyaltiesRevertIfFeeHigherThanLimit() public {
        _setUpUsers();
        uint256 _creatorRoyaltyFeeTooHigh = looksRareProtocol.maximumCreatorFeeBp() + 1;

        // Adjust royalties
        _setUpRoyaltiesRegistry(_creatorRoyaltyFeeTooHigh);

        uint256 price = 1 ether; // Fixed price of sale
        uint256 itemId = 0; // TokenId

        // Prepare the order hash
        OrderStructs.MakerBid memory makerBid = _createSingleItemMakerBidOrder({
            bidNonce: 0,
            subsetNonce: 0,
            strategyId: 0,
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

        // Execute taker ask transaction
        vm.expectRevert(IExecutionManager.CreatorFeeBpTooHigh.selector);
        vm.prank(takerUser);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _emptyMerkleTree, _emptyAffiliate);

        // 2. Maker ask
        itemId = 1; // The itemId changes as it is already minted before

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
        signature = _signMakerAsk(makerAsk, makerUserPK);

        // Prepare the taker bid
        OrderStructs.TakerBid memory takerBid = OrderStructs.TakerBid(
            takerUser,
            makerAsk.minPrice,
            makerAsk.itemIds,
            makerAsk.amounts,
            abi.encode()
        );

        // Execute taker ask transaction
        vm.expectRevert(IExecutionManager.CreatorFeeBpTooHigh.selector);

        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerBid{value: price}(
            takerBid,
            makerAsk,
            signature,
            _emptyMerkleTree,
            _emptyAffiliate
        );
    }
}
