// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Libraries
import {OrderStructs} from "../../../contracts/libraries/OrderStructs.sol";

// Other tests
import {TestHelpers} from "./TestHelpers.sol";
import {TestParameters} from "./TestParameters.sol";

contract ProtocolHelpers is TestHelpers, TestParameters {
    using OrderStructs for OrderStructs.Maker;
    using OrderStructs for OrderStructs.MerkleTree;

    bytes32 internal _domainSeparator;

    receive() external payable {}

    function _createSingleItemMakerAskAndTakerBidOrderAndSignature(
        uint256 askNonce,
        uint256 subsetNonce,
        uint256 strategyId,
        uint256 assetType,
        uint256 orderNonce,
        address collection,
        address currency,
        address signer,
        uint256 minPrice,
        uint256 itemId
    )
        internal
        view
        returns (OrderStructs.Maker memory newMakerAsk, OrderStructs.Taker memory newTakerBid, bytes memory signature)
    {
        newMakerAsk = _createSingleItemMakerAskOrder(
            askNonce,
            subsetNonce,
            strategyId,
            assetType,
            orderNonce,
            collection,
            currency,
            signer,
            minPrice,
            itemId
        );

        signature = _signMakerOrder(newMakerAsk, makerUserPK);

        newTakerBid = OrderStructs.Taker(takerUser, abi.encode());
    }

    function _createSingleItemMakerAskOrder(
        uint256 askNonce,
        uint256 subsetNonce,
        uint256 strategyId,
        uint256 assetType,
        uint256 orderNonce,
        address collection,
        address currency,
        address signer,
        uint256 minPrice,
        uint256 itemId
    ) internal view returns (OrderStructs.Maker memory newMakerAsk) {
        uint256[] memory itemIds = new uint256[](1);
        itemIds[0] = itemId;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        newMakerAsk = OrderStructs.Maker({
            quoteType: OrderStructs.QuoteType.Ask,
            globalNonce: askNonce,
            orderNonce: orderNonce,
            subsetNonce: subsetNonce,
            strategyId: strategyId,
            assetType: assetType,
            collection: collection,
            currency: currency,
            signer: signer,
            startTime: block.timestamp,
            endTime: block.timestamp + 1,
            price: minPrice,
            itemIds: itemIds,
            amounts: amounts,
            additionalParameters: abi.encode()
        });
    }

    function _createMultiItemMakerAskOrder(
        uint256 askNonce,
        uint256 subsetNonce,
        uint256 strategyId,
        uint256 assetType,
        uint256 orderNonce,
        address collection,
        address currency,
        address signer,
        uint256 minPrice,
        uint256[] memory itemIds,
        uint256[] memory amounts
    ) internal view returns (OrderStructs.Maker memory newMakerAsk) {
        newMakerAsk = OrderStructs.Maker({
            quoteType: OrderStructs.QuoteType.Ask,
            globalNonce: askNonce,
            orderNonce: orderNonce,
            subsetNonce: subsetNonce,
            strategyId: strategyId,
            assetType: assetType,
            collection: collection,
            currency: currency,
            signer: signer,
            startTime: block.timestamp,
            endTime: block.timestamp + 1,
            price: minPrice,
            itemIds: itemIds,
            amounts: amounts,
            additionalParameters: abi.encode()
        });
    }

    function _createSingleItemMakerBidAndTakerAskOrderAndSignature(
        uint256 bidNonce,
        uint256 subsetNonce,
        uint256 strategyId,
        uint256 assetType,
        uint256 orderNonce,
        address collection,
        address currency,
        address signer,
        uint256 maxPrice,
        uint256 itemId
    )
        internal
        view
        returns (OrderStructs.Maker memory newMakerBid, OrderStructs.Taker memory newTakerAsk, bytes memory signature)
    {
        newMakerBid = _createSingleItemMakerBidOrder(
            bidNonce,
            subsetNonce,
            strategyId,
            assetType,
            orderNonce,
            collection,
            currency,
            signer,
            maxPrice,
            itemId
        );

        signature = _signMakerOrder(newMakerBid, makerUserPK);

        newTakerAsk = OrderStructs.Taker(takerUser, abi.encode());
    }

    function _createSingleItemMakerBidOrder(
        uint256 bidNonce,
        uint256 subsetNonce,
        uint256 strategyId,
        uint256 assetType,
        uint256 orderNonce,
        address collection,
        address currency,
        address signer,
        uint256 maxPrice,
        uint256 itemId
    ) internal view returns (OrderStructs.Maker memory newMakerBid) {
        uint256[] memory itemIds = new uint256[](1);
        itemIds[0] = itemId;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        newMakerBid = OrderStructs.Maker({
            quoteType: OrderStructs.QuoteType.Bid,
            globalNonce: bidNonce,
            subsetNonce: subsetNonce,
            orderNonce: orderNonce,
            strategyId: strategyId,
            assetType: assetType,
            collection: collection,
            currency: currency,
            signer: signer,
            startTime: block.timestamp,
            endTime: block.timestamp + 1,
            price: maxPrice,
            itemIds: itemIds,
            amounts: amounts,
            additionalParameters: abi.encode()
        });
    }

    function _createMultiItemMakerBidOrder(
        uint256 bidNonce,
        uint256 subsetNonce,
        uint256 strategyId,
        uint256 assetType,
        uint256 orderNonce,
        address collection,
        address currency,
        address signer,
        uint256 maxPrice,
        uint256[] memory itemIds,
        uint256[] memory amounts
    ) internal view returns (OrderStructs.Maker memory newMakerBid) {
        newMakerBid = OrderStructs.Maker({
            quoteType: OrderStructs.QuoteType.Bid,
            globalNonce: bidNonce,
            subsetNonce: subsetNonce,
            orderNonce: orderNonce,
            strategyId: strategyId,
            assetType: assetType,
            collection: collection,
            currency: currency,
            signer: signer,
            startTime: block.timestamp,
            endTime: block.timestamp + 1,
            price: maxPrice,
            itemIds: itemIds,
            amounts: amounts,
            additionalParameters: abi.encode()
        });
    }

    function _signMakerOrder(OrderStructs.Maker memory maker, uint256 signerKey) internal view returns (bytes memory) {
        bytes32 orderHash = _computeOrderHash(maker);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            signerKey,
            keccak256(abi.encodePacked("\x19\x01", _domainSeparator, orderHash))
        );

        return abi.encodePacked(r, s, v);
    }

    function _signMerkleProof(
        OrderStructs.MerkleTree memory merkleTree,
        uint256 signerKey
    ) internal view returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            signerKey,
            keccak256(abi.encodePacked("\x19\x01", _domainSeparator, merkleTree.hash()))
        );

        return abi.encodePacked(r, s, v);
    }

    function _computeOrderHash(OrderStructs.Maker memory maker) internal pure returns (bytes32) {
        return maker.hash();
    }
}
