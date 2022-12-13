// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Libraries
import {OrderStructs} from "../../../contracts/libraries/OrderStructs.sol";

// Interfaces
import {IExecutionManager} from "../../../contracts/interfaces/IExecutionManager.sol";
import {IStrategyManager} from "../../../contracts/interfaces/IStrategyManager.sol";

// Mock files and other tests
import {StrategyTestMultiFillCollectionOrder} from "../utils/StrategyTestMultiFillCollectionOrder.sol";
import {ProtocolBase} from "../ProtocolBase.t.sol";

contract MultiFillCollectionOrdersTest is ProtocolBase, IStrategyManager {
    bytes4 public selectorTakerAsk = StrategyTestMultiFillCollectionOrder.executeStrategyWithTakerAsk.selector;

    StrategyTestMultiFillCollectionOrder public strategyMultiFillCollectionOrder;

    function _setUpNewStrategy() private asPrankedUser(_owner) {
        strategyMultiFillCollectionOrder = new StrategyTestMultiFillCollectionOrder(address(looksRareProtocol));
        looksRareProtocol.addStrategy(
            _standardProtocolFee,
            _minTotalFee,
            _maxProtocolFee,
            selectorTakerAsk,
            false,
            address(strategyMultiFillCollectionOrder)
        );
    }

    function testNewStrategy() public {
        _setUpNewStrategy();
        (
            bool strategyIsActive,
            uint16 strategyStandardProtocolFee,
            uint16 strategyMinTotalFee,
            uint16 strategyMaxProtocolFee,
            bytes4 strategySelector,
            bool isTakerBid,
            address strategyImplementation
        ) = looksRareProtocol.strategyInfo(1);

        assertTrue(strategyIsActive);
        assertEq(strategyStandardProtocolFee, _standardProtocolFee);
        assertEq(strategyMinTotalFee, _minTotalFee);
        assertEq(strategyMaxProtocolFee, _maxProtocolFee);
        assertEq(strategySelector, selectorTakerAsk);
        assertFalse(isTakerBid);
        assertEq(strategyImplementation, address(strategyMultiFillCollectionOrder));
    }

    /**
     * Maker bid user wants to buy 4 ERC721 items in a collection. The order can be filled in multiple parts.
     * First takerUser sells 1 item.
     * Second takerUser sells 3 items.
     */
    function testMultiFill() public {
        _setUpUsers();
        _setUpNewStrategy();

        price = 1 ether; // Fixed price of sale
        uint256 amountsToFill = 4;

        {
            uint256[] memory itemIds = new uint256[](0);
            uint256[] memory amounts = new uint256[](1);
            amounts[0] = amountsToFill;

            {
                // Prepare the order hash
                makerBid = _createMultiItemMakerBidOrder({
                    bidNonce: 0,
                    subsetNonce: 0,
                    strategyId: 1, // Multi-fill bid offer
                    assetType: 0,
                    orderNonce: 0,
                    collection: address(mockERC721),
                    currency: address(weth),
                    signer: makerUser,
                    maxPrice: price,
                    itemIds: itemIds,
                    amounts: amounts
                });

                // Sign order
                signature = _signMakerBid(makerBid, makerUserPK);
            }
        }

        // First taker user actions
        vm.startPrank(takerUser);
        {
            uint256[] memory itemIds = new uint256[](1);
            uint256[] memory amounts = new uint256[](1);
            itemIds[0] = 0;
            amounts[0] = 1;

            mockERC721.mint(takerUser, itemIds[0]);

            // Prepare the taker ask
            takerAsk = OrderStructs.TakerAsk(takerUser, makerBid.maxPrice, itemIds, amounts, abi.encode());

            uint256 gasLeft = gasleft();

            // Execute taker ask transaction
            looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _emptyMerkleTree, _emptyAffiliate);

            emit log_named_uint(
                "TakerAsk // 1 ERC721 Sold // Protocol Fee // Collection Order (Multi-fills) // Registry Royalties",
                gasLeft - gasleft()
            );
        }

        vm.stopPrank();

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(0), makerUser);
        // Maker bid user pays the whole price
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser - price);
        // Taker ask user receives 98% of the whole price (2% protocol)
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser + (price * 9_800) / 10_000);
        // Verify the nonce is not marked as executed
        assertEq(looksRareProtocol.userOrderNonce(makerUser, makerBid.orderNonce), computeOrderHashMakerBid(makerBid));

        // Second taker user actions
        address secondTakerUser = address(420);
        _setUpUser(secondTakerUser);
        vm.startPrank(secondTakerUser);

        {
            uint256[] memory itemIds = new uint256[](3);
            uint256[] memory amounts = new uint256[](3);

            itemIds[0] = 1; // tokenId = 1
            itemIds[1] = 2; // tokenId = 2
            itemIds[2] = 3; // tokenId = 3
            amounts[0] = 1;
            amounts[1] = 1;
            amounts[2] = 1;

            mockERC721.batchMint(secondTakerUser, itemIds);

            // Prepare the taker ask
            takerAsk = OrderStructs.TakerAsk(secondTakerUser, makerBid.maxPrice, itemIds, amounts, abi.encode());

            uint256 gasLeft = gasleft();

            // Execute taker ask transaction
            looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _emptyMerkleTree, _emptyAffiliate);

            emit log_named_uint(
                "TakerAsk // 3 ERC721 Sold // Protocol Fee // Collection Order (Multi-fills) // Registry Royalties",
                gasLeft - gasleft()
            );
        }

        // Taker user has received the 3 assets
        assertEq(mockERC721.ownerOf(1), makerUser);
        assertEq(mockERC721.ownerOf(2), makerUser);
        assertEq(mockERC721.ownerOf(3), makerUser);

        // Maker bid user pays the whole price
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser - 4 * price);
        // Taker ask user receives 98% of the whole price (2% protocol)
        assertEq(weth.balanceOf(secondTakerUser), _initialWETHBalanceUser + 3 * ((price * 9_800) / 10_000));
        // Verify the nonce is now marked as executed
        assertEq(looksRareProtocol.userOrderNonce(makerUser, makerBid.orderNonce), MAGIC_VALUE_NONCE_EXECUTED);
    }

    function testInactiveStrategy() public {
        _setUpUsers();
        _setUpNewStrategy();

        price = 1 ether; // Fixed price of sale
        uint256 amountsToFill = 4;

        {
            uint256[] memory itemIds = new uint256[](0);
            uint256[] memory amounts = new uint256[](1);
            amounts[0] = amountsToFill;

            // Prepare the order hash
            makerBid = _createMultiItemMakerBidOrder({
                bidNonce: 0,
                subsetNonce: 0,
                strategyId: 1, // Multi-fill bid offer
                assetType: 0,
                orderNonce: 0,
                collection: address(mockERC721),
                currency: address(weth),
                signer: makerUser,
                maxPrice: price,
                itemIds: itemIds,
                amounts: amounts
            });

            // Sign order
            signature = _signMakerBid(makerBid, makerUserPK);
        }

        vm.prank(_owner);
        looksRareProtocol.updateStrategy(1, _standardProtocolFee, _minTotalFee, false);

        {
            uint256[] memory itemIds = new uint256[](1);
            uint256[] memory amounts = new uint256[](1);
            itemIds[0] = 0;
            amounts[0] = 1;

            mockERC721.mint(takerUser, itemIds[0]);

            // Prepare the taker ask
            takerAsk = OrderStructs.TakerAsk(takerUser, makerBid.maxPrice, itemIds, amounts, abi.encode());

            vm.prank(takerUser);
            vm.expectRevert(abi.encodeWithSelector(IExecutionManager.StrategyNotAvailable.selector, uint16(1)));
            // Execute taker ask transaction
            looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _emptyMerkleTree, _emptyAffiliate);
        }
    }
}
