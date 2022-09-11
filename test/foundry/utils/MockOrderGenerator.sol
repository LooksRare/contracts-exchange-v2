// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC165} from "@looksrare/contracts-libs/contracts/interfaces/IERC165.sol";
import {OrderStructs} from "../../../contracts/libraries/OrderStructs.sol";
import {ProtocolHelpers} from "./ProtocolHelpers.sol";

contract MockOrderGenerator is ProtocolHelpers {
    function _createMockMakerAskAndTakerBid(address collection)
        internal
        view
        returns (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid)
    {
        uint8 assetType;

        // If ERC1155, adjust asset type
        if (IERC165(collection).supportsInterface(0xd9b67a26)) {
            assetType = 1;
        }

        makerAsk = _createSingleItemMakerAskOrder(
            0,
            0,
            0,
            assetType,
            0,
            0,
            collection,
            address(0), // ETH
            makerUser,
            1 ether,
            0
        );
        takerBid = OrderStructs.TakerBid(
            takerUser,
            makerAsk.minNetRatio,
            makerAsk.minPrice,
            makerAsk.itemIds,
            makerAsk.amounts,
            abi.encode()
        );
    }

    function _createMockMakerBidAndTakerAsk(address collection, address currency)
        internal
        view
        returns (OrderStructs.MakerBid memory makerBid, OrderStructs.TakerAsk memory takerAsk)
    {
        uint8 assetType;
        // If ERC1155, adjust asset type
        if (IERC165(collection).supportsInterface(0x4e2312e0)) {
            assetType = 1;
        }

        makerBid = _createSingleItemMakerBidOrder(
            0,
            0,
            0,
            assetType,
            0,
            0,
            collection,
            currency,
            makerUser,
            1 ether,
            0
        );

        takerAsk = OrderStructs.TakerAsk(
            takerUser,
            makerBid.minNetRatio,
            makerBid.maxPrice,
            makerBid.itemIds,
            makerBid.amounts,
            abi.encode()
        );
    }

    function _createMockMakerAskAndTakerBidWithBundle(address collection, uint256 numberTokens)
        internal
        view
        returns (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid)
    {
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

        makerAsk = _createMultiItemMakerAskOrder(
            0,
            0,
            0,
            assetType,
            0,
            0,
            collection,
            address(0),
            makerUser,
            1 ether,
            itemIds,
            amounts
        );

        takerBid = OrderStructs.TakerBid(
            takerUser,
            makerAsk.minNetRatio,
            makerAsk.minPrice,
            makerAsk.itemIds,
            makerAsk.amounts,
            abi.encode()
        );
    }

    function _createMockMakerBidAndTakerAskWithBundle(
        address collection,
        address currency,
        uint256 numberTokens
    ) internal view returns (OrderStructs.MakerBid memory makerBid, OrderStructs.TakerAsk memory takerAsk) {
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

        makerBid = _createMultiItemMakerBidOrder(
            0,
            0,
            0,
            assetType,
            0,
            0,
            collection,
            currency,
            makerUser,
            1 ether,
            itemIds,
            amounts
        );

        takerAsk = OrderStructs.TakerAsk(
            takerUser,
            makerBid.minNetRatio,
            makerBid.maxPrice,
            makerBid.itemIds,
            makerBid.amounts,
            abi.encode()
        );
    }
}
