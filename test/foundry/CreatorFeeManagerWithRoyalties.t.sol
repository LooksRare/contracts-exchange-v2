// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Libraries and interfaces
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";
import {ICreatorFeeManager} from "../../contracts/interfaces/ICreatorFeeManager.sol";
import {IExecutionManager} from "../../contracts/interfaces/IExecutionManager.sol";

// Core contract
import {CreatorFeeManagerWithRoyalties} from "../../contracts/CreatorFeeManagerWithRoyalties.sol";

// Shared errors
import {BUNDLE_ERC2981_NOT_SUPPORTED, CREATOR_FEE_TOO_HIGH} from "../../contracts/constants/ValidationCodeConstants.sol";

// Base test
import {ProtocolBase} from "./ProtocolBase.t.sol";

// Constants
import {ONE_HUNDRED_PERCENT_IN_BP} from "../../contracts/constants/NumericConstants.sol";

// Enums
import {AssetType} from "../../contracts/enums/AssetType.sol";
import {QuoteType} from "../../contracts/enums/QuoteType.sol";

contract CreatorFeeManagerWithRoyaltiesTest is ProtocolBase {
    CreatorFeeManagerWithRoyalties public creatorFeeManagerWithRoyalties;

    // New protocol fee
    uint16 internal constant _newProtocolFee = 200;

    // New creator royalty fee
    uint256 internal constant _newCreatorRoyaltyFee = 300;

    function _setUpRoyaltiesRegistry(uint256 fee) internal {
        vm.prank(_owner);
        royaltyFeeRegistry.updateRoyaltyInfoForCollection(
            address(mockERC721),
            _royaltyRecipient,
            _royaltyRecipient,
            fee
        );
    }

    function setUp() public {
        _setUp();
        creatorFeeManagerWithRoyalties = new CreatorFeeManagerWithRoyalties(address(royaltyFeeRegistry));
        vm.startPrank(_owner);
        looksRareProtocol.updateCreatorFeeManager(address(creatorFeeManagerWithRoyalties));
        // Set up 2% as protocol fee, which is now equal to minimum fee
        looksRareProtocol.updateStrategy(0, true, _newProtocolFee, _newProtocolFee);
        vm.stopPrank();

        // Adjust for new creator fee manager
        orderValidator.deriveProtocolParameters();
    }

    function testCreatorRoyaltiesGetPaidForRoyaltyFeeManager() public {
        _setUpUsers();

        // Adjust royalties
        _setUpRoyaltiesRegistry(_newCreatorRoyaltyFee);

        uint256 price = 1 ether; // Fixed price of sale
        uint256 itemId = 0;

        // Prepare the order hash
        OrderStructs.Maker memory makerBid = _createSingleItemMakerOrder({
            quoteType: QuoteType.Bid,
            globalNonce: 0,
            subsetNonce: 0,
            strategyId: STANDARD_SALE_FOR_FIXED_PRICE_STRATEGY,
            assetType: AssetType.ERC721,
            orderNonce: 0,
            collection: address(mockERC721),
            currency: address(weth),
            signer: makerUser,
            price: price,
            itemId: itemId
        });

        // Sign order
        bytes memory signature = _signMakerOrder(makerBid, makerUserPK);

        // Mint asset
        mockERC721.mint(takerUser, itemId);

        _assertValidMakerOrder(makerBid, signature);

        // Execute taker ask transaction
        vm.prank(takerUser);
        looksRareProtocol.executeTakerAsk(
            _genericTakerOrder(),
            makerBid,
            signature,
            _EMPTY_MERKLE_TREE,
            _EMPTY_AFFILIATE
        );

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(itemId), makerUser);
        _assertSuccessfulTakerAsk(makerBid);
    }

    function testCreatorRoyaltiesGetPaidForERC2981() public {
        uint256 itemId = 0;
        uint256 price = 1 ether; // Fixed price of sale

        _setUpUsers();

        // Adjust ERC721 with royalties
        mockERC721WithRoyalties.addCustomRoyaltyInformationForTokenId(itemId, _royaltyRecipient, _newCreatorRoyaltyFee);

        // Prepare the order hash
        OrderStructs.Maker memory makerBid = _createSingleItemMakerOrder({
            quoteType: QuoteType.Bid,
            globalNonce: 0,
            subsetNonce: 0,
            strategyId: STANDARD_SALE_FOR_FIXED_PRICE_STRATEGY,
            assetType: AssetType.ERC721,
            orderNonce: 0,
            collection: address(mockERC721WithRoyalties),
            currency: address(weth),
            signer: makerUser,
            price: price,
            itemId: itemId
        });

        // Sign order
        bytes memory signature = _signMakerOrder(makerBid, makerUserPK);

        // Mint asset
        mockERC721WithRoyalties.mint(takerUser, itemId);

        _assertValidMakerOrder(makerBid, signature);

        // Execute taker ask transaction
        vm.prank(takerUser);
        looksRareProtocol.executeTakerAsk(
            _genericTakerOrder(),
            makerBid,
            signature,
            _EMPTY_MERKLE_TREE,
            _EMPTY_AFFILIATE
        );

        // Taker user has received the asset
        assertEq(mockERC721WithRoyalties.ownerOf(itemId), makerUser);
        _assertSuccessfulTakerAsk(makerBid);
    }

    function testCreatorRoyaltiesGetPaidForRoyaltyFeeManagerWithBundles() public {
        _setUpUsers();

        // Adjust royalties
        _setUpRoyaltiesRegistry(_newCreatorRoyaltyFee);

        uint256 numberItemsInBundle = 5;

        (
            OrderStructs.Maker memory makerBid,
            OrderStructs.Taker memory takerAsk
        ) = _createMockMakerBidAndTakerAskWithBundle(address(mockERC721), address(weth), numberItemsInBundle);

        // Sign the order
        bytes memory signature = _signMakerOrder(makerBid, makerUserPK);

        // Mint the items
        mockERC721.batchMint(takerUser, makerBid.itemIds);

        // Check order validity
        _assertValidMakerOrder(makerBid, signature);

        // Taker user actions
        vm.prank(takerUser);

        // Execute taker ask transaction
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);

        for (uint256 i; i < makerBid.itemIds.length; i++) {
            // Maker user has received all the assets in the bundle
            assertEq(mockERC721.ownerOf(makerBid.itemIds[i]), makerUser);
        }

        _assertSuccessfulTakerAskBundle(makerBid);
    }

    function testCreatorRoyaltiesGetPaidForERC2981WithBundles() public {
        _setUpUsers();

        uint256 numberItemsInBundle = 5;

        (
            OrderStructs.Maker memory makerBid,
            OrderStructs.Taker memory takerAsk
        ) = _createMockMakerBidAndTakerAskWithBundle(
                address(mockERC721WithRoyalties),
                address(weth),
                numberItemsInBundle
            );

        // Sign the order
        bytes memory signature = _signMakerOrder(makerBid, makerUserPK);

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

        _assertValidMakerOrder(makerBid, signature);

        // Taker user actions
        vm.prank(takerUser);

        // Execute taker ask transaction
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);

        _assertSuccessfulTakerAskBundle(makerBid);
    }

    function testCreatorRoyaltiesRevertForEIP2981WithBundlesIfInfoDiffer() public {
        _setUpUsers();

        uint256 numberItemsInBundle = 5;

        (
            OrderStructs.Maker memory makerBid,
            OrderStructs.Taker memory takerAsk
        ) = _createMockMakerBidAndTakerAskWithBundle(
                address(mockERC721WithRoyalties),
                address(weth),
                numberItemsInBundle
            );

        // Sign the order
        bytes memory signature = _signMakerOrder(makerBid, makerUserPK);

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

        _doesMakerOrderReturnValidationCode(makerBid, signature, BUNDLE_ERC2981_NOT_SUPPORTED);

        // Taker user action should revert
        vm.prank(takerUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICreatorFeeManager.BundleEIP2981NotAllowed.selector,
                address(mockERC721WithRoyalties)
            )
        );

        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);

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

        _doesMakerOrderReturnValidationCode(makerBid, signature, BUNDLE_ERC2981_NOT_SUPPORTED);

        vm.prank(takerUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICreatorFeeManager.BundleEIP2981NotAllowed.selector,
                address(mockERC721WithRoyalties)
            )
        );

        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function testCreatorRoyaltiesRevertForEIP2981WithBundlesIfAtLeastOneCallReverts(uint256 revertIndex) public {
        _setUpUsers();

        uint256 numberItemsInBundle = 5;
        vm.assume(revertIndex < numberItemsInBundle);

        (
            OrderStructs.Maker memory makerBid,
            OrderStructs.Taker memory takerAsk
        ) = _createMockMakerBidAndTakerAskWithBundle(
                address(mockERC721WithRoyalties),
                address(weth),
                numberItemsInBundle
            );

        // Sign the order
        bytes memory signature = _signMakerOrder(makerBid, makerUserPK);

        // Mint the items
        mockERC721WithRoyalties.batchMint(takerUser, makerBid.itemIds);

        // Adjust ERC721 with royalties
        for (uint256 i; i < makerBid.itemIds.length; i++) {
            mockERC721WithRoyalties.addCustomRoyaltyInformationForTokenId(
                makerBid.itemIds[i],
                _royaltyRecipient,
                // if greater than 10,000, will revert in royaltyInfo
                i == revertIndex ? 10_001 : _newCreatorRoyaltyFee
            );
        }

        _doesMakerOrderReturnValidationCode(makerBid, signature, BUNDLE_ERC2981_NOT_SUPPORTED);

        // Taker user action should revert
        vm.prank(takerUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICreatorFeeManager.BundleEIP2981NotAllowed.selector,
                address(mockERC721WithRoyalties)
            )
        );

        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function testCreatorRoyaltiesRevertIfFeeHigherThanLimit() public {
        _setUpUsers();
        uint256 _creatorRoyaltyFeeTooHigh = looksRareProtocol.maxCreatorFeeBp() + 1;

        // Adjust royalties
        _setUpRoyaltiesRegistry(_creatorRoyaltyFeeTooHigh);

        // Mint asset
        mockERC721.mint(takerUser, 0);

        (
            OrderStructs.Maker memory makerBid,
            OrderStructs.Taker memory takerAsk,
            bytes memory signature
        ) = _createSingleItemMakerAndTakerOrderAndSignature({
                quoteType: QuoteType.Bid,
                globalNonce: 0,
                subsetNonce: 0,
                strategyId: STANDARD_SALE_FOR_FIXED_PRICE_STRATEGY,
                assetType: AssetType.ERC721,
                orderNonce: 0,
                collection: address(mockERC721),
                currency: address(weth),
                signer: makerUser,
                price: 1 ether,
                itemId: 0
            });

        _doesMakerOrderReturnValidationCode(makerBid, signature, CREATOR_FEE_TOO_HIGH);

        vm.expectRevert(IExecutionManager.CreatorFeeBpTooHigh.selector);
        vm.prank(takerUser);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);

        // 2. Maker ask

        // Mint asset
        mockERC721.mint(makerUser, 1);

        // Prepare the orders and signature
        OrderStructs.Maker memory makerAsk;
        OrderStructs.Taker memory takerBid;

        (makerAsk, takerBid, signature) = _createSingleItemMakerAndTakerOrderAndSignature({
            quoteType: QuoteType.Ask,
            globalNonce: 0,
            subsetNonce: 0,
            strategyId: STANDARD_SALE_FOR_FIXED_PRICE_STRATEGY,
            assetType: AssetType.ERC721,
            orderNonce: 0,
            collection: address(mockERC721),
            currency: ETH,
            signer: makerUser,
            price: 1 ether,
            // The itemId changes as it is already minted before
            itemId: 1
        });

        _doesMakerOrderReturnValidationCode(makerAsk, signature, CREATOR_FEE_TOO_HIGH);

        vm.expectRevert(IExecutionManager.CreatorFeeBpTooHigh.selector);
        vm.prank(takerUser);

        looksRareProtocol.executeTakerBid{value: 1 ether}(
            takerBid,
            makerAsk,
            signature,
            _EMPTY_MERKLE_TREE,
            _EMPTY_AFFILIATE
        );
    }

    function _assertSuccessfulTakerAsk(OrderStructs.Maker memory makerBid) private {
        uint256 price = makerBid.price;

        // Maker bid user pays the whole price
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser - price);
        // Owner receives 2% of the whole price
        assertEq(
            weth.balanceOf(_owner),
            _initialWETHBalanceOwner + (price * _newProtocolFee) / ONE_HUNDRED_PERCENT_IN_BP
        );
        // Taker ask user receives 95% of the whole price
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser + (price * 9_500) / ONE_HUNDRED_PERCENT_IN_BP);
        // Royalty recipient receives 3% of the whole price
        assertEq(
            weth.balanceOf(_royaltyRecipient),
            _initialWETHBalanceRoyaltyRecipient + (price * _newCreatorRoyaltyFee) / ONE_HUNDRED_PERCENT_IN_BP
        );
        // Verify the nonce is marked as executed
        assertEq(looksRareProtocol.userOrderNonce(makerUser, makerBid.orderNonce), MAGIC_VALUE_ORDER_NONCE_EXECUTED);
    }

    function _assertSuccessfulTakerAskBundle(OrderStructs.Maker memory makerBid) private {
        uint256 price = makerBid.price;

        // Maker bid user pays the whole price
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser - price);
        // Royalty recipient receives royalties
        assertEq(
            weth.balanceOf(_royaltyRecipient),
            _initialWETHBalanceRoyaltyRecipient + (price * _newCreatorRoyaltyFee) / ONE_HUNDRED_PERCENT_IN_BP
        );
        // Owner receives protocol fee
        assertEq(
            weth.balanceOf(_owner),
            _initialWETHBalanceOwner + (price * _newProtocolFee) / ONE_HUNDRED_PERCENT_IN_BP
        );
        // Taker ask user receives 95% of the whole price
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser + (price * 9_500) / ONE_HUNDRED_PERCENT_IN_BP);
        // Verify the nonce is marked as executed
        assertEq(looksRareProtocol.userOrderNonce(makerUser, makerBid.orderNonce), MAGIC_VALUE_ORDER_NONCE_EXECUTED);
    }
}
