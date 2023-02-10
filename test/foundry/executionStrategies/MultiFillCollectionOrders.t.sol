// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Libraries
import {OrderStructs} from "../../../contracts/libraries/OrderStructs.sol";

// Interfaces
import {IExecutionManager} from "../../../contracts/interfaces/IExecutionManager.sol";
import {IStrategyManager} from "../../../contracts/interfaces/IStrategyManager.sol";

// Mock files and other tests
import {StrategyTestMultiFillCollectionOrder} from "../utils/StrategyTestMultiFillCollectionOrder.sol";
import {ProtocolBase} from "../ProtocolBase.t.sol";

// Constants
import {ONE_HUNDRED_PERCENT_IN_BP} from "../../../contracts/constants/NumericConstants.sol";

// Enums
import {AssetType} from "../../../contracts/enums/AssetType.sol";
import {QuoteType} from "../../../contracts/enums/QuoteType.sol";

contract MultiFillCollectionOrdersTest is ProtocolBase, IStrategyManager {
    uint256 private constant price = 1 ether; // Fixed price of sale

    bytes4 public selector = StrategyTestMultiFillCollectionOrder.executeStrategyWithTakerAsk.selector;

    StrategyTestMultiFillCollectionOrder public strategyMultiFillCollectionOrder;

    function setUp() public {
        _setUp();
    }

    function _setUpNewStrategy() private asPrankedUser(_owner) {
        strategyMultiFillCollectionOrder = new StrategyTestMultiFillCollectionOrder(address(looksRareProtocol));
        _addStrategy(address(strategyMultiFillCollectionOrder), selector, true);
    }

    function testNewStrategy() public {
        _setUpNewStrategy();
        _assertStrategyAttributes(address(strategyMultiFillCollectionOrder), selector, true);
    }

    /**
     * Maker bid user wants to buy 4 ERC721 items in a collection. The order can be filled in multiple parts.
     * First takerUser sells 1 item.
     * Second takerUser sells 3 items.
     */
    function testMultiFill() public {
        _setUpUsers();
        _setUpNewStrategy();

        uint256 amountsToFill = 4;

        uint256[] memory itemIds = new uint256[](0);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amountsToFill;

        // Prepare the order hash
        OrderStructs.Maker memory makerBid = _createMultiItemMakerOrder({
            quoteType: QuoteType.Bid,
            globalNonce: 0,
            subsetNonce: 0,
            strategyId: 1, // Multi-fill bid offer
            assetType: AssetType.ERC721,
            orderNonce: 0,
            collection: address(mockERC721),
            currency: address(weth),
            signer: makerUser,
            price: price,
            itemIds: itemIds,
            amounts: amounts
        });

        // Sign order
        bytes memory signature = _signMakerOrder(makerBid, makerUserPK);

        itemIds = new uint256[](1);
        amounts = new uint256[](1);
        itemIds[0] = 0;
        amounts[0] = 1;

        mockERC721.mint(takerUser, itemIds[0]);

        // Prepare the taker ask
        OrderStructs.Taker memory takerAsk = OrderStructs.Taker(takerUser, abi.encode(itemIds, amounts));

        // Execute the first taker ask transaction by the first taker user
        vm.prank(takerUser);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(0), makerUser);
        // Maker bid user pays the whole price
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser - price);
        // Taker ask user receives 98% of the whole price (2% protocol)
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser + (price * 9_800) / ONE_HUNDRED_PERCENT_IN_BP);
        // Verify the nonce is not marked as executed
        assertEq(looksRareProtocol.userOrderNonce(makerUser, makerBid.orderNonce), _computeOrderHash(makerBid));

        // Second taker user actions
        address secondTakerUser = address(420);
        _setUpUser(secondTakerUser);

        itemIds = new uint256[](3);
        amounts = new uint256[](3);

        itemIds[0] = 1; // tokenId = 1
        itemIds[1] = 2; // tokenId = 2
        itemIds[2] = 3; // tokenId = 3
        amounts[0] = 1;
        amounts[1] = 1;
        amounts[2] = 1;

        mockERC721.batchMint(secondTakerUser, itemIds);

        // Prepare the taker ask
        takerAsk = OrderStructs.Taker(secondTakerUser, abi.encode(itemIds, amounts));

        // Execute a second taker ask transaction from the second taker user
        vm.prank(secondTakerUser);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);

        // Taker user has received the 3 assets
        assertEq(mockERC721.ownerOf(1), makerUser);
        assertEq(mockERC721.ownerOf(2), makerUser);
        assertEq(mockERC721.ownerOf(3), makerUser);

        // Maker bid user pays the whole price
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser - 4 * price);
        // Taker ask user receives 98% of the whole price (2% protocol)
        assertEq(
            weth.balanceOf(secondTakerUser),
            _initialWETHBalanceUser + 3 * ((price * 9_800) / ONE_HUNDRED_PERCENT_IN_BP)
        );
        // Verify the nonce is now marked as executed
        assertEq(looksRareProtocol.userOrderNonce(makerUser, makerBid.orderNonce), MAGIC_VALUE_ORDER_NONCE_EXECUTED);
    }

    function testInactiveStrategy() public {
        _setUpUsers();
        _setUpNewStrategy();

        uint256 amountsToFill = 4;

        uint256[] memory itemIds = new uint256[](0);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amountsToFill;

        // Prepare the order hash
        OrderStructs.Maker memory makerBid = _createMultiItemMakerOrder({
            quoteType: QuoteType.Bid,
            globalNonce: 0,
            subsetNonce: 0,
            strategyId: 1, // Multi-fill bid offer
            assetType: AssetType.ERC721,
            orderNonce: 0,
            collection: address(mockERC721),
            currency: address(weth),
            signer: makerUser,
            price: price,
            itemIds: itemIds,
            amounts: amounts
        });

        // Sign order
        bytes memory signature = _signMakerOrder(makerBid, makerUserPK);

        vm.prank(_owner);
        looksRareProtocol.updateStrategy(1, false, _standardProtocolFeeBp, _minTotalFeeBp);

        {
            itemIds = new uint256[](1);
            amounts = new uint256[](1);
            itemIds[0] = 0;
            amounts[0] = 1;

            mockERC721.mint(takerUser, itemIds[0]);

            // It should revert if strategy is not available
            vm.prank(takerUser);
            vm.expectRevert(abi.encodeWithSelector(IExecutionManager.StrategyNotAvailable.selector, 1));
            looksRareProtocol.executeTakerAsk(
                _genericTakerOrder(),
                makerBid,
                signature,
                _EMPTY_MERKLE_TREE,
                _EMPTY_AFFILIATE
            );
        }
    }
}
