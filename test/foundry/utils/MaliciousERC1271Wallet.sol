// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ILooksRareProtocol} from "../../../contracts/interfaces/ILooksRareProtocol.sol";
import {OrderStructs} from "../../../contracts/libraries/OrderStructs.sol";

abstract contract MaliciousERC1271Wallet {
    enum FunctionToReenter {
        None,
        ExecuteTakerAsk,
        ExecuteTakerBid,
        ExecuteMultipleTakerBids
    }

    ILooksRareProtocol internal immutable looksRareProtocol;
    FunctionToReenter internal functionToReenter;

    constructor(address _looksRareProtocol) {
        looksRareProtocol = ILooksRareProtocol(_looksRareProtocol);
    }

    function setFunctionToReenter(FunctionToReenter _functionToReenter) external {
        functionToReenter = _functionToReenter;
    }

    function isValidSignature(bytes32, bytes calldata) external virtual returns (bytes4 magicValue) {
        magicValue = this.isValidSignature.selector;
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external virtual returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external virtual returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    function _executeTakerAsk(bytes memory signature) internal {
        OrderStructs.TakerAsk memory takerAsk;
        OrderStructs.MakerBid memory makerBid;
        OrderStructs.MerkleTree memory merkleTree;

        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, merkleTree, address(this));
    }

    function _executeTakerBid(bytes memory signature) internal {
        OrderStructs.TakerBid memory takerBid;
        OrderStructs.MakerAsk memory makerAsk;
        OrderStructs.MerkleTree memory merkleTree;

        looksRareProtocol.executeTakerBid(takerBid, makerAsk, signature, merkleTree, address(this));
    }

    function _executeMultipleTakerBids() internal {
        OrderStructs.TakerBid[] memory takerBids = new OrderStructs.TakerBid[](2);
        OrderStructs.MakerAsk[] memory makerAsks = new OrderStructs.MakerAsk[](2);
        bytes[] memory signatures = new bytes[](2);
        OrderStructs.MerkleTree[] memory merkleTrees = new OrderStructs.MerkleTree[](2);

        looksRareProtocol.executeMultipleTakerBids(takerBids, makerAsks, signatures, merkleTrees, address(this), false);
    }
}
