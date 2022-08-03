// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {RoyaltyFeeRegistry} from "@looksrare/contracts-exchange-v1/contracts/royaltyFeeHelpers/RoyaltyFeeRegistry.sol";

import {LooksRareProtocol} from "../../contracts/LooksRareProtocol.sol";
import {TransferManager} from "../../contracts/TransferManager.sol";
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";

import {TestHelpers} from "./TestHelpers.sol";
import {MockERC721} from "./utils/MockERC721.sol";

abstract contract TestParameters is TestHelpers {
    address internal _owner = address(42);
    address internal _collectionOwner = address(22);
    uint256 internal makerUserPK = 1;
    uint256 internal takerUserPK = 2;
    address internal makerUser = vm.addr(makerUserPK);
    address internal takerUser = vm.addr(takerUserPK);
}

contract LooksRareProtocolTest is TestParameters {
    using OrderStructs for OrderStructs.MultipleMakerAskOrders;

    bytes32 internal _domainSeparator;
    address[] public operators;

    MockERC721 public mockERC721;
    RoyaltyFeeRegistry public royaltyFeeRegistry;
    LooksRareProtocol public looksRareProtocol;
    TransferManager public transferManager;

    receive() external payable {}

    function _createSimpleMakerAskOrder(uint256 price, uint256 itemId)
        internal
        pure
        returns (OrderStructs.SingleMakerAskOrder memory makerAskOrder)
    {
        makerAskOrder.minPrice = price;

        uint256[] memory itemIds = new uint256[](1);
        itemIds[0] = itemId;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        makerAskOrder.itemIds = itemIds;
        makerAskOrder.amounts = itemIds;

        return makerAskOrder;
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

    function _setUpApprovals(address[] memory users) internal {
        for (uint256 i; i < users.length; i++) {
            vm.startPrank(users[i]);
            mockERC721.setApprovalForAll(address(transferManager), true);
            transferManager.grantApprovals(operators);
            vm.stopPrank();
        }
    }

    function _setUpUsers() internal {
        address[] memory _users = new address[](2);
        _users[0] = makerUser;
        _users[1] = takerUser;
        _setUpApprovals(_users);
    }

    function setUp() public asPrankedUser(_owner) {
        royaltyFeeRegistry = new RoyaltyFeeRegistry(9500);
        transferManager = new TransferManager();
        looksRareProtocol = new LooksRareProtocol(address(transferManager), address(royaltyFeeRegistry));
        mockERC721 = new MockERC721();

        // Update registry info
        royaltyFeeRegistry.updateRoyaltyInfoForCollection(address(mockERC721), _collectionOwner, _collectionOwner, 100);

        (address recipient, uint256 amount) = royaltyFeeRegistry.royaltyInfo(address(mockERC721), 1 ether);
        assertEq(recipient, _collectionOwner);
        assertEq(amount, 1 ether / 100);
        assertTrue(mockERC721.supportsInterface(0x2a55205a));

        // Operations
        transferManager.whitelistOperator(address(looksRareProtocol));
        looksRareProtocol.addCurrency(address(0));
        looksRareProtocol.setProtocolFeeRecipient(_owner);

        // Fetch domain separator
        (_domainSeparator, , , ) = looksRareProtocol.information();
        operators.push(address(looksRareProtocol));

        vm.deal(makerUser, 100 ether);
        vm.deal(takerUser, 100 ether);
        vm.deal(_owner, 100 ether);
        vm.deal(_collectionOwner, 100 ether);
    }

    function testStandardSaleWithRoyaltiesArray() public {
        _setUpUsers();
        uint256 numberOrders = 1;

        // Maker user actions
        vm.startPrank(makerUser);

        OrderStructs.MultipleMakerAskOrders memory multiMakerAskOrders;
        multiMakerAskOrders.baseMakerOrder.signer = makerUser;
        OrderStructs.SingleMakerAskOrder[] memory makerAskOrders = new OrderStructs.SingleMakerAskOrder[](numberOrders);

        for (uint256 i; i < numberOrders; i++) {
            mockERC721.mint(makerUser, i);
            OrderStructs.SingleMakerAskOrder memory makerAskOrder = _createSimpleMakerAskOrder(1 ether, i);
            makerAskOrders[i] = makerAskOrder;
            makerAskOrder.minNetRatio = 9700;
        }

        multiMakerAskOrders.baseMakerOrder.strategyId = 0;
        multiMakerAskOrders.baseMakerOrder.assetType = 0; // ERC721
        multiMakerAskOrders.baseMakerOrder.collection = address(mockERC721);
        multiMakerAskOrders.baseMakerOrder.currency = address(0);
        multiMakerAskOrders.makerAskOrders = makerAskOrders;

        multiMakerAskOrders.signature = _signMakerAsksOrder(multiMakerAskOrders, makerUserPK);
        vm.stopPrank();

        // Taker user actions
        vm.startPrank(takerUser);

        OrderStructs.TakerBidOrder memory takerBidOrder;
        takerBidOrder = OrderStructs.TakerBidOrder(
            1 ether,
            takerUser,
            makerAskOrders[0].itemIds,
            makerAskOrders[0].amounts,
            abi.encode()
        );

        uint256[] memory makerArraySlots = new uint256[](1);
        OrderStructs.MultipleTakerBidOrders memory multipleTakerBidOrders;
        OrderStructs.MultipleMakerAskOrders[] memory multipleMakerAskOrders = new OrderStructs.MultipleMakerAskOrders[](
            1
        );

        makerArraySlots[0] = 0;
        multipleMakerAskOrders[0] = multiMakerAskOrders;

        OrderStructs.TakerBidOrder[] memory takerBidOrders = new OrderStructs.TakerBidOrder[](1);
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

    function testStandardSaleWithRoyaltiesNoArray() public {
        _setUpUsers();
        uint256 numberOrders = 1;

        // Maker user actions
        vm.startPrank(makerUser);

        OrderStructs.MultipleMakerAskOrders memory multiMakerAskOrders;
        multiMakerAskOrders.baseMakerOrder.signer = makerUser;
        OrderStructs.SingleMakerAskOrder[] memory makerAskOrders = new OrderStructs.SingleMakerAskOrder[](numberOrders);

        for (uint256 i; i < numberOrders; i++) {
            mockERC721.mint(makerUser, i);
            OrderStructs.SingleMakerAskOrder memory makerAskOrder = _createSimpleMakerAskOrder(1 ether, i);
            makerAskOrders[i] = makerAskOrder;
            makerAskOrder.minNetRatio = 9700;
        }

        multiMakerAskOrders.baseMakerOrder.strategyId = 0;
        multiMakerAskOrders.baseMakerOrder.assetType = 0; // ERC721
        multiMakerAskOrders.baseMakerOrder.collection = address(mockERC721);
        multiMakerAskOrders.baseMakerOrder.currency = address(0);
        multiMakerAskOrders.makerAskOrders = makerAskOrders;

        multiMakerAskOrders.signature = _signMakerAsksOrder(multiMakerAskOrders, makerUserPK);
        vm.stopPrank();

        // Taker user actions
        vm.startPrank(takerUser);

        OrderStructs.TakerBidOrder memory takerBidOrder;
        takerBidOrder = OrderStructs.TakerBidOrder(
            1 ether,
            takerUser,
            makerAskOrders[0].itemIds,
            makerAskOrders[0].amounts,
            abi.encode()
        );

        uint256 makerArraySlot = 0;

        OrderStructs.SingleTakerBidOrder memory singleTakerBidOrder;
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
}
