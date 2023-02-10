// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Dependencies
import {BatchOrderTypehashRegistry} from "../../../contracts/BatchOrderTypehashRegistry.sol";

// Libraries
import {OrderStructs} from "../../../contracts/libraries/OrderStructs.sol";

// Other tests
import {TestHelpers} from "./TestHelpers.sol";
import {TestParameters} from "./TestParameters.sol";

// Enums
import {AssetType} from "../../../contracts/enums/AssetType.sol";
import {QuoteType} from "../../../contracts/enums/QuoteType.sol";

contract ProtocolHelpers is TestHelpers, TestParameters {
    using OrderStructs for OrderStructs.Maker;
    using OrderStructs for OrderStructs.MerkleTree;

    bytes32 internal _domainSeparator;

    receive() external payable {}

    function _createSingleItemMakerOrder(
        QuoteType quoteType,
        uint256 globalNonce,
        uint256 subsetNonce,
        uint256 strategyId,
        AssetType assetType,
        uint256 orderNonce,
        address collection,
        address currency,
        address signer,
        uint256 price,
        uint256 itemId
    ) internal view returns (OrderStructs.Maker memory makerOrder) {
        uint256[] memory itemIds = new uint256[](1);
        itemIds[0] = itemId;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        makerOrder = OrderStructs.Maker({
            quoteType: quoteType,
            globalNonce: globalNonce,
            subsetNonce: subsetNonce,
            orderNonce: orderNonce,
            strategyId: strategyId,
            assetType: assetType,
            collection: collection,
            currency: currency,
            signer: signer,
            startTime: block.timestamp,
            endTime: block.timestamp + 1,
            price: price,
            itemIds: itemIds,
            amounts: amounts,
            additionalParameters: abi.encode()
        });
    }

    function _createMultiItemMakerOrder(
        QuoteType quoteType,
        uint256 globalNonce,
        uint256 subsetNonce,
        uint256 strategyId,
        AssetType assetType,
        uint256 orderNonce,
        address collection,
        address currency,
        address signer,
        uint256 price,
        uint256[] memory itemIds,
        uint256[] memory amounts
    ) internal view returns (OrderStructs.Maker memory newMakerBid) {
        newMakerBid = OrderStructs.Maker({
            quoteType: quoteType,
            globalNonce: globalNonce,
            subsetNonce: subsetNonce,
            orderNonce: orderNonce,
            strategyId: strategyId,
            assetType: assetType,
            collection: collection,
            currency: currency,
            signer: signer,
            startTime: block.timestamp,
            endTime: block.timestamp + 1,
            price: price,
            itemIds: itemIds,
            amounts: amounts,
            additionalParameters: abi.encode()
        });
    }

    function _createSingleItemMakerAndTakerOrderAndSignature(
        QuoteType quoteType,
        uint256 globalNonce,
        uint256 subsetNonce,
        uint256 strategyId,
        AssetType assetType,
        uint256 orderNonce,
        address collection,
        address currency,
        address signer,
        uint256 price,
        uint256 itemId
    )
        internal
        view
        returns (
            OrderStructs.Maker memory newMakerOrder,
            OrderStructs.Taker memory newTakerOrder,
            bytes memory signature
        )
    {
        newMakerOrder = _createSingleItemMakerOrder(
            quoteType,
            globalNonce,
            subsetNonce,
            strategyId,
            assetType,
            orderNonce,
            collection,
            currency,
            signer,
            price,
            itemId
        );

        signature = _signMakerOrder(newMakerOrder, makerUserPK);

        newTakerOrder = OrderStructs.Taker(takerUser, abi.encode());
    }

    function _signMakerOrder(OrderStructs.Maker memory maker, uint256 signerKey) internal view returns (bytes memory) {
        bytes32 orderHash = _computeOrderHash(maker);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            signerKey,
            keccak256(abi.encodePacked("\x19\x01", _domainSeparator, orderHash))
        );

        return abi.encodePacked(r, s, v);
    }

    function _computeOrderHash(OrderStructs.Maker memory maker) internal pure returns (bytes32) {
        return maker.hash();
    }
}
