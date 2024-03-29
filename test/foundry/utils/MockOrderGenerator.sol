// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Generic interfaces
import {IERC165} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC165.sol";

// Libraries
import {OrderStructs} from "../../../contracts/libraries/OrderStructs.sol";

// Other helpers
import {ProtocolHelpers} from "../utils/ProtocolHelpers.sol";

// Enums
import {CollectionType} from "../../../contracts/enums/CollectionType.sol";
import {QuoteType} from "../../../contracts/enums/QuoteType.sol";

contract MockOrderGenerator is ProtocolHelpers {
    function _createMockMakerAskAndTakerBid(
        address collection
    ) internal view returns (OrderStructs.Maker memory newMakerAsk, OrderStructs.Taker memory newTakerBid) {
        CollectionType collectionType = _getCollectionType(collection);

        newMakerAsk = _createSingleItemMakerOrder({
            quoteType: QuoteType.Ask,
            globalNonce: 0,
            subsetNonce: 0,
            strategyId: STANDARD_SALE_FOR_FIXED_PRICE_STRATEGY,
            collectionType: collectionType,
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
        CollectionType collectionType = _getCollectionType(collection);

        newMakerBid = _createSingleItemMakerOrder({
            quoteType: QuoteType.Bid,
            globalNonce: 0,
            subsetNonce: 0,
            strategyId: STANDARD_SALE_FOR_FIXED_PRICE_STRATEGY,
            collectionType: collectionType,
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
        CollectionType collectionType = _getCollectionType(collection);

        (uint256[] memory itemIds, uint256[] memory amounts) = _setBundleItemIdsAndAmounts(
            collectionType,
            numberTokens
        );

        newMakerAsk = _createMultiItemMakerOrder({
            quoteType: QuoteType.Ask,
            globalNonce: 0,
            subsetNonce: 0,
            strategyId: STANDARD_SALE_FOR_FIXED_PRICE_STRATEGY,
            collectionType: collectionType,
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
        CollectionType collectionType = _getCollectionType(collection);

        (uint256[] memory itemIds, uint256[] memory amounts) = _setBundleItemIdsAndAmounts(
            collectionType,
            numberTokens
        );

        newMakerBid = _createMultiItemMakerOrder({
            quoteType: QuoteType.Bid,
            globalNonce: 0,
            subsetNonce: 0,
            strategyId: STANDARD_SALE_FOR_FIXED_PRICE_STRATEGY,
            collectionType: collectionType,
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

    function _getCollectionType(address collection) private view returns (CollectionType collectionType) {
        collectionType = CollectionType.ERC721;

        // If ERC1155, adjust the collection type
        if (IERC165(collection).supportsInterface(0xd9b67a26)) {
            collectionType = CollectionType.ERC1155;
        }
    }

    function _setBundleItemIdsAndAmounts(
        CollectionType collectionType,
        uint256 numberTokens
    ) private pure returns (uint256[] memory itemIds, uint256[] memory amounts) {
        itemIds = new uint256[](numberTokens);
        amounts = new uint256[](numberTokens);

        for (uint256 i; i < itemIds.length; i++) {
            itemIds[i] = i;
            if (collectionType != CollectionType.ERC1155) {
                amounts[i] = 1;
            } else {
                amounts[i] = 1 + i;
            }
        }
    }
}
