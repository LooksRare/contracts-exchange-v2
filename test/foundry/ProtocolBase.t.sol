// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// WETH
import {WETH} from "solmate/src/tokens/WETH.sol";

// Libraries
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";

// Core contracts
import {LooksRareProtocol, ILooksRareProtocol} from "../../contracts/LooksRareProtocol.sol";
import {TransferManager} from "../../contracts/TransferManager.sol";

// Other contracts
import {CreatorFeeManagerWithRebates} from "../../contracts/CreatorFeeManagerWithRebates.sol";
import {OrderValidatorV2A} from "../../contracts/helpers/OrderValidatorV2A.sol";

// Mock files
import {MockERC20} from "../mock/MockERC20.sol";
import {MockERC721} from "../mock/MockERC721.sol";
import {MockERC721WithRoyalties} from "../mock/MockERC721WithRoyalties.sol";
import {MockERC1155} from "../mock/MockERC1155.sol";
import {MockRoyaltyFeeRegistry} from "../mock/MockRoyaltyFeeRegistry.sol";

// Utils
import {MockOrderGenerator} from "./utils/MockOrderGenerator.sol";

contract ProtocolBase is MockOrderGenerator, ILooksRareProtocol {
    address[] public operators;

    MockERC20 public looksRareToken;
    MockERC721WithRoyalties public mockERC721WithRoyalties;
    MockERC721 public mockERC721;
    MockERC1155 public mockERC1155;

    LooksRareProtocol public looksRareProtocol;
    TransferManager public transferManager;
    MockRoyaltyFeeRegistry public royaltyFeeRegistry;
    CreatorFeeManagerWithRebates public creatorFeeManager;
    OrderValidatorV2A public orderValidator;

    WETH public weth;

    function _assertValidMakerAskOrder(OrderStructs.MakerAsk memory makerAsk, bytes memory signature) internal {
        _assertValidMakerAskOrder(makerAsk, signature, _EMPTY_MERKLE_TREE);
    }

    function _assertValidMakerAskOrderWithMerkleTree(
        OrderStructs.MakerAsk memory makerAsk,
        bytes memory signature,
        OrderStructs.MerkleTree memory merkleTree
    ) internal {
        _assertValidMakerAskOrder(makerAsk, signature, merkleTree);
    }

    function _assertValidMakerAskOrder(
        OrderStructs.MakerAsk memory makerAsk,
        bytes memory signature,
        OrderStructs.MerkleTree memory merkleTree
    ) private {
        OrderStructs.MakerAsk[] memory makerAsks = new OrderStructs.MakerAsk[](1);
        makerAsks[0] = makerAsk;

        bytes[] memory signatures = new bytes[](1);
        signatures[0] = signature;

        OrderStructs.MerkleTree[] memory merkleTrees = new OrderStructs.MerkleTree[](1);
        merkleTrees[0] = merkleTree;

        uint256[9][] memory validationCodes = orderValidator.checkMultipleMakerAskOrdersValidity(
            makerAsks,
            signatures,
            merkleTrees
        );

        _assertValidationCodesAllZeroes(validationCodes);
    }

    function _doesMakerAskOrderReturnValidationCode(
        OrderStructs.MakerAsk memory makerAsk,
        bytes memory signature,
        uint256 expectedValidationCode
    ) internal {
        _doesMakerAskOrderReturnValidationCode(makerAsk, signature, _EMPTY_MERKLE_TREE, expectedValidationCode);
    }

    function _doesMakerAskOrderReturnValidationCodeWithMerkleTree(
        OrderStructs.MakerAsk memory makerAsk,
        bytes memory signature,
        OrderStructs.MerkleTree memory merkleTree,
        uint256 expectedValidationCode
    ) internal {
        _doesMakerAskOrderReturnValidationCode(makerAsk, signature, merkleTree, expectedValidationCode);
    }

    function _doesMakerAskOrderReturnValidationCode(
        OrderStructs.MakerAsk memory makerAsk,
        bytes memory signature,
        OrderStructs.MerkleTree memory merkleTree,
        uint256 expectedValidationCode
    ) private {
        OrderStructs.MakerAsk[] memory makerAsks = new OrderStructs.MakerAsk[](1);
        makerAsks[0] = makerAsk;

        bytes[] memory signatures = new bytes[](1);
        signatures[0] = signature;

        OrderStructs.MerkleTree[] memory merkleTrees = new OrderStructs.MerkleTree[](1);
        merkleTrees[0] = merkleTree;

        uint256[9][] memory validationCodes = orderValidator.checkMultipleMakerAskOrdersValidity(
            makerAsks,
            signatures,
            merkleTrees
        );

        uint256 index = expectedValidationCode / 100;
        assertEq(validationCodes[0][index - 1], expectedValidationCode);
    }

    function _assertValidMakerBidOrder(OrderStructs.MakerBid memory makerBid, bytes memory signature) internal {
        _assertValidMakerBidOrder(makerBid, signature, _EMPTY_MERKLE_TREE);
    }

    function _assertValidMakerBidOrderWithMerkleTree(
        OrderStructs.MakerBid memory makerBid,
        bytes memory signature,
        OrderStructs.MerkleTree memory merkleTree
    ) internal {
        _assertValidMakerBidOrder(makerBid, signature, merkleTree);
    }

    function _assertValidMakerBidOrder(
        OrderStructs.MakerBid memory makerBid,
        bytes memory signature,
        OrderStructs.MerkleTree memory merkleTree
    ) private {
        OrderStructs.MakerBid[] memory makerBids = new OrderStructs.MakerBid[](1);
        makerBids[0] = makerBid;

        bytes[] memory signatures = new bytes[](1);
        signatures[0] = signature;

        OrderStructs.MerkleTree[] memory merkleTrees = new OrderStructs.MerkleTree[](1);
        merkleTrees[0] = merkleTree;

        uint256[9][] memory validationCodes = orderValidator.checkMultipleMakerBidOrdersValidity(
            makerBids,
            signatures,
            merkleTrees
        );

        _assertValidationCodesAllZeroes(validationCodes);
    }

    function _doesMakerBidOrderReturnValidationCode(
        OrderStructs.MakerBid memory makerBid,
        bytes memory signature,
        uint256 expectedValidationCode
    ) internal {
        _doesMakerBidOrderReturnValidationCode(makerBid, signature, _EMPTY_MERKLE_TREE, expectedValidationCode);
    }

    function _doesMakerBidOrderReturnValidationCodeWithMerkleTree(
        OrderStructs.MakerBid memory makerBid,
        bytes memory signature,
        OrderStructs.MerkleTree memory merkleTree,
        uint256 expectedValidationCode
    ) internal {
        _doesMakerBidOrderReturnValidationCode(makerBid, signature, merkleTree, expectedValidationCode);
    }

    function _doesMakerBidOrderReturnValidationCode(
        OrderStructs.MakerBid memory makerBid,
        bytes memory signature,
        OrderStructs.MerkleTree memory merkleTree,
        uint256 expectedValidationCode
    ) private {
        OrderStructs.MakerBid[] memory makerBids = new OrderStructs.MakerBid[](1);
        makerBids[0] = makerBid;

        bytes[] memory signatures = new bytes[](1);
        signatures[0] = signature;

        OrderStructs.MerkleTree[] memory merkleTrees = new OrderStructs.MerkleTree[](1);
        merkleTrees[0] = merkleTree;

        uint256[9][] memory validationCodes = orderValidator.checkMultipleMakerBidOrdersValidity(
            makerBids,
            signatures,
            merkleTrees
        );

        uint256 index = expectedValidationCode / 100;
        assertEq(validationCodes[0][index - 1], expectedValidationCode);
    }

    function _assertValidationCodesAllZeroes(uint256[9][] memory validationCodes) private {
        for (uint256 i; i < validationCodes.length; i++) {
            for (uint256 j; j < 9; j++) {
                assertEq(validationCodes[i][j], 0);
            }
        }
    }

    function _setUpUser(address user) internal asPrankedUser(user) {
        // Do approvals for collections and WETH
        mockERC721.setApprovalForAll(address(transferManager), true);
        mockERC1155.setApprovalForAll(address(transferManager), true);
        mockERC721WithRoyalties.setApprovalForAll(address(transferManager), true);
        weth.approve(address(looksRareProtocol), type(uint256).max);

        // Grant approvals for transfer manager
        transferManager.grantApprovals(operators);

        // Receive ETH and WETH
        vm.deal(user, _initialETHBalanceUser + _initialWETHBalanceUser);
        weth.deposit{value: _initialWETHBalanceUser}();
    }

    function _setUpUsers() internal {
        _setUpUser(makerUser);
        _setUpUser(takerUser);
    }

    function _setupRegistryRoyalties(address collection, uint256 standardRoyaltyFee) internal {
        vm.prank(royaltyFeeRegistry.owner());
        royaltyFeeRegistry.updateRoyaltyInfoForCollection(
            collection,
            _royaltyRecipient,
            _royaltyRecipient,
            standardRoyaltyFee
        );
    }

    function _setUp() internal {
        vm.startPrank(_owner);
        weth = new WETH();
        looksRareToken = new MockERC20();
        mockERC721 = new MockERC721();
        mockERC1155 = new MockERC1155();

        transferManager = new TransferManager(_owner);
        royaltyFeeRegistry = new MockRoyaltyFeeRegistry(_owner, 9500);
        creatorFeeManager = new CreatorFeeManagerWithRebates(address(royaltyFeeRegistry));
        looksRareProtocol = new LooksRareProtocol(_owner, _owner, address(transferManager), address(weth));
        mockERC721WithRoyalties = new MockERC721WithRoyalties(_royaltyRecipient, _standardRoyaltyFee);

        // Operations
        transferManager.allowOperator(address(looksRareProtocol));
        looksRareProtocol.updateCurrencyStatus(ETH, true);
        looksRareProtocol.updateCurrencyStatus(address(weth), true);
        looksRareProtocol.updateCreatorFeeManager(address(creatorFeeManager));

        // Fetch domain separator and store it as one of the operators
        _domainSeparator = looksRareProtocol.domainSeparator();
        operators.push(address(looksRareProtocol));

        // Deploy order validator contract
        orderValidator = new OrderValidatorV2A(address(looksRareProtocol));

        // Distribute ETH and WETH to protocol owner
        vm.deal(_owner, _initialETHBalanceOwner + _initialWETHBalanceOwner);
        weth.deposit{value: _initialWETHBalanceOwner}();
        vm.stopPrank();

        // Distribute ETH and WETH to royalty recipient
        vm.deal(_royaltyRecipient, _initialETHBalanceRoyaltyRecipient + _initialWETHBalanceRoyaltyRecipient);
        vm.startPrank(_royaltyRecipient);
        weth.deposit{value: _initialWETHBalanceRoyaltyRecipient}();
        vm.stopPrank();
    }

    /**
     * NOTE: It inherits from ILooksRareProtocol, so it
     *       needs to at least define the functions below.
     */
    function executeTakerAsk(
        OrderStructs.Taker calldata takerAsk,
        OrderStructs.MakerBid calldata makerBid,
        bytes calldata makerSignature,
        OrderStructs.MerkleTree calldata merkleTree,
        address affiliate
    ) external {}

    function executeTakerBid(
        OrderStructs.Taker calldata takerBid,
        OrderStructs.MakerAsk calldata makerAsk,
        bytes calldata makerSignature,
        OrderStructs.MerkleTree calldata merkleTree,
        address affiliate
    ) external payable {}

    function executeMultipleTakerBids(
        OrderStructs.Taker[] calldata takerBids,
        OrderStructs.MakerAsk[] calldata makerAsks,
        bytes[] calldata makerSignatures,
        OrderStructs.MerkleTree[] calldata merkleTrees,
        address affiliate,
        bool isAtomic
    ) external payable {}
}
