// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {OrderStructs} from "../../../contracts/libraries/OrderStructs.sol";
import {TestHelpers} from "./TestHelpers.sol";
import {TestParameters} from "./TestParameters.sol";

contract ProtocolHelpers is TestHelpers, TestParameters {
    using OrderStructs for OrderStructs.MakerAsk;
    using OrderStructs for OrderStructs.MakerBid;
    using OrderStructs for OrderStructs.MerkleRoot;

    receive() external payable {}

    bytes32 internal _domainSeparator;

    function _createSingleItemMakerAskOrder(
        uint112 askNonce,
        uint112 subsetNonce,
        uint16 strategyId,
        uint8 assetType,
        uint112 orderNonce,
        address collection,
        address currency,
        address signer,
        uint256 minPrice,
        uint256 itemId
    ) internal view returns (OrderStructs.MakerAsk memory newMakerAsk) {
        uint256[] memory itemIds = new uint256[](1);
        itemIds[0] = itemId;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        return
            OrderStructs.MakerAsk({
                askNonce: askNonce,
                subsetNonce: subsetNonce,
                strategyId: strategyId,
                assetType: assetType,
                orderNonce: orderNonce,
                collection: collection,
                currency: currency,
                recipient: signer,
                signer: signer,
                startTime: block.timestamp,
                endTime: block.timestamp,
                minPrice: minPrice,
                itemIds: itemIds,
                amounts: amounts,
                additionalParameters: abi.encode()
            });
    }

    function _createMultiItemMakerAskOrder(
        uint112 askNonce,
        uint112 subsetNonce,
        uint16 strategyId,
        uint8 assetType,
        uint112 orderNonce,
        address collection,
        address currency,
        address signer,
        uint256 minPrice,
        uint256[] memory itemIds,
        uint256[] memory amounts
    ) internal view returns (OrderStructs.MakerAsk memory newMakerAsk) {
        return
            OrderStructs.MakerAsk({
                askNonce: askNonce,
                subsetNonce: subsetNonce,
                strategyId: strategyId,
                assetType: assetType,
                orderNonce: orderNonce,
                collection: collection,
                currency: currency,
                recipient: signer,
                signer: signer,
                startTime: block.timestamp,
                endTime: block.timestamp,
                minPrice: minPrice,
                itemIds: itemIds,
                amounts: amounts,
                additionalParameters: abi.encode()
            });
    }

    function _createSingleItemMakerBidOrder(
        uint112 bidNonce,
        uint112 subsetNonce,
        uint16 strategyId,
        uint8 assetType,
        uint112 orderNonce,
        address collection,
        address currency,
        address signer,
        uint256 maxPrice,
        uint256 itemId
    ) internal view returns (OrderStructs.MakerBid memory newMakerBid) {
        uint256[] memory itemIds = new uint256[](1);
        itemIds[0] = itemId;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;
        return
            OrderStructs.MakerBid({
                bidNonce: bidNonce,
                subsetNonce: subsetNonce,
                strategyId: strategyId,
                assetType: assetType,
                orderNonce: orderNonce,
                collection: collection,
                currency: currency,
                recipient: signer,
                signer: signer,
                startTime: block.timestamp,
                endTime: block.timestamp,
                maxPrice: maxPrice,
                itemIds: itemIds,
                amounts: amounts,
                additionalParameters: abi.encode()
            });
    }

    function _createMultiItemMakerBidOrder(
        uint112 bidNonce,
        uint112 subsetNonce,
        uint16 strategyId,
        uint8 assetType,
        uint112 orderNonce,
        address collection,
        address currency,
        address signer,
        uint256 maxPrice,
        uint256[] memory itemIds,
        uint256[] memory amounts
    ) internal view returns (OrderStructs.MakerBid memory newMakerBid) {
        return
            OrderStructs.MakerBid({
                bidNonce: bidNonce,
                subsetNonce: subsetNonce,
                strategyId: strategyId,
                assetType: assetType,
                orderNonce: orderNonce,
                collection: collection,
                currency: currency,
                recipient: signer,
                signer: signer,
                startTime: block.timestamp,
                endTime: block.timestamp,
                maxPrice: maxPrice,
                itemIds: itemIds,
                amounts: amounts,
                additionalParameters: abi.encode()
            });
    }

    function _signMakerAsk(OrderStructs.MakerAsk memory _makerAsk, uint256 _signerKey) internal returns (bytes memory) {
        bytes32 orderHash = _makerAsk.hash();

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            _signerKey,
            keccak256(abi.encodePacked("\x19\x01", _domainSeparator, orderHash))
        );

        return abi.encodePacked(r, s, v);
    }

    function _signMakerBid(OrderStructs.MakerBid memory _makerBid, uint256 _signerKey) internal returns (bytes memory) {
        bytes32 orderHash = computeOrderHashMakerBid(_makerBid);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            _signerKey,
            keccak256(abi.encodePacked("\x19\x01", _domainSeparator, orderHash))
        );

        return abi.encodePacked(r, s, v);
    }

    function _signMerkleProof(
        OrderStructs.MerkleRoot memory _merkleRoot,
        uint256 _signerKey
    ) internal returns (bytes memory) {
        bytes32 merkleRootHash = _merkleRoot.hash();

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            _signerKey,
            keccak256(abi.encodePacked("\x19\x01", _domainSeparator, merkleRootHash))
        );

        return abi.encodePacked(r, s, v);
    }

    function computeOrderHashMakerBid(OrderStructs.MakerBid memory _makerBid) public pure returns (bytes32) {
        return _makerBid.hash();
    }

    function computeOrderHashMakerAsk(OrderStructs.MakerAsk memory _makerAsk) public pure returns (bytes32) {
        return _makerAsk.hash();
    }
}
