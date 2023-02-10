// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Generic interfaces
import {IERC165} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC165.sol";

// Libraries
import {OrderStructs} from "../../../contracts/libraries/OrderStructs.sol";

// Other helpers
import {ProtocolHelpers} from "../utils/ProtocolHelpers.sol";

// Enums
import {AssetType} from "../../../contracts/enums/AssetType.sol";
import {QuoteType} from "../../../contracts/enums/QuoteType.sol";

contract MockOrderGenerator is ProtocolHelpers {
    function _createMockMakerAskAndTakerBid(
        address collection
    ) internal view returns (OrderStructs.Maker memory newMakerAsk, OrderStructs.Taker memory newTakerBid) {
        AssetType assetType = _getAssetType(collection);

        newMakerAsk = _createSingleItemMakerOrder({
            quoteType: QuoteType.Ask,
            globalNonce: 0,
            subsetNonce: 0,
            strategyId: STANDARD_SALE_FOR_FIXED_PRICE_STRATEGY,
            assetType: assetType,
            orderNonce: 0,
            collection: collection,
            currency: ETH,
            signer: makerUser,
            price: 1 ether,
            itemId: 420
        });

        newTakerBid = OrderStructs.Taker(takerUser, abi.encode());
    }

    function _createMockMakerBidAndTakerAsk(
        address collection,
        address currency
    ) internal view returns (OrderStructs.Maker memory newMakerBid, OrderStructs.Taker memory newTakerAsk) {
        AssetType assetType = _getAssetType(collection);

        newMakerBid = _createSingleItemMakerOrder({
            quoteType: QuoteType.Bid,
            globalNonce: 0,
            subsetNonce: 0,
            strategyId: STANDARD_SALE_FOR_FIXED_PRICE_STRATEGY,
            assetType: assetType,
            orderNonce: 0,
            collection: collection,
            currency: currency,
            signer: makerUser,
            price: 1 ether,
            itemId: 420
        });

        newTakerAsk = OrderStructs.Taker(takerUser, abi.encode());
    }

    function _createMockMakerAskAndTakerBidWithBundle(
        address collection,
        uint256 numberTokens
    ) internal view returns (OrderStructs.Maker memory newMakerAsk, OrderStructs.Taker memory newTakerBid) {
        AssetType assetType = _getAssetType(collection);

        (uint256[] memory itemIds, uint256[] memory amounts) = _setBundleItemIdsAndAmounts(assetType, numberTokens);

        newMakerAsk = _createMultiItemMakerOrder({
            quoteType: QuoteType.Ask,
            globalNonce: 0,
            subsetNonce: 0,
            strategyId: STANDARD_SALE_FOR_FIXED_PRICE_STRATEGY,
            assetType: assetType,
            orderNonce: 0,
            collection: collection,
            currency: ETH,
            signer: makerUser,
            price: 1 ether,
            itemIds: itemIds,
            amounts: amounts
        });

        newTakerBid = OrderStructs.Taker(takerUser, abi.encode());
    }

    function _createMockMakerBidAndTakerAskWithBundle(
        address collection,
        address currency,
        uint256 numberTokens
    ) internal view returns (OrderStructs.Maker memory newMakerBid, OrderStructs.Taker memory newTakerAsk) {
        AssetType assetType = _getAssetType(collection);

        (uint256[] memory itemIds, uint256[] memory amounts) = _setBundleItemIdsAndAmounts(assetType, numberTokens);

        newMakerBid = _createMultiItemMakerOrder({
            quoteType: QuoteType.Bid,
            globalNonce: 0,
            subsetNonce: 0,
            strategyId: STANDARD_SALE_FOR_FIXED_PRICE_STRATEGY,
            assetType: assetType,
            orderNonce: 0,
            collection: collection,
            currency: currency,
            signer: makerUser,
            price: 1 ether,
            itemIds: itemIds,
            amounts: amounts
        });

        newTakerAsk = OrderStructs.Taker(takerUser, abi.encode());
    }

    function _getAssetType(address collection) private view returns (AssetType assetType) {
        assetType = AssetType.ERC721;

        // If ERC1155, adjust asset type
        if (IERC165(collection).supportsInterface(0xd9b67a26)) {
            assetType = AssetType.ERC1155;
        }
    }

    function _setBundleItemIdsAndAmounts(
        AssetType assetType,
        uint256 numberTokens
    ) private pure returns (uint256[] memory itemIds, uint256[] memory amounts) {
        itemIds = new uint256[](numberTokens);
        amounts = new uint256[](numberTokens);

        for (uint256 i; i < itemIds.length; i++) {
            itemIds[i] = i;
            if (assetType != AssetType.ERC1155) {
                amounts[i] = 1;
            } else {
                amounts[i] = 1 + i;
            }
        }
    }
}
