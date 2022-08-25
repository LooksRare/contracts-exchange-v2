// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {TestHelpers} from "./TestHelpers.sol";

import {IExecutionManager} from "../../../contracts/interfaces/IExecutionManager.sol";
import {OrderStructs} from "../../../contracts/libraries/OrderStructs.sol";

abstract contract TestParameters is TestHelpers {
    address internal _owner = address(42);
    address internal _collectionOwner = address(22);
    uint256 internal makerUserPK = 1;
    uint256 internal takerUserPK = 2;
    address internal makerUser = vm.addr(makerUserPK);
    address internal takerUser = vm.addr(takerUserPK);
}

contract ProtocolHelpers is TestParameters, IExecutionManager {
    receive() external payable {}

    bytes32 internal _domainSeparator;

    function _createSimpleMakerAskOrder(uint256 price, uint256 itemId)
        internal
        pure
        returns (OrderStructs.SingleMakerAskOrder memory makerAskOrder)
    {
        uint256[] memory itemIds = new uint256[](1);
        itemIds[0] = itemId;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        makerAskOrder.minPrice = price;
        makerAskOrder.itemIds = itemIds;
        makerAskOrder.amounts = amounts;
    }

    function _createSimpleMakerBidOrder(uint256 price, uint256 itemId)
        internal
        pure
        returns (OrderStructs.SingleMakerBidOrder memory makerBidOrder)
    {
        uint256[] memory itemIds = new uint256[](1);
        itemIds[0] = itemId;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        makerBidOrder.maxPrice = price;
        makerBidOrder.itemIds = itemIds;
        makerBidOrder.amounts = amounts;
    }

    function _createMultipleItemsMakerAskOrder(uint256 price, uint256[] calldata _itemIds)
        internal
        pure
        returns (OrderStructs.SingleMakerAskOrder memory makerAskOrder)
    {
        makerAskOrder.minPrice = price;

        uint256[] memory itemIds = new uint256[](_itemIds.length);
        uint256[] memory amounts = new uint256[](_itemIds.length);

        for (uint256 i; i < _itemIds.length; i++) {
            itemIds[i] = _itemIds[i];
            amounts[i] = 1;
        }

        makerAskOrder.itemIds = itemIds;
        makerAskOrder.amounts = amounts;

        return makerAskOrder;
    }

    function _signMakerAsksOrder(OrderStructs.MultipleMakerAskOrders memory _makerAsks, uint256 _signerKey)
        internal
        returns (bytes memory)
    {
        bytes32 _MAKER_ASK_ORDERS_HASH = OrderStructs._MULTIPLE_MAKER_ASK_ORDERS;

        bytes32 orderHash = keccak256(
            abi.encode(_MAKER_ASK_ORDERS_HASH, _makerAsks.makerAskOrders, _makerAsks.baseMakerOrder)
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            _signerKey,
            keccak256(abi.encodePacked("\x19\x01", _domainSeparator, orderHash))
        );

        return abi.encodePacked(r, s, v);
    }

    function _signMakerBidsOrder(OrderStructs.MultipleMakerBidOrders memory _makerBids, uint256 _signerKey)
        internal
        returns (bytes memory)
    {
        bytes32 _MAKER_BID_ORDERS_HASH = OrderStructs._MULTIPLE_MAKER_BID_ORDERS;

        bytes32 orderHash = keccak256(
            abi.encode(_MAKER_BID_ORDERS_HASH, _makerBids.makerBidOrders, _makerBids.baseMakerOrder)
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            _signerKey,
            keccak256(abi.encodePacked("\x19\x01", _domainSeparator, orderHash))
        );

        return abi.encodePacked(r, s, v);
    }
}
