// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// LooksRare unopinionated libraries
import {IERC721} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC721.sol";

// Libraries
import {OrderStructs} from "../../../../contracts/libraries/OrderStructs.sol";

// Errors and constants
import {FunctionSelectorInvalid, OrderInvalid} from "../../../../contracts/errors/SharedErrors.sol";
import {ItemIdFlagged, ItemTransferredTooRecently, LastTransferTimeInvalid, MessageIdInvalid, SignatureTimestampExpired} from "../../../../contracts/errors/ReservoirErrors.sol";
import {MAKER_ORDER_PERMANENTLY_INVALID_NON_STANDARD_SALE} from "../../../../contracts/constants/ValidationCodeConstants.sol";
import {ONE_HUNDRED_PERCENT_IN_BP, ASSET_TYPE_ERC721} from "../../../../contracts/constants/NumericConstants.sol";

// Strategies
import {StrategyReservoirCollectionOffer} from "../../../../contracts/executionStrategies/Reservoir/StrategyReservoirCollectionOffer.sol";

// Base test
import {ProtocolBase} from "../../ProtocolBase.t.sol";

contract CollectionOffersWithReservoirTest is ProtocolBase {
    StrategyReservoirCollectionOffer public strategyReservoirCollectionOffer;
    bytes4 public selector = strategyReservoirCollectionOffer.executeCollectionStrategyWithTakerAsk.selector;

    uint256 public SIGNATURE_VALIDITY_PERIOD;
    // Test parameters
    uint256 private constant price = 1 ether; // Fixed price of sale

    function testNewStrategies() public {
        _setUp();
        _setUpNewStrategies();

        (
            bool strategyIsActive,
            uint16 strategyStandardProtocolFee,
            uint16 strategyMinTotalFee,
            uint16 strategyMaxProtocolFee,
            bytes4 strategySelector,
            bool strategyIsMakerBid,
            address strategyImplementation
        ) = looksRareProtocol.strategyInfo(1);

        assertTrue(strategyIsActive);
        assertEq(strategyStandardProtocolFee, _standardProtocolFeeBp);
        assertEq(strategyMinTotalFee, _minTotalFeeBp);
        assertEq(strategyMaxProtocolFee, _maxProtocolFeeBp);
        assertEq(strategySelector, selector);
        assertTrue(strategyIsMakerBid);
        assertEq(strategyImplementation, address(strategyReservoirCollectionOffer));
    }

    function testTakerAskReservoirCollectionOrderERC721RevertsIfItemIsFlagged() public {
        (
            uint256 forkedBlockNumber,
            ,
            address collection,
            uint256 flaggedItemId,
            address itemOwner,
            bytes memory takerAdditionalParameters
        ) = _returnFlaggedItemDataFromReservoir();

        _setUpForkAtBlockNumber(forkedBlockNumber);
        _setUpUser(makerUser);
        _setUpTakerUserAndGrantApprovals(itemOwner, collection);

        // Prepare the order hash
        OrderStructs.MakerBid memory makerBid = _createSingleItemMakerBidOrder({
            bidNonce: 0,
            subsetNonce: 0,
            strategyId: 1,
            assetType: ASSET_TYPE_ERC721,
            orderNonce: 0,
            collection: collection,
            currency: address(weth),
            signer: makerUser,
            maxPrice: price,
            itemId: 0 // Not used
        });

        // Maker user specifies the cooldown period for transfer
        uint256 transferCooldownPeriod = 1 hours;
        makerBid.additionalParameters = abi.encode(transferCooldownPeriod);

        // Sign order
        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        // Prepare taker ask
        OrderStructs.Taker memory takerAsk = OrderStructs.Taker(itemOwner, takerAdditionalParameters);

        _assertOrderIsValid(makerBid);
        _assertValidMakerBidOrder(makerBid, signature);

        // Execute taker ask transaction
        vm.prank(itemOwner);
        vm.expectRevert(abi.encodeWithSelector(ItemIdFlagged.selector, collection, flaggedItemId));
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function testTakerAskReservoirCollectionOrderERC721WorksIfItemIsNotFlagged() public {
        (
            uint256 forkedBlockNumber,
            ,
            address collection,
            uint256 itemId,
            address itemOwner,
            ,
            bytes memory takerAdditionalParameters
        ) = _returnValidNonFlaggedItemDataFromReservoir();

        _setUpForkAtBlockNumber(forkedBlockNumber);
        _setUpUser(makerUser);
        _setUpTakerUserAndGrantApprovals(itemOwner, collection);

        // Prepare the order hash
        OrderStructs.MakerBid memory makerBid = _createSingleItemMakerBidOrder({
            bidNonce: 0,
            subsetNonce: 0,
            strategyId: 1,
            assetType: ASSET_TYPE_ERC721,
            orderNonce: 0,
            collection: collection,
            currency: address(weth),
            signer: makerUser,
            maxPrice: price,
            itemId: 0 // Not used
        });

        // Maker user specifies the cooldown period for transfer
        uint256 transferCooldownPeriod = 1 hours;
        makerBid.additionalParameters = abi.encode(transferCooldownPeriod);

        // Sign order
        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        // Prepare taker ask
        OrderStructs.Taker memory takerAsk = OrderStructs.Taker(itemOwner, takerAdditionalParameters);

        _assertOrderIsValid(makerBid);
        _assertValidMakerBidOrder(makerBid, signature);

        // Execute taker ask transaction
        vm.prank(itemOwner);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);

        // Maker user has received the asset
        assertEq(IERC721(collection).ownerOf(itemId), makerUser);
    }

    function testTakerAskReservoirCollectionOrderERC721RevertsIfLastTransferTimeIs0() public {
        (
            uint256 forkedBlockNumber,
            ,
            address collection,
            ,
            address itemOwner,
            bytes memory takerAdditionalParameters
        ) = _returnInvalidNonFlaggedItemDataFromReservoir();

        _setUpForkAtBlockNumber(forkedBlockNumber);
        _setUpUser(makerUser);
        _setUpTakerUserAndGrantApprovals(itemOwner, collection);

        // Prepare the order hash
        OrderStructs.MakerBid memory makerBid = _createSingleItemMakerBidOrder({
            bidNonce: 0,
            subsetNonce: 0,
            strategyId: 1,
            assetType: ASSET_TYPE_ERC721,
            orderNonce: 0,
            collection: collection,
            currency: address(weth),
            signer: makerUser,
            maxPrice: price,
            itemId: 0 // Not used
        });

        // Maker user specifies the cooldown period for transfer
        uint256 transferCooldownPeriod = 1 hours;
        makerBid.additionalParameters = abi.encode(transferCooldownPeriod);

        // Sign order
        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        // Prepare taker ask
        OrderStructs.Taker memory takerAsk = OrderStructs.Taker(itemOwner, takerAdditionalParameters);

        _assertOrderIsValid(makerBid);
        _assertValidMakerBidOrder(makerBid, signature);

        // Execute taker ask transaction
        vm.prank(itemOwner);
        vm.expectRevert(LastTransferTimeInvalid.selector);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function testTakerAskReservoirCollectionOrderERC721RevertsIfSignatureTimestampExpires() public {
        (
            uint256 forkedBlockNumber,
            uint256 timestamp,
            address collection,
            ,
            address itemOwner,
            ,
            bytes memory takerAdditionalParameters
        ) = _returnValidNonFlaggedItemDataFromReservoir();

        _setUpForkAtBlockNumber(forkedBlockNumber);
        _setUpUser(makerUser);
        _setUpTakerUserAndGrantApprovals(itemOwner, collection);

        // Prepare the order hash
        OrderStructs.MakerBid memory makerBid = _createSingleItemMakerBidOrder({
            bidNonce: 0,
            subsetNonce: 0,
            strategyId: 1,
            assetType: ASSET_TYPE_ERC721,
            orderNonce: 0,
            collection: collection,
            currency: address(weth),
            signer: makerUser,
            maxPrice: price,
            itemId: 0 // Not used
        });

        // End time is increased to prevent OutsideOfTimeRange() after vm.warp
        makerBid.endTime = timestamp + SIGNATURE_VALIDITY_PERIOD + 1;

        // Maker user specifies the cooldown period for transfer
        uint256 transferCooldownPeriod = 1 hours;
        makerBid.additionalParameters = abi.encode(transferCooldownPeriod);

        // Sign order
        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        // Prepare taker ask
        OrderStructs.Taker memory takerAsk = OrderStructs.Taker(itemOwner, takerAdditionalParameters);

        _assertOrderIsValid(makerBid);
        _assertValidMakerBidOrder(makerBid, signature);

        // Time travel
        vm.warp(timestamp + SIGNATURE_VALIDITY_PERIOD + 1);

        vm.expectRevert(SignatureTimestampExpired.selector);
        vm.prank(itemOwner);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function testTakerAskReservoirCollectionOrderERC721RevertsIfTransferWithinCooldownPeriod() public {
        (
            uint256 forkedBlockNumber,
            ,
            address collection,
            uint256 itemId,
            address itemOwner,
            uint256 lastTransferTime,
            bytes memory takerAdditionalParameters
        ) = _returnValidNonFlaggedItemDataFromReservoir();

        _setUpForkAtBlockNumber(forkedBlockNumber);
        _setUpUser(makerUser);
        _setUpTakerUserAndGrantApprovals(itemOwner, collection);

        // Prepare the order hash
        OrderStructs.MakerBid memory makerBid = _createSingleItemMakerBidOrder({
            bidNonce: 0,
            subsetNonce: 0,
            strategyId: 1,
            assetType: ASSET_TYPE_ERC721,
            orderNonce: 0,
            collection: collection,
            currency: address(weth),
            signer: makerUser,
            maxPrice: price,
            itemId: 0 // Not used
        });

        // Maker user specifies the cooldown period for transfer
        uint256 transferCooldownPeriod = block.timestamp - lastTransferTime + 1;
        makerBid.additionalParameters = abi.encode(transferCooldownPeriod);

        // Sign order
        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        // Prepare taker ask
        OrderStructs.Taker memory takerAsk = OrderStructs.Taker(itemOwner, takerAdditionalParameters);

        _assertOrderIsValid(makerBid);
        _assertValidMakerBidOrder(makerBid, signature);

        vm.expectRevert(abi.encodeWithSelector(ItemTransferredTooRecently.selector, collection, itemId));
        vm.prank(itemOwner);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function testTakerAskReservoirCollectionOrderERC721RevertsIfItemIdDiffers(uint256 itemId) public {
        // 420 is the itemId that is from the Reservoir's data
        vm.assume(itemId != 420);
        // @dev Trying to sell an itemId that is not the one in the Reservoir's data
        //      will generate an invalid message id.
        (
            uint256 forkedBlockNumber,
            ,
            address collection,
            ,
            address itemOwner,
            ,
            bytes memory takerAdditionalParameters
        ) = _returnValidNonFlaggedItemDataFromReservoir();

        takerAdditionalParameters = _corruptTakerAdditionalParametersByChangingItemId(
            takerAdditionalParameters,
            itemId
        );

        _setUpForkAtBlockNumber(forkedBlockNumber);
        _setUpUser(makerUser);
        _setUpTakerUserAndGrantApprovals(itemOwner, collection);

        // Prepare the order hash
        OrderStructs.MakerBid memory makerBid = _createSingleItemMakerBidOrder({
            bidNonce: 0,
            subsetNonce: 0,
            strategyId: 1,
            assetType: ASSET_TYPE_ERC721,
            orderNonce: 0,
            collection: collection,
            currency: address(weth),
            signer: makerUser,
            maxPrice: price,
            itemId: 0 // Not used
        });

        // Maker user specifies the cooldown period for transfer
        uint256 transferCooldownPeriod = 1 hours;
        makerBid.additionalParameters = abi.encode(transferCooldownPeriod);

        // Sign order
        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        // Prepare taker ask
        OrderStructs.Taker memory takerAsk = OrderStructs.Taker(itemOwner, takerAdditionalParameters);

        _assertOrderIsValid(makerBid);
        _assertValidMakerBidOrder(makerBid, signature);

        vm.expectRevert(MessageIdInvalid.selector);
        vm.prank(itemOwner);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function _setUpForkAtBlockNumber(uint256 blockNumber) internal {
        vm.createSelectFork(vm.rpcUrl("mainnet"), blockNumber);
        _setUp();
        _setUpNewStrategies();

        SIGNATURE_VALIDITY_PERIOD = strategyReservoirCollectionOffer.SIGNATURE_VALIDITY_PERIOD();
    }

    function _setUpTakerUserAndGrantApprovals(address user, address collection) internal {
        _setUpUser(user);
        vm.prank(user);
        IERC721(collection).setApprovalForAll(address(transferManager), true);
    }

    function _returnFlaggedItemDataFromReservoir()
        private
        pure
        returns (
            uint256 forkedBlockNumber,
            uint256 timestamp,
            address collection,
            uint256 itemId,
            address itemOwner,
            bytes memory takerAdditionalParameters
        )
    {
        /**
         * @dev The below is the response from Reservoir's API
         *   {
         *       "token": "0x60e4d786628fea6478f785a6d7e704777c86a7c6:14412",
         *       "isFlagged": true,
         *       "lastTransferTime": 1675157279,
         *       "message":
         *              {
         *                "id": "0xf028a527cd00aeef0191c213ca8f6f1a5649efb6b83db3e8451fda701933e70e",
         *                "payload": "0x00000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000063d8df1f",
         *                "timestamp": 1675226327,
         *                "signature": "0xb2f5a86289bab990d1b7bed6bc8b373e0a01bff11cbcc4f1d3d9e697fae98768226969527ab7efa61631b86bd441e40a3a89a3c2bbbda271d607bd8cfe3335211c"
         *              }
         *   }
         */

        // @dev The signature timestamp was exactly the same as the one from block 16_531_634
        forkedBlockNumber = 16_531_634;
        timestamp = 1_675_226_327;
        itemId = 14_412;
        collection = 0x60E4d786628Fea6478F785A6d7e704777c86a7c6;
        itemOwner = 0xF5b9d00f6184954D6e725215D9Cab5F5698e8Bb3; // This address owns the flagged itemId

        takerAdditionalParameters = abi.encode(
            bytes32(0xf028a527cd00aeef0191c213ca8f6f1a5649efb6b83db3e8451fda701933e70e),
            hex"00000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000063d8df1f",
            uint256(timestamp),
            hex"b2f5a86289bab990d1b7bed6bc8b373e0a01bff11cbcc4f1d3d9e697fae98768226969527ab7efa61631b86bd441e40a3a89a3c2bbbda271d607bd8cfe3335211c",
            uint256(itemId)
        );
    }

    function _returnInvalidNonFlaggedItemDataFromReservoir()
        private
        pure
        returns (
            uint256 forkedBlockNumber,
            uint256 timestamp,
            address collection,
            uint256 itemId,
            address itemOwner,
            bytes memory takerAdditionalParameters
        )
    {
        /**
         * @dev The below is the invalid response from Reservoir's API that is still properly signed.
         *   {
         *       "token": "0x60e4d786628fea6478f785a6d7e704777c86a7c6:420",
         *       "isFlagged": false,
         *       "lastTransferTime": 0,
         *       "message":
         *              {
         *                "id": "0xdfe46268693892a9f04f448e598fdf46e54128885f9f152fabb92b3a1628623e",
         *                "payload": "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
         *                "timestamp": 1675386659,
         *                "signature": "0x03e0d8c2e100b8717deb7c9cefbabbac84d78908dc79f352de9fc328bb7ffa0c325037a7fa638d344c02dc077cd8f798dcc666765c2eaeccfb4fbde71c36325f1b"
         *              }
         *   }
         */

        forkedBlockNumber = 16_544_902;
        timestamp = 1_675_386_659;
        itemId = 420;
        collection = 0x60E4d786628Fea6478F785A6d7e704777c86a7c6;
        itemOwner = 0xE052113bd7D7700d623414a0a4585BCaE754E9d5; // This address owns the itemId

        takerAdditionalParameters = abi.encode(
            bytes32(0xdfe46268693892a9f04f448e598fdf46e54128885f9f152fabb92b3a1628623e),
            hex"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
            uint256(timestamp),
            hex"03e0d8c2e100b8717deb7c9cefbabbac84d78908dc79f352de9fc328bb7ffa0c325037a7fa638d344c02dc077cd8f798dcc666765c2eaeccfb4fbde71c36325f1b",
            uint256(itemId)
        );
    }

    function _returnValidNonFlaggedItemDataFromReservoir()
        private
        pure
        returns (
            uint256 forkedBlockNumber,
            uint256 timestamp,
            address collection,
            uint256 itemId,
            address itemOwner,
            uint256 lastTransferTime,
            bytes memory takerAdditionalParameters
        )
    {
        /**
         * @dev The below is the response from Reservoir's API
         *   {
         *       "token": "0x60e4d786628fea6478f785a6d7e704777c86a7c6:420",
         *       "isFlagged": false,
         *       "lastTransferTime": 1652309738,
         *       "message":
         *              {
         *                "id": "0xdfe46268693892a9f04f448e598fdf46e54128885f9f152fabb92b3a1628623e",
         *                "payload": "0x000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000627c3eea",
         *                "timestamp": 1675386659,
         *                "signature": "0xf3eeeef0bc09cc510fb8edde0196fa4208e868232649a4d0fd565f00aed176a608899f2609aaada31457388ced8c16c84f52a9d132d817bb3db7d61ab96d8eb61b"
         *              }
         *   }
         */

        forkedBlockNumber = 16_544_902;
        timestamp = 1_675_386_659;
        itemId = 420;
        collection = 0x60E4d786628Fea6478F785A6d7e704777c86a7c6;
        itemOwner = 0xE052113bd7D7700d623414a0a4585BCaE754E9d5; // This address owns the itemId
        lastTransferTime = 1_652_309_738;

        takerAdditionalParameters = abi.encode(
            bytes32(0xdfe46268693892a9f04f448e598fdf46e54128885f9f152fabb92b3a1628623e),
            hex"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000627c3eea",
            uint256(timestamp),
            hex"f3eeeef0bc09cc510fb8edde0196fa4208e868232649a4d0fd565f00aed176a608899f2609aaada31457388ced8c16c84f52a9d132d817bb3db7d61ab96d8eb61b",
            uint256(itemId)
        );
    }

    function _setUpNewStrategies() private asPrankedUser(_owner) {
        strategyReservoirCollectionOffer = new StrategyReservoirCollectionOffer();

        looksRareProtocol.addStrategy(
            _standardProtocolFeeBp,
            _minTotalFeeBp,
            _maxProtocolFeeBp,
            selector,
            true,
            address(strategyReservoirCollectionOffer)
        );
    }

    function _assertOrderIsValid(OrderStructs.MakerBid memory makerBid) private {
        (bool orderIsValid, bytes4 errorSelector) = strategyReservoirCollectionOffer.isMakerBidValid(
            makerBid,
            selector
        );
        assertTrue(orderIsValid);
        assertEq(errorSelector, _EMPTY_BYTES4);
    }

    function _assertOrderIsInvalid(OrderStructs.MakerBid memory makerBid) private {
        (bool orderIsValid, bytes4 errorSelector) = strategyReservoirCollectionOffer.isMakerBidValid(
            makerBid,
            selector
        );

        assertFalse(orderIsValid);
        assertEq(errorSelector, OrderInvalid.selector);
    }

    function _corruptTakerAdditionalParametersByChangingItemId(
        bytes memory takerAdditionalParameters,
        uint256 newItemId
    ) private pure returns (bytes memory corruptedTakerAdditionalParameters) {
        (bytes32 messageId, bytes memory payload, uint256 timestamp, bytes memory signature, ) = abi.decode(
            takerAdditionalParameters,
            (bytes32, bytes, uint256, bytes, uint256)
        );

        corruptedTakerAdditionalParameters = abi.encode(messageId, payload, timestamp, signature, newItemId);
    }
}
