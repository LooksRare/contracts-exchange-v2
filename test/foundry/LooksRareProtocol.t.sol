// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {RoyaltyFeeRegistry} from "@looksrare/contracts-exchange-v1/contracts/royaltyFeeHelpers/RoyaltyFeeRegistry.sol";

import {LooksRareProtocol} from "../../contracts/LooksRareProtocol.sol";
import {TransferManager} from "../../contracts/TransferManager.sol";
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";

import {TestHelpers} from "./TestHelpers.sol";
import {MockERC721} from "./utils/MockERC721.sol";
import {WETH} from "@rari-capital/solmate/src/tokens/WETH.sol";

abstract contract TestParameters is TestHelpers {
    address internal _owner = address(42);
    address internal _collectionOwner = address(22);
    uint256 internal makerUserPK = 1;
    uint256 internal takerUserPK = 2;
    address internal makerUser = vm.addr(makerUserPK);
    address internal takerUser = vm.addr(takerUserPK);
}

contract ProtocolHelpers is TestParameters {
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
        makerAskOrder.amounts = itemIds;
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
        makerBidOrder.amounts = itemIds;
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
        makerAskOrder.amounts = itemIds;

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

contract LooksRareProtocolTest is ProtocolHelpers {
    using OrderStructs for OrderStructs.MultipleMakerAskOrders;
    using OrderStructs for OrderStructs.MultipleMakerBidOrders;

    address[] public operators;

    MockERC721 public mockERC721;
    RoyaltyFeeRegistry public royaltyFeeRegistry;
    LooksRareProtocol public looksRareProtocol;
    TransferManager public transferManager;
    WETH public weth;

    function _setUpUser(address user) internal asPrankedUser(user) {
        vm.deal(user, 100 ether);
        mockERC721.setApprovalForAll(address(transferManager), true);
        transferManager.grantApprovals(operators);
        weth.approve(address(looksRareProtocol), type(uint256).max);
        weth.deposit{value: 10 ether}();
    }

    function _setUpUsers() internal {
        _setUpUser(makerUser);
        _setUpUser(takerUser);
    }

    function setUp() public asPrankedUser(_owner) {
        royaltyFeeRegistry = new RoyaltyFeeRegistry(9500);
        transferManager = new TransferManager();
        looksRareProtocol = new LooksRareProtocol(address(transferManager), address(royaltyFeeRegistry));
        mockERC721 = new MockERC721();
        weth = new WETH();

        vm.deal(_owner, 100 ether);
        vm.deal(_collectionOwner, 100 ether);

        // Verify interfaceId of ERC-2981 is not supported
        assertFalse(mockERC721.supportsInterface(0x2a55205a));

        // Update registry info
        royaltyFeeRegistry.updateRoyaltyInfoForCollection(address(mockERC721), _collectionOwner, _collectionOwner, 100);

        (address recipient, uint256 amount) = royaltyFeeRegistry.royaltyInfo(address(mockERC721), 1 ether);
        assertEq(recipient, _collectionOwner);
        assertEq(amount, 1 ether / 100);

        // Operations
        transferManager.whitelistOperator(address(looksRareProtocol));
        looksRareProtocol.addCurrency(address(0));
        looksRareProtocol.addCurrency(address(weth));
        looksRareProtocol.setProtocolFeeRecipient(_owner);

        // Fetch domain separator
        (_domainSeparator, , , ) = looksRareProtocol.information();
        operators.push(address(looksRareProtocol));
    }

    function testInitialStates() public {
        (
            bytes32 initialDomainSeparator,
            uint256 initialChainId,
            bytes32 currentDomainSeparator,
            uint256 currentChainId
        ) = looksRareProtocol.information();

        bytes32 expectedDomainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("LooksRareProtocol"),
                keccak256(bytes("2")),
                block.chainid,
                address(looksRareProtocol)
            )
        );

        assertEq(initialDomainSeparator, expectedDomainSeparator);
        assertEq(initialChainId, block.chainid);
        assertEq(initialDomainSeparator, currentDomainSeparator);
        assertEq(initialChainId, currentChainId);
    }

    /**
     * One ERC721 is sold to buyer who uses an array of order to match (size = 1)
     */
    function testStandardPurchaseWithRoyaltiesArray() public {
        _setUpUsers();
        uint256 numberOrders = 1;

        OrderStructs.MultipleMakerAskOrders memory multiMakerAskOrders;
        OrderStructs.SingleMakerAskOrder[] memory makerAskOrders = new OrderStructs.SingleMakerAskOrder[](numberOrders);
        OrderStructs.TakerBidOrder memory takerBidOrder;
        uint256[] memory makerArraySlots = new uint256[](numberOrders);
        OrderStructs.MultipleTakerBidOrders memory multipleTakerBidOrders;
        OrderStructs.MultipleMakerAskOrders[] memory multipleMakerAskOrders = new OrderStructs.MultipleMakerAskOrders[](
            numberOrders
        );
        OrderStructs.TakerBidOrder[] memory takerBidOrders = new OrderStructs.TakerBidOrder[](numberOrders);

        // Maker user actions
        vm.startPrank(makerUser);

        for (uint256 i; i < numberOrders; i++) {
            mockERC721.mint(makerUser, i);
            OrderStructs.SingleMakerAskOrder memory makerAskOrder = _createSimpleMakerAskOrder(1 ether, i);
            makerAskOrders[i] = makerAskOrder;
            makerAskOrder.minNetRatio = 9700;
            makerAskOrder.orderNonce = uint112(i);
        }

        multiMakerAskOrders.baseMakerOrder.signer = makerUser;
        multiMakerAskOrders.baseMakerOrder.strategyId = 0;
        multiMakerAskOrders.baseMakerOrder.assetType = 0; // ERC721
        multiMakerAskOrders.baseMakerOrder.collection = address(mockERC721);
        multiMakerAskOrders.baseMakerOrder.currency = address(0);
        multiMakerAskOrders.makerAskOrders = makerAskOrders;
        multiMakerAskOrders.signature = _signMakerAsksOrder(multiMakerAskOrders, makerUserPK);
        vm.stopPrank();

        // Taker user actions
        vm.startPrank(takerUser);

        takerBidOrder = OrderStructs.TakerBidOrder(
            1 ether,
            takerUser,
            makerAskOrders[0].itemIds,
            makerAskOrders[0].amounts,
            abi.encode()
        );

        makerArraySlots[0] = 0;
        multipleMakerAskOrders[0] = multiMakerAskOrders;
        takerBidOrders[0] = takerBidOrder;
        multipleTakerBidOrders.takerBidOrders = takerBidOrders;

        looksRareProtocol.matchMultipleAsksWithTakerBids{value: 1 ether}(
            multipleTakerBidOrders,
            multipleMakerAskOrders,
            makerArraySlots,
            true
        );
        vm.stopPrank();

        assertEq(mockERC721.ownerOf(0), takerUser);
        assertEq(address(looksRareProtocol).balance, 0);
    }

    /**
     * One ERC721 is sold to buyer who buy 3 orders with 1 ERC721 per order
     */
    function testStandardPurchaseThreeItemsERC721WithRoyaltiesArray() public {
        _setUpUsers();
        uint256 numberOrders = 3;

        OrderStructs.MultipleMakerAskOrders memory multiMakerAskOrders;
        OrderStructs.SingleMakerAskOrder[] memory makerAskOrders = new OrderStructs.SingleMakerAskOrder[](numberOrders);
        uint256[] memory makerArraySlots = new uint256[](numberOrders);
        OrderStructs.MultipleTakerBidOrders memory multipleTakerBidOrders;
        OrderStructs.MultipleMakerAskOrders[] memory multipleMakerAskOrders = new OrderStructs.MultipleMakerAskOrders[](
            numberOrders
        );
        OrderStructs.TakerBidOrder[] memory takerBidOrders = new OrderStructs.TakerBidOrder[](numberOrders);

        // Maker user actions
        vm.startPrank(makerUser);

        for (uint256 i; i < numberOrders; i++) {
            mockERC721.mint(makerUser, i);
            OrderStructs.SingleMakerAskOrder memory makerAskOrder = _createSimpleMakerAskOrder((i + 1) * 1e18, i);
            makerAskOrders[i] = makerAskOrder;
            makerAskOrder.minNetRatio = 9700;
            makerAskOrder.orderNonce = uint112(i);
        }

        multiMakerAskOrders.baseMakerOrder.signer = makerUser;
        multiMakerAskOrders.baseMakerOrder.strategyId = 0;
        multiMakerAskOrders.baseMakerOrder.assetType = 0; // ERC721
        multiMakerAskOrders.baseMakerOrder.collection = address(mockERC721);
        multiMakerAskOrders.baseMakerOrder.currency = address(0);
        multiMakerAskOrders.makerAskOrders = makerAskOrders;
        multiMakerAskOrders.signature = _signMakerAsksOrder(multiMakerAskOrders, makerUserPK);
        vm.stopPrank();

        // Taker user actions
        vm.startPrank(takerUser);

        for (uint256 i; i < numberOrders; i++) {
            takerBidOrders[i] = OrderStructs.TakerBidOrder(
                (i + 1) * 1e18,
                takerUser,
                makerAskOrders[i].itemIds,
                makerAskOrders[i].amounts,
                abi.encode()
            );

            makerArraySlots[i] = i;
            multipleMakerAskOrders[i] = multiMakerAskOrders;
        }

        multipleTakerBidOrders.takerBidOrders = takerBidOrders;
        multipleTakerBidOrders.referrer = address(0);

        looksRareProtocol.matchMultipleAsksWithTakerBids{value: 6 ether}(
            multipleTakerBidOrders,
            multipleMakerAskOrders,
            makerArraySlots,
            true
        );

        vm.stopPrank();

        for (uint256 i; i < numberOrders; i++) {
            assertEq(mockERC721.ownerOf(i), takerUser);
        }
        assertEq(address(looksRareProtocol).balance, 0);
    }

    /**
     * One ERC721 is sold to buyer who uses no array to match (single-order match)
     */
    function testStandardPurchaseWithRoyaltiesNoArray() public {
        _setUpUsers();
        uint256 numberOrders = 1;

        OrderStructs.MultipleMakerAskOrders memory multiMakerAskOrders;
        OrderStructs.SingleMakerAskOrder[] memory makerAskOrders = new OrderStructs.SingleMakerAskOrder[](numberOrders);
        OrderStructs.TakerBidOrder memory takerBidOrder;
        OrderStructs.SingleTakerBidOrder memory singleTakerBidOrder;

        // Maker user actions
        vm.startPrank(makerUser);

        for (uint256 i; i < numberOrders; i++) {
            mockERC721.mint(makerUser, i);
            OrderStructs.SingleMakerAskOrder memory makerAskOrder = _createSimpleMakerAskOrder(1 ether, i);
            makerAskOrders[i] = makerAskOrder;
            makerAskOrder.minNetRatio = 9700;
            makerAskOrder.orderNonce = uint112(i);
        }

        multiMakerAskOrders.baseMakerOrder.signer = makerUser;
        multiMakerAskOrders.baseMakerOrder.strategyId = 0;
        multiMakerAskOrders.baseMakerOrder.assetType = 0; // ERC721
        multiMakerAskOrders.baseMakerOrder.collection = address(mockERC721);
        multiMakerAskOrders.baseMakerOrder.currency = address(0);
        multiMakerAskOrders.makerAskOrders = makerAskOrders;
        multiMakerAskOrders.signature = _signMakerAsksOrder(multiMakerAskOrders, makerUserPK);

        vm.stopPrank();

        // Taker user actions
        vm.startPrank(takerUser);

        takerBidOrder = OrderStructs.TakerBidOrder(
            1 ether,
            takerUser,
            makerAskOrders[0].itemIds,
            makerAskOrders[0].amounts,
            abi.encode()
        );

        uint256 makerArraySlot = 0;
        singleTakerBidOrder.takerBidOrder = takerBidOrder;
        singleTakerBidOrder.referrer = address(0);

        looksRareProtocol.matchAskWithTakerBid{value: 1 ether}(
            singleTakerBidOrder,
            multiMakerAskOrders,
            makerArraySlot
        );

        vm.stopPrank();

        assertEq(mockERC721.ownerOf(0), takerUser);
        assertEq(address(looksRareProtocol).balance, 0);
    }

    /**
     * One ERC721 is sold to buyer who uses no array to match (single-order match)
     */
    function testStandardSaleWithRoyaltiesNoArray() public {
        _setUpUsers();
        uint256 numberOrders = 1;

        OrderStructs.TakerAskOrder memory takerAskOrder;
        OrderStructs.MultipleMakerBidOrders memory multiMakerBidOrders;
        OrderStructs.SingleMakerBidOrder[] memory makerBidOrders = new OrderStructs.SingleMakerBidOrder[](numberOrders);
        OrderStructs.SingleTakerAskOrder memory singleTakerAskOrder;

        // Maker user actions
        vm.startPrank(takerUser);

        for (uint256 i; i < numberOrders; i++) {
            mockERC721.mint(takerUser, i);
            OrderStructs.SingleMakerBidOrder memory makerBidOrder = _createSimpleMakerBidOrder(1 ether, i);
            makerBidOrder.orderNonce = uint112(i);
            makerBidOrders[i] = makerBidOrder;
        }

        multiMakerBidOrders.baseMakerOrder.signer = makerUser;
        multiMakerBidOrders.baseMakerOrder.strategyId = 0;
        multiMakerBidOrders.baseMakerOrder.assetType = 0; // ERC721
        multiMakerBidOrders.baseMakerOrder.collection = address(mockERC721);
        multiMakerBidOrders.baseMakerOrder.currency = address(weth);
        multiMakerBidOrders.makerBidOrders = makerBidOrders;
        multiMakerBidOrders.signature = _signMakerBidsOrder(multiMakerBidOrders, makerUserPK);
        vm.stopPrank();

        // Taker user actions
        vm.startPrank(takerUser);

        takerAskOrder = OrderStructs.TakerAskOrder(
            takerUser,
            9700,
            1 ether,
            makerBidOrders[0].itemIds,
            makerBidOrders[0].amounts,
            abi.encode()
        );

        uint256 makerArraySlot = 0;
        singleTakerAskOrder.takerAskOrder = takerAskOrder;
        singleTakerAskOrder.referrer = address(0);

        looksRareProtocol.matchBidWithTakerAsk(singleTakerAskOrder, multiMakerBidOrders, makerArraySlot);

        vm.stopPrank();

        assertEq(mockERC721.ownerOf(0), makerUser);
        assertEq(weth.balanceOf(makerUser), 9 ether); // 10 - 1 = 9
        assertEq(address(looksRareProtocol).balance, 0);
    }

    /**
     * Three ERC721 tokens are sold to buyer who uses an array to match (multi-order match)
     */
    function testStandardSaleThreeItemsERC721WithRoyaltiesArray() public {
        _setUpUsers();
        uint256 numberOrders = 3;

        // Maker user actions
        vm.startPrank(takerUser);

        // Custom structs
        OrderStructs.MultipleMakerBidOrders memory multiMakerBidOrders;
        OrderStructs.MultipleMakerBidOrders[] memory multipleMakerBidOrders = new OrderStructs.MultipleMakerBidOrders[](
            numberOrders
        );
        uint256[] memory makerArraySlots = new uint256[](numberOrders);

        OrderStructs.MultipleTakerAskOrders memory multipleTakerAskOrders;
        OrderStructs.TakerAskOrder[] memory takerAskOrders = new OrderStructs.TakerAskOrder[](numberOrders);
        OrderStructs.SingleMakerBidOrder[] memory makerBidOrders = new OrderStructs.SingleMakerBidOrder[](numberOrders);

        for (uint256 i; i < numberOrders; i++) {
            mockERC721.mint(takerUser, i);
            OrderStructs.SingleMakerBidOrder memory makerBidOrder = _createSimpleMakerBidOrder((i + 1) * 1e18, i);
            makerBidOrder.orderNonce = uint112(i);
            makerBidOrders[i] = makerBidOrder;
        }

        multiMakerBidOrders.baseMakerOrder.signer = makerUser;
        multiMakerBidOrders.baseMakerOrder.strategyId = 0;
        multiMakerBidOrders.baseMakerOrder.assetType = 0; // ERC721
        multiMakerBidOrders.baseMakerOrder.collection = address(mockERC721);
        multiMakerBidOrders.baseMakerOrder.currency = address(weth);
        multiMakerBidOrders.makerBidOrders = makerBidOrders;

        multiMakerBidOrders.signature = _signMakerBidsOrder(multiMakerBidOrders, makerUserPK);
        vm.stopPrank();

        // Taker user actions
        vm.startPrank(takerUser);

        for (uint256 i; i < numberOrders; i++) {
            takerAskOrders[i] = OrderStructs.TakerAskOrder(
                takerUser,
                9700,
                (i + 1) * 1e18,
                makerBidOrders[i].itemIds,
                makerBidOrders[i].amounts,
                abi.encode()
            );

            makerArraySlots[i] = i;
            multipleMakerBidOrders[i] = multiMakerBidOrders;
        }

        multipleTakerAskOrders.takerAskOrders = takerAskOrders;
        multipleTakerAskOrders.currency = address(weth);
        multipleTakerAskOrders.referrer = address(0);

        looksRareProtocol.matchMultipleBidsWithTakerAsks(
            multipleTakerAskOrders,
            multipleMakerBidOrders,
            makerArraySlots,
            true
        );

        vm.stopPrank();

        for (uint256 i; i < numberOrders; i++) {
            assertEq(mockERC721.ownerOf(i), makerUser);
        }

        assertEq(address(looksRareProtocol).balance, 0);
        assertEq(weth.balanceOf(makerUser), 4 ether); // 10 - 6 = 4
    }

    /**
     * One ERC721 is sold to buyer who uses no array to match (single-order match) with collection discount
     */
    function testStandardSaleWithRoyaltiesAndCollectionDiscount() public {
        _setUpUsers();
        uint256 numberOrders = 1;
        uint256 discountFactor = 5000; // 50%

        OrderStructs.TakerAskOrder memory takerAskOrder;
        OrderStructs.MultipleMakerBidOrders memory multiMakerBidOrders;
        OrderStructs.SingleMakerBidOrder[] memory makerBidOrders = new OrderStructs.SingleMakerBidOrder[](numberOrders);
        OrderStructs.SingleTakerAskOrder memory singleTakerAskOrder;

        // 1. Owner user actions
        vm.startPrank(_owner);
        looksRareProtocol.adjustDiscountFactorCollection(address(mockERC721), discountFactor);
        vm.stopPrank();

        // 2. Maker user actions
        vm.startPrank(takerUser);

        for (uint256 i; i < numberOrders; i++) {
            mockERC721.mint(takerUser, i);
            OrderStructs.SingleMakerBidOrder memory makerBidOrder = _createSimpleMakerBidOrder(1 ether, i);
            makerBidOrder.orderNonce = uint112(i);
            makerBidOrders[i] = makerBidOrder;
        }

        multiMakerBidOrders.baseMakerOrder.signer = makerUser;
        multiMakerBidOrders.baseMakerOrder.strategyId = 0;
        multiMakerBidOrders.baseMakerOrder.assetType = 0; // ERC721
        multiMakerBidOrders.baseMakerOrder.collection = address(mockERC721);
        multiMakerBidOrders.baseMakerOrder.currency = address(weth);
        multiMakerBidOrders.makerBidOrders = makerBidOrders;
        multiMakerBidOrders.signature = _signMakerBidsOrder(multiMakerBidOrders, makerUserPK);
        vm.stopPrank();

        // 3. Taker user actions
        vm.startPrank(takerUser);

        takerAskOrder = OrderStructs.TakerAskOrder(
            takerUser,
            9800,
            1 ether,
            makerBidOrders[0].itemIds,
            makerBidOrders[0].amounts,
            abi.encode()
        );

        uint256 makerArraySlot = 0;
        singleTakerAskOrder.takerAskOrder = takerAskOrder;
        singleTakerAskOrder.referrer = address(0);

        looksRareProtocol.matchBidWithTakerAsk(singleTakerAskOrder, multiMakerBidOrders, makerArraySlot);

        vm.stopPrank();

        assertEq(mockERC721.ownerOf(0), makerUser);
        assertEq(weth.balanceOf(makerUser), 9 ether); // 10 - 1 = 9 ETH
        assertEq(weth.balanceOf(takerUser), 10.98 ether); // 10 + 1 * (100% - 1% royalty - 2/1% protocol fee)
        assertEq(address(looksRareProtocol).balance, 0);
    }
}
