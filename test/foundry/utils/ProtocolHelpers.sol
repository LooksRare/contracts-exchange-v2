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
    using OrderStructs for OrderStructs.MakerAsk;
    using OrderStructs for OrderStructs.MakerBid;

    receive() external payable {}

    bytes32 internal _domainSeparator;

    function _createSimpleMakerAskOrder(uint256 price, uint256 itemId)
        internal
        pure
        returns (OrderStructs.MakerAsk memory makerAsk)
    {
        uint256[] memory itemIds = new uint256[](1);
        itemIds[0] = itemId;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        makerAsk.minPrice = price;
        makerAsk.itemIds = itemIds;
        makerAsk.amounts = amounts;
    }

    function _createSimpleMakerBidOrder(uint256 price, uint256 itemId)
        internal
        pure
        returns (OrderStructs.MakerBid memory makerBid)
    {
        uint256[] memory itemIds = new uint256[](1);
        itemIds[0] = itemId;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        makerBid.maxPrice = price;
        makerBid.itemIds = itemIds;
        makerBid.amounts = amounts;
    }

    function _createMultipleItemsMakerAskOrder(uint256 price, uint256[] calldata _itemIds)
        internal
        pure
        returns (OrderStructs.MakerAsk memory makerAsk)
    {
        uint256[] memory itemIds = new uint256[](_itemIds.length);
        uint256[] memory amounts = new uint256[](_itemIds.length);

        for (uint256 i; i < _itemIds.length; i++) {
            itemIds[i] = _itemIds[i];
            amounts[i] = 1;
        }

        makerAsk.minPrice = price;
        makerAsk.itemIds = itemIds;
        makerAsk.amounts = amounts;
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
        bytes32 orderHash = _makerBid.hash();

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            _signerKey,
            keccak256(abi.encodePacked("\x19\x01", _domainSeparator, orderHash))
        );

        return abi.encodePacked(r, s, v);
    }
}
