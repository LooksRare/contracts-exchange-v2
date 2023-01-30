// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {OrderValidatorV2A} from "../../contracts/helpers/OrderValidatorV2A.sol";

// Constants
import {ASSET_TYPE_ERC721, ASSET_TYPE_ERC1155} from "../../contracts/constants/NumericConstants.sol";

// Libraries
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";

// Shared errors
import {STRATEGY_NOT_IMPLEMENTED, POTENTIAL_WRONG_ASSET_TYPE_SHOULD_BE_ERC721} from "../../contracts/constants/ValidationCodeConstants.sol";

// Utils
import {TestParameters} from "./utils/TestParameters.sol";
import {MockLooksRareProtocol} from "./utils/MockLooksRareProtocol.sol";

// Mocks
import {MockERC721SupportsNoInterface} from "../mock/MockERC721SupportsNoInterface.sol";

contract OrderValidatorV2ATest is TestParameters {
    OrderValidatorV2A private validator;

    function setUp() public {
        validator = new OrderValidatorV2A(address(new MockLooksRareProtocol()));
    }

    function testDeriveProtocolParameters() public {
        validator.deriveProtocolParameters();
        assertEq(address(validator.royaltyFeeRegistry()), address(1));
        assertEq(validator.domainSeparator(), bytes32("420"));
        // Just need to make sure it's not 0, hence copying the address from log.
        assertEq(address(validator.creatorFeeManager()), 0x037FC82298142374d974839236D2e2dF6B5BdD8F);
        assertEq(validator.maxCreatorFeeBp(), 69);
    }

    function testCheckMakerAskOrderValidityStrategyNotImplemented() public {
        OrderStructs.MakerAsk memory makerAsk;
        makerAsk.strategyId = 1;
        uint256[9] memory validationCodes = validator.checkMakerAskOrderValidity(
            makerAsk,
            new bytes(65),
            _EMPTY_MERKLE_TREE
        );
        assertEq(validationCodes[0], STRATEGY_NOT_IMPLEMENTED);
    }

    function testCheckMakerBidOrderValidityStrategyNotImplemented() public {
        OrderStructs.MakerBid memory makerBid;
        makerBid.currency = address(1); // it cannot be 0
        makerBid.strategyId = 1;
        uint256[9] memory validationCodes = validator.checkMakerBidOrderValidity(
            makerBid,
            new bytes(65),
            _EMPTY_MERKLE_TREE
        );
        assertEq(validationCodes[0], STRATEGY_NOT_IMPLEMENTED);
    }

    function testMakerAskWrongAssetTypeERC721() public {
        OrderStructs.MakerAsk memory makerAsk;
        makerAsk.assetType = ASSET_TYPE_ERC721;
        makerAsk.collection = address(new MockERC721SupportsNoInterface());
        uint256[9] memory validationCodes = validator.checkMakerAskOrderValidity(
            makerAsk,
            new bytes(65),
            _EMPTY_MERKLE_TREE
        );
        assertEq(validationCodes[6], POTENTIAL_WRONG_ASSET_TYPE_SHOULD_BE_ERC721);
    }

    function testMakerBidWrongAssetTypeERC721() public {
        OrderStructs.MakerBid memory makerBid;
        makerBid.assetType = ASSET_TYPE_ERC721;
        makerBid.collection = address(new MockERC721SupportsNoInterface());
        uint256[9] memory validationCodes = validator.checkMakerBidOrderValidity(
            makerBid,
            new bytes(65),
            _EMPTY_MERKLE_TREE
        );
        assertEq(validationCodes[6], POTENTIAL_WRONG_ASSET_TYPE_SHOULD_BE_ERC721);
    }
}
