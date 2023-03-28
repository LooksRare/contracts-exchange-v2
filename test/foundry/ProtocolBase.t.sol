// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// WETH
import {WETH} from "solmate/src/tokens/WETH.sol";

// Libraries
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";

// Enums
import {QuoteType} from "../../contracts/enums/QuoteType.sol";
import {CollectionType} from "../../contracts/enums/CollectionType.sol";

// Core contracts
import {LooksRareProtocol, ILooksRareProtocol} from "../../contracts/LooksRareProtocol.sol";
import {TransferManager} from "../../contracts/TransferManager.sol";

// Other contracts
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
    OrderValidatorV2A public orderValidator;

    WETH public weth;

    function _assertMakerOrderReturnValidationCode(
        OrderStructs.Maker memory makerOrder,
        bytes memory signature,
        uint256 expectedValidationCode
    ) internal {
        _assertMakerOrderReturnValidationCode(makerOrder, signature, _EMPTY_MERKLE_TREE, expectedValidationCode);
    }

    function _assertMakerOrderReturnValidationCodeWithMerkleTree(
        OrderStructs.Maker memory makerOrder,
        bytes memory signature,
        OrderStructs.MerkleTree memory merkleTree,
        uint256 expectedValidationCode
    ) internal {
        _assertMakerOrderReturnValidationCode(makerOrder, signature, merkleTree, expectedValidationCode);
    }

    function _assertMakerOrderReturnValidationCode(
        OrderStructs.Maker memory makerOrder,
        bytes memory signature,
        OrderStructs.MerkleTree memory merkleTree,
        uint256 expectedValidationCode
    ) private {
        OrderStructs.Maker[] memory makerOrders = new OrderStructs.Maker[](1);
        makerOrders[0] = makerOrder;

        bytes[] memory signatures = new bytes[](1);
        signatures[0] = signature;

        OrderStructs.MerkleTree[] memory merkleTrees = new OrderStructs.MerkleTree[](1);
        merkleTrees[0] = merkleTree;

        uint256[9][] memory validationCodes = orderValidator.checkMultipleMakerOrderValidities(
            makerOrders,
            signatures,
            merkleTrees
        );

        uint256 index = expectedValidationCode / 100;
        assertEq(validationCodes[0][index - 1], expectedValidationCode);
    }

    function _assertValidMakerOrder(OrderStructs.Maker memory makerOrder, bytes memory signature) internal {
        _assertValidMakerOrder(makerOrder, signature, _EMPTY_MERKLE_TREE);
    }

    function _assertValidMakerOrderWithMerkleTree(
        OrderStructs.Maker memory makerOrder,
        bytes memory signature,
        OrderStructs.MerkleTree memory merkleTree
    ) internal {
        _assertValidMakerOrder(makerOrder, signature, merkleTree);
    }

    function _assertValidMakerOrder(
        OrderStructs.Maker memory makerOrder,
        bytes memory signature,
        OrderStructs.MerkleTree memory merkleTree
    ) private {
        OrderStructs.Maker[] memory makerOrders = new OrderStructs.Maker[](1);
        makerOrders[0] = makerOrder;

        bytes[] memory signatures = new bytes[](1);
        signatures[0] = signature;

        OrderStructs.MerkleTree[] memory merkleTrees = new OrderStructs.MerkleTree[](1);
        merkleTrees[0] = merkleTree;

        uint256[9][] memory validationCodes = orderValidator.checkMultipleMakerOrderValidities(
            makerOrders,
            signatures,
            merkleTrees
        );

        _assertValidationCodesAllZeroes(validationCodes);
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
        looksRareProtocol = new LooksRareProtocol(_owner, _owner, address(transferManager), address(weth));
        mockERC721WithRoyalties = new MockERC721WithRoyalties(_royaltyRecipient, _standardRoyaltyFee);

        // Operations
        transferManager.allowOperator(address(looksRareProtocol));
        looksRareProtocol.updateCurrencyStatus(ETH, true);
        looksRareProtocol.updateCurrencyStatus(address(weth), true);

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

    function _genericTakerOrder() internal pure returns (OrderStructs.Taker memory takerOrder) {
        takerOrder = OrderStructs.Taker(takerUser, abi.encode());
    }

    function _batchERC721ExecutionSetUp(
        uint256 price,
        uint256 numberOfPurhcases,
        QuoteType quoteType
    ) internal returns (BatchExecutionParameters[] memory batchExecutionParameters) {
        batchExecutionParameters = new BatchExecutionParameters[](numberOfPurhcases);
        address currency;

        for (uint256 i; i < numberOfPurhcases; i++) {
            // Mint asset
            if (quoteType == QuoteType.Bid) {
                mockERC721.mint(takerUser, i);
                currency = address(weth);
            } else if (quoteType == QuoteType.Ask) {
                mockERC721.mint(makerUser, i);
            }

            batchExecutionParameters[i].maker = _createSingleItemMakerOrder({
                quoteType: quoteType,
                globalNonce: 0,
                subsetNonce: 0,
                strategyId: STANDARD_SALE_FOR_FIXED_PRICE_STRATEGY,
                collectionType: CollectionType.ERC721,
                orderNonce: i,
                collection: address(mockERC721),
                currency: currency,
                signer: makerUser,
                price: price,
                itemId: i // (0, 1, etc.)
            });

            // Sign order
            batchExecutionParameters[i].makerSignature = _signMakerOrder(
                batchExecutionParameters[i].maker,
                makerUserPK
            );
            batchExecutionParameters[i].taker = _genericTakerOrder();

            _assertValidMakerOrder(batchExecutionParameters[i].maker, batchExecutionParameters[i].makerSignature);
        }
    }

    function _addStrategy(address strategy, bytes4 selector, bool isMakerBid) internal {
        looksRareProtocol.addStrategy(
            _standardProtocolFeeBp,
            _minTotalFeeBp,
            _maxProtocolFeeBp,
            selector,
            isMakerBid,
            strategy
        );
    }

    function _assertStrategyAttributes(
        address expectedStrategyAddress,
        bytes4 expectedSelector,
        bool expectedIsMakerBid
    ) internal {
        (
            bool strategyIsActive,
            uint16 strategyStandardProtocolFee,
            uint16 strategyMinTotalFee,
            uint16 strategyMaxProtocolFee,
            bytes4 strategySelector,
            bool strategyIsMakerBid,
            address strategyImplementation
        ) = looksRareProtocol.strategyInfo(1);

        assertTrue(strategyIsActive);
        assertEq(strategyStandardProtocolFee, _standardProtocolFeeBp);
        assertEq(strategyMinTotalFee, _minTotalFeeBp);
        assertEq(strategyMaxProtocolFee, _maxProtocolFeeBp);
        assertEq(strategySelector, expectedSelector);
        assertEq(strategyIsMakerBid, expectedIsMakerBid);
        assertEq(strategyImplementation, expectedStrategyAddress);
    }

    function _assertMockERC721Ownership(uint256[] memory itemIds, address owner) internal {
        for (uint256 i; i < itemIds.length; i++) {
            assertEq(mockERC721.ownerOf(itemIds[i]), owner);
        }
    }

    string private constant BUYER_COST_MISMATCH_ERROR = "Buyer should pay for the whole price";

    function _assertBuyerPaidETH(address buyer, uint256 totalValue) internal {
        assertEq(buyer.balance, _initialETHBalanceUser - totalValue, BUYER_COST_MISMATCH_ERROR);
    }

    function _assertBuyerPaidWETH(address buyer, uint256 totalValue) internal {
        assertEq(weth.balanceOf(buyer), _initialWETHBalanceUser - totalValue, BUYER_COST_MISMATCH_ERROR);
    }

    string private constant SELLER_PROCEED_MISMATCH_ERROR =
        "Seller should receive 99.5% of the whole price (0.5% protocol)";

    function _assertSellerReceivedWETHAfterStandardProtocolFee(address seller, uint256 totalValue) internal {
        assertEq(
            weth.balanceOf(seller),
            _initialWETHBalanceUser + (totalValue * _sellerProceedBpWithStandardProtocolFeeBp) / 10_000,
            SELLER_PROCEED_MISMATCH_ERROR
        );
    }

    function _assertSellerReceivedETHAfterStandardProtocolFee(address seller, uint256 totalValue) internal {
        assertEq(
            seller.balance,
            _initialETHBalanceUser + (totalValue * _sellerProceedBpWithStandardProtocolFeeBp) / 10_000,
            SELLER_PROCEED_MISMATCH_ERROR
        );
    }

    function _boolFlagsArray() internal pure returns (bool[2] memory flags) {
        flags[0] = true;
    }

    function _assertTakerBidEvent(
        OrderStructs.Maker memory makerAsk,
        address[2] memory expectedRecipients,
        uint256[3] memory expectedFees
    ) internal {
        vm.expectEmit({checkTopic1: true, checkTopic2: false, checkTopic3: false, checkData: true});
        emit TakerBid(
            NonceInvalidationParameters({
                orderHash: _computeOrderHash(makerAsk),
                orderNonce: makerAsk.orderNonce,
                isNonceInvalidated: true
            }),
            takerUser,
            takerUser,
            makerAsk.strategyId,
            makerAsk.currency,
            makerAsk.collection,
            makerAsk.itemIds,
            makerAsk.amounts,
            expectedRecipients,
            expectedFees
        );
    }

    function _assertTakerAskEvent(
        OrderStructs.Maker memory makerBid,
        address[2] memory expectedRecipients,
        uint256[3] memory expectedFees
    ) internal {
        vm.expectEmit({checkTopic1: true, checkTopic2: false, checkTopic3: false, checkData: true});
        emit TakerAsk(
            NonceInvalidationParameters({
                orderHash: _computeOrderHash(makerBid),
                orderNonce: makerBid.orderNonce,
                isNonceInvalidated: true
            }),
            takerUser,
            makerUser,
            makerBid.strategyId,
            makerBid.currency,
            makerBid.collection,
            makerBid.itemIds,
            makerBid.amounts,
            expectedRecipients,
            expectedFees
        );
    }

    /**
     * NOTE: It inherits from ILooksRareProtocol, so it
     *       needs to at least define the functions below.
     */
    function executeTakerAsk(
        OrderStructs.Taker calldata takerAsk,
        OrderStructs.Maker calldata makerBid,
        bytes calldata makerSignature,
        OrderStructs.MerkleTree calldata merkleTree,
        address affiliate
    ) external {}

    function executeTakerBid(
        OrderStructs.Taker calldata takerBid,
        OrderStructs.Maker calldata makerAsk,
        bytes calldata makerSignature,
        OrderStructs.MerkleTree calldata merkleTree,
        address affiliate
    ) external payable {}

    function executeMultipleTakerBids(
        BatchExecutionParameters[] calldata batchExecutionParameters,
        address affiliate,
        bool isAtomic
    ) external payable {}

    function executeMultipleTakerAsks(
        BatchExecutionParameters[] calldata batchExecutionParameters,
        address affiliate,
        bool isAtomic
    ) external {}
}
