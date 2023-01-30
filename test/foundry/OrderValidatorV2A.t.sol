// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {OrderValidatorV2A} from "../../contracts/helpers/OrderValidatorV2A.sol";

// Constants
import {ASSET_TYPE_ERC721, ASSET_TYPE_ERC1155} from "../../contracts/constants/NumericConstants.sol";

// Libraries
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";

// Shared errors
import {ERC20_APPROVAL_INFERIOR_TO_PRICE, ERC721_ITEM_ID_NOT_IN_BALANCE, ERC1155_BALANCE_OF_ITEM_ID_INFERIOR_TO_AMOUNT, POTENTIAL_WRONG_ASSET_TYPE_SHOULD_BE_ERC721, POTENTIAL_WRONG_ASSET_TYPE_SHOULD_BE_ERC1155, STRATEGY_NOT_IMPLEMENTED} from "../../contracts/constants/ValidationCodeConstants.sol";

// Utils
import {TestParameters} from "./utils/TestParameters.sol";
import {MockLooksRareProtocol} from "./utils/MockLooksRareProtocol.sol";

// Mocks
import {MockERC721} from "../mock/MockERC721.sol";
import {MockERC1155} from "../mock/MockERC1155.sol";
import {MockERC721SupportsNoInterface} from "../mock/MockERC721SupportsNoInterface.sol";
import {MockERC1155SupportsNoInterface} from "../mock/MockERC1155SupportsNoInterface.sol";
import {MockERC20} from "../mock/MockERC20.sol";

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

    function testMakerAskWrongAssetTypeERC1155() public {
        OrderStructs.MakerAsk memory makerAsk;
        makerAsk.assetType = ASSET_TYPE_ERC1155;
        makerAsk.collection = address(new MockERC1155SupportsNoInterface());
        uint256[9] memory validationCodes = validator.checkMakerAskOrderValidity(
            makerAsk,
            new bytes(65),
            _EMPTY_MERKLE_TREE
        );
        assertEq(validationCodes[6], POTENTIAL_WRONG_ASSET_TYPE_SHOULD_BE_ERC1155);
    }

    function testMakerBidWrongAssetTypeERC1155() public {
        OrderStructs.MakerBid memory makerBid;
        makerBid.assetType = ASSET_TYPE_ERC1155;
        makerBid.collection = address(new MockERC1155SupportsNoInterface());
        uint256[9] memory validationCodes = validator.checkMakerBidOrderValidity(
            makerBid,
            new bytes(65),
            _EMPTY_MERKLE_TREE
        );
        assertEq(validationCodes[6], POTENTIAL_WRONG_ASSET_TYPE_SHOULD_BE_ERC1155);
    }

    function testMakerBidInsufficientERC20Allowance() public {
        OrderStructs.MakerBid memory makerBid;
        MockERC20 mockERC20 = new MockERC20();
        makerBid.assetType = ASSET_TYPE_ERC721;
        makerBid.collection = address(new MockERC721());
        makerBid.signer = makerUser;
        makerBid.currency = address(mockERC20);
        makerBid.assetType = ASSET_TYPE_ERC721;
        makerBid.maxPrice = 1 ether;

        mockERC20.mint(makerUser, 1 ether);

        vm.startPrank(makerUser);
        mockERC20.approve(address(validator.looksRareProtocol()), makerBid.maxPrice - 1 wei);
        vm.stopPrank();

        uint256[9] memory validationCodes = validator.checkMakerBidOrderValidity(
            makerBid,
            new bytes(65),
            _EMPTY_MERKLE_TREE
        );
        assertEq(validationCodes[5], ERC20_APPROVAL_INFERIOR_TO_PRICE);
    }

    function testMakerAskDoesNotOwnERC721() public {
        OrderStructs.MakerAsk memory makerAsk;
        makerAsk.assetType = ASSET_TYPE_ERC721;
        MockERC721 mockERC721 = new MockERC721();
        mockERC721.mint(address(this), 0);
        makerAsk.collection = address(mockERC721);
        makerAsk.signer = makerUser;
        makerAsk.assetType = ASSET_TYPE_ERC721;
        uint256[] memory itemIds = new uint256[](1);
        makerAsk.itemIds = itemIds;

        uint256[9] memory validationCodes = validator.checkMakerAskOrderValidity(
            makerAsk,
            new bytes(65),
            _EMPTY_MERKLE_TREE
        );
        assertEq(validationCodes[5], ERC721_ITEM_ID_NOT_IN_BALANCE);
    }

    function testMakerAskERC1155BalanceInferiorToAmount() public {
        OrderStructs.MakerAsk memory makerAsk;
        makerAsk.assetType = ASSET_TYPE_ERC1155;
        MockERC1155 mockERC1155 = new MockERC1155();
        makerAsk.collection = address(mockERC1155);
        makerAsk.signer = makerUser;
        makerAsk.assetType = ASSET_TYPE_ERC1155;
        uint256[] memory itemIds = new uint256[](1);
        makerAsk.itemIds = itemIds;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;
        makerAsk.amounts = amounts;

        uint256[9] memory validationCodes = validator.checkMakerAskOrderValidity(
            makerAsk,
            new bytes(65),
            _EMPTY_MERKLE_TREE
        );
        assertEq(validationCodes[5], ERC1155_BALANCE_OF_ITEM_ID_INFERIOR_TO_AMOUNT);
    }
}
