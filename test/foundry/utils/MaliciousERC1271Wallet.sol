// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ILooksRareProtocol} from "../../../contracts/interfaces/ILooksRareProtocol.sol";
import {OrderStructs} from "../../../contracts/libraries/OrderStructs.sol";

contract MaliciousERC1271Wallet {
    enum FunctionToReenter {
        ExecuteTakerAsk,
        ExecuteTakerBid,
        ExecuteMultipleTakerBids
    }

    ILooksRareProtocol private immutable looksRareProtocol;
    FunctionToReenter private functionToReenter;

    constructor(address _looksRareProtocol) {
        looksRareProtocol = ILooksRareProtocol(_looksRareProtocol);
    }

    function isValidSignature(bytes32, bytes calldata signature) external returns (bytes4 magicValue) {
        if (functionToReenter == FunctionToReenter.ExecuteTakerAsk) {
            _executeTakerAsk(signature);
        } else if (functionToReenter == FunctionToReenter.ExecuteTakerBid) {} else if (
            functionToReenter == FunctionToReenter.ExecuteMultipleTakerBids
        ) {}

        magicValue = this.isValidSignature.selector;
    }

    function setFunctionToReenter(FunctionToReenter _functionToReenter) external {
        functionToReenter = _functionToReenter;
    }

    function _executeTakerAsk(bytes calldata signature) private {
        OrderStructs.TakerAsk memory takerAsk;
        OrderStructs.MakerBid memory makerBid;
        OrderStructs.MerkleTree memory merkleTree = OrderStructs.MerkleTree({
            root: bytes32(0),
            proof: new bytes32[](0)
        });

        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, merkleTree, address(this));
    }
}
