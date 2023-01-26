// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Libraries, interfaces, errors
import {BadSignatureV, BadSignatureS, InvalidSignatureEOA, NullSignerAddress, WrongSignatureLength} from "@looksrare/contracts-libs/contracts/errors/SignatureCheckerErrors.sol";
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";

// Base test
import {ProtocolBase} from "./ProtocolBase.t.sol";

// Constants
import {ONE_HUNDRED_PERCENT_IN_BP, ASSET_TYPE_ERC721} from "../../contracts/constants/NumericConstants.sol";
import {INVALID_S_PARAMETER_EOA, INVALID_V_PARAMETER_EOA, NULL_SIGNER_EOA, WRONG_SIGNATURE_LENGTH, WRONG_SIGNER_EOA} from "../../contracts/constants/ValidationCodeConstants.sol";

contract SignatureCheckerRevertions is ProtocolBase {
    function testRevertIfWrongSignatureEOA(uint256 itemId, uint256 price, uint256 randomPK) public {
        // Private keys 1 and 2 are used for maker/taker users
        vm.assume(
            randomPK > 2 && randomPK < 115792089237316195423570985008687907852837564279074904382605163141518161494337
        );

        OrderStructs.MakerAsk memory makerAsk = _createSingleItemMakerAskOrder({
            askNonce: 0,
            subsetNonce: 0,
            strategyId: STANDARD_SALE_FOR_FIXED_PRICE_STRATEGY,
            assetType: ASSET_TYPE_ERC721,
            orderNonce: 0,
            collection: address(mockERC721),
            currency: ETH,
            signer: makerUser,
            minPrice: price,
            itemId: itemId
        });

        address randomUser = vm.addr(randomPK);
        _setUpUser(randomUser);
        bytes memory signature = _signMakerAsk(makerAsk, randomPK);
        _doesMakerAskOrderReturnValidationCode(makerAsk, signature, WRONG_SIGNER_EOA);

        OrderStructs.TakerBid memory takerBid = OrderStructs.TakerBid(
            takerUser,
            makerAsk.minPrice,
            new uint256[](0),
            new uint256[](0),
            abi.encode()
        );

        vm.expectRevert(InvalidSignatureEOA.selector);
        vm.prank(takerUser);
        looksRareProtocol.executeTakerBid(takerBid, makerAsk, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function testRevertIfWrongVParameter(uint256 itemId, uint256 price, uint8 v) public {
        vm.assume(v != 27 && v != 28);

        OrderStructs.MakerAsk memory makerAsk = _createSingleItemMakerAskOrder({
            askNonce: 0,
            subsetNonce: 0,
            strategyId: STANDARD_SALE_FOR_FIXED_PRICE_STRATEGY,
            assetType: ASSET_TYPE_ERC721,
            orderNonce: 0,
            collection: address(mockERC721),
            currency: ETH,
            signer: makerUser,
            minPrice: price,
            itemId: itemId
        });

        // Sign but replace v by the fuzzed v
        bytes32 orderHash = _computeOrderHashMakerAsk(makerAsk);
        (, bytes32 r, bytes32 s) = vm.sign(
            makerUserPK,
            keccak256(abi.encodePacked("\x19\x01", _domainSeparator, orderHash))
        );
        bytes memory signature = abi.encodePacked(r, s, v);

        _doesMakerAskOrderReturnValidationCode(makerAsk, signature, INVALID_V_PARAMETER_EOA);

        OrderStructs.TakerBid memory takerBid = OrderStructs.TakerBid(
            takerUser,
            makerAsk.minPrice,
            new uint256[](0),
            new uint256[](0),
            abi.encode()
        );

        vm.expectRevert(abi.encodeWithSelector(BadSignatureV.selector, v));
        vm.prank(takerUser);
        looksRareProtocol.executeTakerBid(takerBid, makerAsk, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function testRevertIfWrongSParameter(uint256 itemId, uint256 price, bytes32 s) public {
        vm.assume(uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0);

        OrderStructs.MakerAsk memory makerAsk = _createSingleItemMakerAskOrder({
            askNonce: 0,
            subsetNonce: 0,
            strategyId: STANDARD_SALE_FOR_FIXED_PRICE_STRATEGY,
            assetType: ASSET_TYPE_ERC721,
            orderNonce: 0,
            collection: address(mockERC721),
            currency: ETH,
            signer: makerUser,
            minPrice: price,
            itemId: itemId
        });

        // Sign but replace s by the fuzzed s
        bytes32 orderHash = _computeOrderHashMakerAsk(makerAsk);
        (uint8 v, bytes32 r, ) = vm.sign(
            makerUserPK,
            keccak256(abi.encodePacked("\x19\x01", _domainSeparator, orderHash))
        );
        bytes memory signature = abi.encodePacked(r, s, v);

        _doesMakerAskOrderReturnValidationCode(makerAsk, signature, INVALID_S_PARAMETER_EOA);

        OrderStructs.TakerBid memory takerBid = OrderStructs.TakerBid(
            takerUser,
            makerAsk.minPrice,
            new uint256[](0),
            new uint256[](0),
            abi.encode()
        );

        vm.expectRevert(abi.encodeWithSelector(BadSignatureS.selector));
        vm.prank(takerUser);
        looksRareProtocol.executeTakerBid(takerBid, makerAsk, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function testCannotSignIfWrongSignatureLength(uint256 itemId, uint256 price, uint256 length) public {
        // Getting OutOfGas starting from 16,776,985, probably due to memory cost
        vm.assume(length != 64 && length != 65 && length < 16_776_985);

        OrderStructs.MakerAsk memory makerAsk = _createSingleItemMakerAskOrder({
            askNonce: 0,
            subsetNonce: 0,
            strategyId: STANDARD_SALE_FOR_FIXED_PRICE_STRATEGY,
            assetType: ASSET_TYPE_ERC721,
            orderNonce: 0,
            collection: address(mockERC721),
            currency: ETH,
            signer: makerUser,
            minPrice: price,
            itemId: itemId
        });

        bytes memory signature = new bytes(length);
        _doesMakerAskOrderReturnValidationCode(makerAsk, signature, WRONG_SIGNATURE_LENGTH);

        OrderStructs.TakerBid memory takerBid = OrderStructs.TakerBid(
            takerUser,
            makerAsk.minPrice,
            new uint256[](0),
            new uint256[](0),
            abi.encode()
        );

        vm.expectRevert(abi.encodeWithSelector(WrongSignatureLength.selector, length));
        vm.prank(takerUser);
        looksRareProtocol.executeTakerBid(takerBid, makerAsk, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }
}