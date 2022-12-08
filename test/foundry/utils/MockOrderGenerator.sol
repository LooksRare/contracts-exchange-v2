// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC165} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC165.sol";
import {OrderStructs} from "../../../contracts/libraries/OrderStructs.sol";
import {ProtocolHelpers} from "../utils/ProtocolHelpers.sol";

contract MockOrderGenerator is ProtocolHelpers {
    function _createMockMakerAskAndTakerBid(
        address collection
    ) internal view returns (OrderStructs.MakerAsk memory newMakerAsk, OrderStructs.TakerBid memory newTakerBid) {
        uint8 assetType;

        // If ERC1155, adjust asset type
        if (IERC165(collection).supportsInterface(0xd9b67a26)) {
            assetType = 1;
        }

        newMakerAsk = _createSingleItemMakerAskOrder(
            0,
            0,
            0,
            assetType,
            0,
            collection,
            address(0), // ETH
            makerUser,
            1 ether,
            0
        );

        newTakerBid = OrderStructs.TakerBid(
            takerUser,
            newMakerAsk.minPrice,
            newMakerAsk.itemIds,
            newMakerAsk.amounts,
            abi.encode()
        );
    }

    function _createMockMakerBidAndTakerAsk(
        address collection,
        address currency
    ) internal view returns (OrderStructs.MakerBid memory newMakerBid, OrderStructs.TakerAsk memory newTakerAsk) {
        uint8 assetType;
        // If ERC1155, adjust asset type
        if (IERC165(collection).supportsInterface(0x4e2312e0)) {
            assetType = 1;
        }

        newMakerBid = _createSingleItemMakerBidOrder(
            0,
            0,
            0,
            assetType,
            0,
            collection,
            currency,
            makerUser,
            1 ether,
            0
        );

        newTakerAsk = OrderStructs.TakerAsk(
            takerUser,
            newMakerBid.maxPrice,
            newMakerBid.itemIds,
            newMakerBid.amounts,
            abi.encode()
        );
    }

    function _createMockMakerAskAndTakerBidWithBundle(
        address collection,
        uint256 numberTokens
    ) internal view returns (OrderStructs.MakerAsk memory newMakerAsk, OrderStructs.TakerBid memory newTakerBid) {
        uint8 assetType;

        // If ERC1155, adjust asset type
        if (IERC165(collection).supportsInterface(0xd9b67a26)) {
            assetType = 1;
        }

        uint256[] memory itemIds = new uint256[](numberTokens);
        uint256[] memory amounts = new uint256[](numberTokens);

        for (uint256 i; i < itemIds.length; i++) {
            itemIds[i] = i;
            amounts[i] = 1;
        }

        newMakerAsk = _createMultiItemMakerAskOrder(
            0,
            0,
            0,
            assetType,
            0,
            collection,
            address(0),
            makerUser,
            1 ether,
            itemIds,
            amounts
        );

        newTakerBid = OrderStructs.TakerBid(
            takerUser,
            newMakerAsk.minPrice,
            newMakerAsk.itemIds,
            newMakerAsk.amounts,
            abi.encode()
        );
    }

    function _createMockMakerBidAndTakerAskWithBundle(
        address collection,
        address currency,
        uint256 numberTokens
    ) internal view returns (OrderStructs.MakerBid memory newMakerBid, OrderStructs.TakerAsk memory newTakerAsk) {
        uint8 assetType;
        // If ERC1155, adjust asset type
        if (IERC165(collection).supportsInterface(0x4e2312e0)) {
            assetType = 1;
        }

        uint256[] memory itemIds = new uint256[](numberTokens);
        uint256[] memory amounts = new uint256[](numberTokens);

        for (uint256 i; i < itemIds.length; i++) {
            itemIds[i] = i;
            amounts[i] = 1;
        }

        newMakerBid = _createMultiItemMakerBidOrder(
            0,
            0,
            0,
            assetType,
            0,
            collection,
            currency,
            makerUser,
            1 ether,
            itemIds,
            amounts
        );

        newTakerAsk = OrderStructs.TakerAsk(
            takerUser,
            newMakerBid.maxPrice,
            newMakerBid.itemIds,
            newMakerBid.amounts,
            abi.encode()
        );
    }
}
