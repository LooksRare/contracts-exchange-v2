// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {LooksRareProtocol} from "../../contracts/LooksRareProtocol.sol";
import {TransferManager} from "../../contracts/TransferManager.sol";
import {CreatorFeeManagerWithRoyalties} from "../../contracts/CreatorFeeManagerWithRoyalties.sol";

import {OrderValidatorV2A} from "../../contracts/helpers/OrderValidatorV2A.sol";

// Constants
import {ASSET_TYPE_ERC721, ASSET_TYPE_ERC1155} from "../../contracts/constants/NumericConstants.sol";

// Libraries
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";

// Shared errors
import {ERC20_APPROVAL_INFERIOR_TO_PRICE, ERC721_ITEM_ID_NOT_IN_BALANCE, ERC1155_BALANCE_OF_ITEM_ID_INFERIOR_TO_AMOUNT, MAKER_ORDER_INVALID_STANDARD_SALE, MISSING_IS_VALID_SIGNATURE_FUNCTION_EIP1271, POTENTIAL_WRONG_ASSET_TYPE_SHOULD_BE_ERC721, POTENTIAL_WRONG_ASSET_TYPE_SHOULD_BE_ERC1155, STRATEGY_NOT_IMPLEMENTED, TRANSFER_MANAGER_APPROVAL_REVOKED_BY_OWNER_FOR_EXCHANGE} from "../../contracts/constants/ValidationCodeConstants.sol";

// Utils
import {TestParameters} from "./utils/TestParameters.sol";

// Mocks
import {MockRoyaltyFeeRegistry} from "../mock/MockRoyaltyFeeRegistry.sol";
import {MockERC721} from "../mock/MockERC721.sol";
import {MockERC1155} from "../mock/MockERC1155.sol";
import {MockERC1155WithoutBalanceOfBatch} from "../mock/MockERC1155WithoutBalanceOfBatch.sol";
import {MockERC721SupportsNoInterface} from "../mock/MockERC721SupportsNoInterface.sol";
import {MockERC1155SupportsNoInterface} from "../mock/MockERC1155SupportsNoInterface.sol";
import {MockERC20} from "../mock/MockERC20.sol";

/**
 * @dev Not everything is tested in this file. Most tests live in other files
 * with the assert functions living in ProtocolBase.t.sol.
 */
contract OrderValidatorV2ATest is TestParameters {
    LooksRareProtocol private looksRareProtocol;
    OrderValidatorV2A private orderValidator;

    function setUp() public {
        TransferManager transferManager = new TransferManager(address(this));
        looksRareProtocol = new LooksRareProtocol(
            address(this),
            address(this),
            address(transferManager),
            0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
        );
        MockRoyaltyFeeRegistry royaltyFeeRegistry = new MockRoyaltyFeeRegistry(address(this), 9_500);
        CreatorFeeManagerWithRoyalties creatorFeeManager = new CreatorFeeManagerWithRoyalties(
            address(royaltyFeeRegistry)
        );
        looksRareProtocol.updateCreatorFeeManager(address(creatorFeeManager));
        looksRareProtocol.updateCurrencyWhitelistStatus(ETH, true);
        orderValidator = new OrderValidatorV2A(address(looksRareProtocol));
    }

    function testDeriveProtocolParameters() public {
        orderValidator.deriveProtocolParameters();
        assertEq(address(orderValidator.royaltyFeeRegistry()), 0x037FC82298142374d974839236D2e2dF6B5BdD8F);
        assertEq(orderValidator.domainSeparator(), bytes32("420"));
        // Just need to make sure it's not 0, hence copying the address from log.
        assertEq(address(orderValidator.creatorFeeManager()), 0x566B72091192CCd7013AdF77E2a1b349564acC21);
        assertEq(orderValidator.maxCreatorFeeBp(), 69);
    }

    function testCheckMakerAskOrderValidityStrategyNotImplemented() public {
        OrderStructs.MakerAsk memory makerAsk;
        makerAsk.strategyId = 1;
        uint256[9] memory validationCodes = orderValidator.checkMakerAskOrderValidity(
            makerAsk,
            new bytes(65),
            _EMPTY_MERKLE_TREE
        );
        assertEq(validationCodes[0], STRATEGY_NOT_IMPLEMENTED);
    }

    function testCheckMakerBidOrderValidityStrategyNotImplemented() public {
        OrderStructs.MakerBid memory makerBid;
        address currency = address(1); // it cannot be 0
        looksRareProtocol.updateCurrencyWhitelistStatus(currency, true);
        makerBid.currency = currency;
        makerBid.strategyId = 1;
        uint256[9] memory validationCodes = orderValidator.checkMakerBidOrderValidity(
            makerBid,
            new bytes(65),
            _EMPTY_MERKLE_TREE
        );
        assertEq(validationCodes[0], STRATEGY_NOT_IMPLEMENTED);
    }

    function testMakerAskLooksRareProtocolIsNotAWhitelistedOperator() public {
        OrderStructs.MakerAsk memory makerAsk;
        makerAsk.signer = makerUser;
        makerAsk.assetType = ASSET_TYPE_ERC721;
        makerAsk.collection = address(new MockERC721());

        address[] memory operators = new address[](1);
        operators[0] = address(orderValidator.looksRareProtocol());

        TransferManager transferManager = orderValidator.transferManager();

        transferManager.whitelistOperator(operators[0]);

        vm.prank(makerUser);
        transferManager.grantApprovals(operators);

        transferManager.removeOperator(operators[0]);

        uint256[9] memory validationCodes = orderValidator.checkMakerAskOrderValidity(
            makerAsk,
            new bytes(65),
            _EMPTY_MERKLE_TREE
        );
        assertEq(validationCodes[7], TRANSFER_MANAGER_APPROVAL_REVOKED_BY_OWNER_FOR_EXCHANGE);
    }

    function testMakerAskWrongAssetTypeERC721() public {
        OrderStructs.MakerAsk memory makerAsk;
        makerAsk.assetType = ASSET_TYPE_ERC721;
        makerAsk.collection = address(new MockERC721SupportsNoInterface());
        uint256[9] memory validationCodes = orderValidator.checkMakerAskOrderValidity(
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
        uint256[9] memory validationCodes = orderValidator.checkMakerBidOrderValidity(
            makerBid,
            new bytes(65),
            _EMPTY_MERKLE_TREE
        );
        assertEq(validationCodes[6], POTENTIAL_WRONG_ASSET_TYPE_SHOULD_BE_ERC721);
    }

    function testMakerBidZeroAmount() public {
        _testMakerBidERC721InvalidAmount(0);
    }

    function testMakerBidERC721AmountNotEqualToOne() public {
        _testMakerBidERC721InvalidAmount(2);
    }

    function _testMakerBidERC721InvalidAmount(uint256 amount) public {
        OrderStructs.MakerBid memory makerBid;
        makerBid.assetType = ASSET_TYPE_ERC721;
        makerBid.collection = address(new MockERC721());
        uint256[] memory itemIds = new uint256[](1);
        itemIds[0] = amount;
        makerBid.itemIds = itemIds;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        makerBid.amounts = amounts;
        uint256[9] memory validationCodes = orderValidator.checkMakerBidOrderValidity(
            makerBid,
            new bytes(65),
            _EMPTY_MERKLE_TREE
        );
        assertEq(validationCodes[1], MAKER_ORDER_INVALID_STANDARD_SALE);
    }

    function testMakerBidMissingIsValidSignature() public {
        OrderStructs.MakerBid memory makerBid;
        // This contract does not have isValidSignature implemented
        makerBid.signer = address(this);
        makerBid.assetType = ASSET_TYPE_ERC721;
        makerBid.collection = address(new MockERC721());
        uint256[9] memory validationCodes = orderValidator.checkMakerBidOrderValidity(
            makerBid,
            new bytes(65),
            _EMPTY_MERKLE_TREE
        );
        assertEq(validationCodes[3], MISSING_IS_VALID_SIGNATURE_FUNCTION_EIP1271);
    }

    function testMakerAskWrongAssetTypeERC1155() public {
        OrderStructs.MakerAsk memory makerAsk;
        makerAsk.assetType = ASSET_TYPE_ERC1155;
        makerAsk.collection = address(new MockERC1155SupportsNoInterface());
        uint256[9] memory validationCodes = orderValidator.checkMakerAskOrderValidity(
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
        uint256[9] memory validationCodes = orderValidator.checkMakerBidOrderValidity(
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
        mockERC20.approve(address(orderValidator.looksRareProtocol()), makerBid.maxPrice - 1 wei);
        vm.stopPrank();

        uint256[9] memory validationCodes = orderValidator.checkMakerBidOrderValidity(
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

        uint256[9] memory validationCodes = orderValidator.checkMakerAskOrderValidity(
            makerAsk,
            new bytes(65),
            _EMPTY_MERKLE_TREE
        );
        assertEq(validationCodes[5], ERC721_ITEM_ID_NOT_IN_BALANCE);
    }

    function testMakerAskERC1155BalanceInferiorToAmountThroughBalanceOfBatch() public {
        _testMakerAskERC1155BalanceInferiorToAmount(true);
    }

    function testMakerAskERC1155BalanceInferiorToAmountThroughBalanceOf() public {
        _testMakerAskERC1155BalanceInferiorToAmount(false);
    }

    function _testMakerAskERC1155BalanceInferiorToAmount(bool revertBalanceOfBatch) public {
        address collection;
        if (revertBalanceOfBatch) {
            MockERC1155WithoutBalanceOfBatch mockERC1155 = new MockERC1155WithoutBalanceOfBatch();
            collection = address(mockERC1155);
        } else {
            MockERC1155 mockERC1155 = new MockERC1155();
            collection = address(mockERC1155);
        }

        OrderStructs.MakerAsk memory makerAsk;
        makerAsk.assetType = ASSET_TYPE_ERC1155;
        makerAsk.collection = collection;
        makerAsk.signer = makerUser;
        makerAsk.assetType = ASSET_TYPE_ERC1155;
        uint256[] memory itemIds = new uint256[](1);
        makerAsk.itemIds = itemIds;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;
        makerAsk.amounts = amounts;

        uint256[9] memory validationCodes = orderValidator.checkMakerAskOrderValidity(
            makerAsk,
            new bytes(65),
            _EMPTY_MERKLE_TREE
        );
        assertEq(validationCodes[5], ERC1155_BALANCE_OF_ITEM_ID_INFERIOR_TO_AMOUNT);
    }
}
