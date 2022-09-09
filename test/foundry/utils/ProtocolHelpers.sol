// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {TestHelpers} from "./TestHelpers.sol";
import {OrderStructs} from "../../../contracts/libraries/OrderStructs.sol";

abstract contract TestParameters is TestHelpers {
    address internal _owner = address(42);
    address internal _royaltyRecipient = address(22);
    address internal _emptyReferrer = address(0);
    uint16 internal _standardProtocolFee = uint16(200);
    uint16 internal _standardRoyaltyFee = uint16(100);
    uint256 internal makerUserPK = 1;
    uint256 internal takerUserPK = 2;
    address internal makerUser = vm.addr(makerUserPK);
    address internal takerUser = vm.addr(takerUserPK);
    OrderStructs.MerkleRoot internal _emptyMerkleRoot = OrderStructs.MerkleRoot({root: bytes32(0)});
    bytes32[] internal _emptyMerkleProof = new bytes32[](0);

    // Initial balances
    uint256 internal _initialETHBalanceUser = 100 ether;
    uint256 internal _initialWETHBalanceUser = 10 ether;
    uint256 internal _initialETHBalanceRoyaltyRecipient = 10 ether;
    uint256 internal _initialWETHBalanceRoyaltyRecipient = 10 ether;
    uint256 internal _initialETHBalanceOwner = 50 ether;
    uint256 internal _initialWETHBalanceOwner = 15 ether;

    // Reused parameters
    OrderStructs.MakerAsk makerAsk;
    OrderStructs.MakerBid makerBid;
    OrderStructs.TakerBid takerBid;
    OrderStructs.TakerAsk takerAsk;
    bytes signature;
}

contract ProtocolHelpers is TestParameters {
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
        uint16 minNetRatio,
        address collection,
        address currency,
        address signer,
        uint256 minPrice,
        uint256 itemId
    ) internal view returns (OrderStructs.MakerAsk memory makerAsk) {
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
                minNetRatio: minNetRatio,
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
        uint16 minNetRatio,
        address collection,
        address currency,
        address signer,
        uint256 minPrice,
        uint256[] memory itemIds,
        uint256[] memory amounts
    ) internal view returns (OrderStructs.MakerAsk memory makerAsk) {
        return
            OrderStructs.MakerAsk({
                askNonce: askNonce,
                subsetNonce: subsetNonce,
                strategyId: strategyId,
                assetType: assetType,
                orderNonce: orderNonce,
                minNetRatio: minNetRatio,
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
        uint16 minNetRatio,
        address collection,
        address currency,
        address signer,
        uint256 maxPrice,
        uint256 itemId
    ) internal view returns (OrderStructs.MakerBid memory makerBid) {
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
                minNetRatio: minNetRatio,
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
        uint16 minNetRatio,
        address collection,
        address currency,
        address signer,
        uint256 maxPrice,
        uint256[] memory itemIds,
        uint256[] memory amounts
    ) internal view returns (OrderStructs.MakerBid memory makerBid) {
        return
            OrderStructs.MakerBid({
                bidNonce: bidNonce,
                subsetNonce: subsetNonce,
                strategyId: strategyId,
                assetType: assetType,
                orderNonce: orderNonce,
                minNetRatio: minNetRatio,
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
        bytes32 orderHash = _computeOrderHashMakerBid(_makerBid);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            _signerKey,
            keccak256(abi.encodePacked("\x19\x01", _domainSeparator, orderHash))
        );

        return abi.encodePacked(r, s, v);
    }

    function _signMerkleProof(OrderStructs.MerkleRoot memory _merkleRoot, uint256 _signerKey)
        internal
        returns (bytes memory)
    {
        bytes32 merkleRootHash = _merkleRoot.hash();

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            _signerKey,
            keccak256(abi.encodePacked("\x19\x01", _domainSeparator, merkleRootHash))
        );

        return abi.encodePacked(r, s, v);
    }

    function _computeOrderHashMakerBid(OrderStructs.MakerBid memory _makerBid) internal pure returns (bytes32) {
        return _makerBid.hash();
    }

    function _computeOrderHashMakerAsk(OrderStructs.MakerAsk memory _makerAsk) internal pure returns (bytes32) {
        return _makerAsk.hash();
    }
}
