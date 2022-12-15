// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Libraries
import {OrderStructs} from "../../../contracts/libraries/OrderStructs.sol";

// Other tests
import {TestHelpers} from "./TestHelpers.sol";
import {TestParameters} from "./TestParameters.sol";

contract ProtocolHelpers is TestHelpers, TestParameters {
    using OrderStructs for OrderStructs.MakerAsk;
    using OrderStructs for OrderStructs.MakerBid;
    using OrderStructs for OrderStructs.MerkleTree;

    receive() external payable {}

    bytes32 internal _domainSeparator;

    function _createSingleItemMakerAskOrder(
        uint128 askNonce,
        uint256 subsetNonce,
        uint256 strategyId,
        uint256 assetType,
        uint256 orderNonce,
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

        newMakerAsk = OrderStructs.MakerAsk({
            askNonce: askNonce,
            subsetNonce: subsetNonce,
            strategyId: strategyId,
            assetType: assetType,
            orderNonce: orderNonce,
            collection: collection,
            currency: currency,
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
        uint128 askNonce,
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
    ) internal view returns (OrderStructs.MakerAsk memory newMakerAsk) {
        newMakerAsk = OrderStructs.MakerAsk({
            askNonce: askNonce,
            subsetNonce: subsetNonce,
            strategyId: strategyId,
            assetType: assetType,
            orderNonce: orderNonce,
            collection: collection,
            currency: currency,
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
        uint128 bidNonce,
        uint256 subsetNonce,
        uint256 strategyId,
        uint256 assetType,
        uint256 orderNonce,
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
        newMakerBid = OrderStructs.MakerBid({
            bidNonce: bidNonce,
            subsetNonce: subsetNonce,
            strategyId: strategyId,
            assetType: assetType,
            orderNonce: orderNonce,
            collection: collection,
            currency: currency,
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
        uint128 bidNonce,
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
    ) internal view returns (OrderStructs.MakerBid memory newMakerBid) {
        newMakerBid = OrderStructs.MakerBid({
            bidNonce: bidNonce,
            subsetNonce: subsetNonce,
            strategyId: strategyId,
            assetType: assetType,
            orderNonce: orderNonce,
            collection: collection,
            currency: currency,
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
        OrderStructs.MerkleTree memory _merkleTree,
        uint256 _signerKey
    ) internal returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            _signerKey,
            keccak256(abi.encodePacked("\x19\x01", _domainSeparator, _merkleTree.hash()))
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
