// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Libraries and interfaces
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";
import {ITransferSelectorNFT} from "../../contracts/interfaces/ITransferSelectorNFT.sol";
import {INonceManager} from "../../contracts/interfaces/INonceManager.sol";

// Other utils and tests
import {StrategyTestMultiFillCollectionOrder} from "./utils/StrategyTestMultiFillCollectionOrder.sol";
import {ProtocolBase} from "./ProtocolBase.t.sol";

contract NonceInvalidationTest is INonceManager, ProtocolBase {
    /**
     * Cannot execute an order if subset nonce is used
     */
    function testCannotExecuteOrderIfSubsetNonceIsUsed() public {
        uint112 subsetNonce = 3;
        uint256 itemId = 420;

        {
            // Mint asset
            mockERC721.mint(makerUser, itemId);

            // Prepare the order hash
            makerAsk = _createSingleItemMakerAskOrder({
                askNonce: 0,
                subsetNonce: subsetNonce,
                strategyId: 0, // Standard sale for fixed price
                assetType: 0, // ERC721,
                orderNonce: 0,
                collection: address(mockERC721),
                currency: address(0), // ETH,
                signer: makerUser,
                minPrice: price,
                itemId: itemId
            });

            // Sign order
            signature = _signMakerAsk(makerAsk, makerUserPK);
        }

        uint112[] memory subsetNonces = new uint112[](1);
        subsetNonces[0] = subsetNonce;

        vm.prank(makerUser);
        vm.expectEmit(false, false, false, false);
        emit SubsetNoncesCancelled(subsetNonces);
        looksRareProtocol.cancelSubsetNonces(subsetNonces);

        {
            // Prepare the taker bid
            takerBid = OrderStructs.TakerBid(
                takerUser,
                makerAsk.minPrice,
                makerAsk.itemIds,
                makerAsk.amounts,
                abi.encode()
            );
        }

        // Execute taker bid transaction
        // Taker user actions
        vm.prank(takerUser);
        vm.expectRevert(WrongNonces.selector);
        looksRareProtocol.executeTakerBid{value: price}(
            takerBid,
            makerAsk,
            signature,
            _emptyMerkleTree,
            _emptyAffiliate
        );
    }

    /**
     * Cannot execute an order if maker is at a different global ask nonce than signed
     */
    function testCannotExecuteOrderIfWrongUserGlobalAskNonce() public {
        uint112 userGlobalAskNonce = 1;
        uint256 itemId = 420;

        {
            // Mint asset
            mockERC721.mint(makerUser, itemId);

            // Prepare the order hash
            makerAsk = _createSingleItemMakerAskOrder({
                askNonce: userGlobalAskNonce,
                subsetNonce: 0,
                strategyId: 0, // Standard sale for fixed price
                assetType: 0, // ERC721,
                orderNonce: 0,
                collection: address(mockERC721),
                currency: address(0), // ETH,
                signer: makerUser,
                minPrice: price,
                itemId: itemId
            });

            // Sign order
            signature = _signMakerAsk(makerAsk, makerUserPK);
        }

        {
            // Prepare the taker bid
            takerBid = OrderStructs.TakerBid(
                takerUser,
                makerAsk.minPrice,
                makerAsk.itemIds,
                makerAsk.amounts,
                abi.encode()
            );
        }

        // Execute taker bid transaction
        // Taker user actions
        vm.prank(takerUser);
        vm.expectRevert(WrongNonces.selector);
        looksRareProtocol.executeTakerBid{value: price}(
            takerBid,
            makerAsk,
            signature,
            _emptyMerkleTree,
            _emptyAffiliate
        );

        vm.prank(makerUser);
        vm.expectEmit(false, false, false, false);
        emit NewBidAskNonces(0, 1);
        looksRareProtocol.incrementBidAskNonces(false, true);
    }

    /**
     * Cannot execute an order if maker is at a different global bid nonce than signed
     */
    function testCannotExecuteOrderIfWrongUserGlobalBidNonce() public {
        uint112 userGlobalBidNonce = 1;
        uint256 itemId = 420;

        {
            // Prepare the order hash
            makerBid = _createSingleItemMakerBidOrder({
                bidNonce: userGlobalBidNonce,
                subsetNonce: 0,
                strategyId: 0, // Standard sale for fixed price
                assetType: 0, // ERC721,
                orderNonce: 0,
                collection: address(mockERC721),
                currency: address(weth),
                signer: makerUser,
                maxPrice: price,
                itemId: itemId
            });

            // Sign order
            signature = _signMakerBid(makerBid, makerUserPK);
        }

        {
            // Mint asset
            mockERC721.mint(takerUser, itemId);

            // Prepare the taker ask
            takerAsk = OrderStructs.TakerAsk(
                takerUser,
                makerBid.maxPrice,
                makerBid.itemIds,
                makerBid.amounts,
                abi.encode()
            );
        }

        // Execute taker ask transaction
        // Taker user actions
        vm.prank(takerUser);
        vm.expectRevert(WrongNonces.selector);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _emptyMerkleTree, _emptyAffiliate);

        vm.prank(makerUser);
        vm.expectEmit(false, false, false, false);
        emit NewBidAskNonces(1, 0);
        looksRareProtocol.incrementBidAskNonces(true, false);
    }

    /**
     * Cannot execute an order twice
     */
    function testCannotExecuteAnOrderTwice() public {
        _setUpUsers();
        _setupRegistryRoyalties(address(mockERC721), _standardRoyaltyFee);

        price = 1 ether; // Fixed price of sale
        uint256 itemId = 0; // TokenId

        {
            // Prepare the order hash
            makerBid = _createSingleItemMakerBidOrder({
                bidNonce: 0,
                subsetNonce: 0,
                strategyId: 0, // Standard sale for fixed price
                assetType: 0, // ERC721,
                orderNonce: 0,
                collection: address(mockERC721),
                currency: address(weth),
                signer: makerUser,
                maxPrice: price,
                itemId: itemId
            });

            // Sign order
            signature = _signMakerBid(makerBid, makerUserPK);
        }

        // Taker user actions
        vm.startPrank(takerUser);

        {
            // Mint asset
            mockERC721.mint(takerUser, itemId);

            // Prepare the taker ask
            takerAsk = OrderStructs.TakerAsk(
                takerUser,
                makerBid.maxPrice,
                makerBid.itemIds,
                makerBid.amounts,
                abi.encode()
            );
        }

        {
            looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _emptyMerkleTree, _emptyAffiliate);

            // Second one fails
            vm.expectRevert(WrongNonces.selector);
            looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _emptyMerkleTree, _emptyAffiliate);
        }

        vm.stopPrank();
    }

    /**
     * Cannot execute an order sharing the same order nonce as another that is being partially filled
     */
    function testCannotExecuteAnotherOrderAtNonceIfExecutionIsInProgress() public {
        _setUpUsers();

        // 0. Add the new strategy
        bytes4 selectorTakerAsk = StrategyTestMultiFillCollectionOrder.executeStrategyWithTakerAsk.selector;
        bytes4 selectorTakerBid = StrategyTestMultiFillCollectionOrder.executeStrategyWithTakerBid.selector;

        StrategyTestMultiFillCollectionOrder strategyMultiFillCollectionOrder = new StrategyTestMultiFillCollectionOrder(
                address(looksRareProtocol)
            );

        vm.prank(_owner);
        looksRareProtocol.addStrategy(
            _standardProtocolFee,
            _minTotalFee,
            _maxProtocolFee,
            selectorTakerAsk,
            selectorTakerBid,
            address(strategyMultiFillCollectionOrder)
        );

        // 1. Maker signs a message and execute a partial fill on it
        price = 1 ether; // Fixed price of sale
        uint256 amountsToFill = 4;
        uint256 orderNonce = 420;

        {
            uint256[] memory itemIds = new uint256[](0);
            uint256[] memory amounts = new uint256[](1);
            amounts[0] = amountsToFill;

            {
                // Prepare the first order
                makerBid = _createMultiItemMakerBidOrder({
                    bidNonce: 0,
                    subsetNonce: 0,
                    strategyId: 1, // Multi-fill bid offer
                    assetType: 0,
                    orderNonce: orderNonce,
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
        {
            uint256[] memory itemIds = new uint256[](1);
            uint256[] memory amounts = new uint256[](1);
            itemIds[0] = 0;
            amounts[0] = 1;

            mockERC721.mint(takerUser, itemIds[0]);

            // Prepare the taker ask
            takerAsk = OrderStructs.TakerAsk(takerUser, makerBid.maxPrice, itemIds, amounts, abi.encode());

            vm.prank(takerUser);

            // Execute taker ask transaction
            looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _emptyMerkleTree, _emptyAffiliate);
        }

        // 2. Second maker order is signed sharing the same order nonce as the first one
        {
            uint256 itemId = 420;

            uint256[] memory itemIds = new uint256[](1);
            uint256[] memory amounts = new uint256[](1);
            itemIds[0] = itemId;
            amounts[0] = 1;

            // Prepare the second order
            makerBid = _createMultiItemMakerBidOrder({
                bidNonce: 0,
                subsetNonce: 0,
                strategyId: 0, // normal offer
                assetType: 0,
                orderNonce: orderNonce,
                collection: address(mockERC721),
                currency: address(weth),
                signer: makerUser,
                maxPrice: price,
                itemIds: itemIds,
                amounts: amounts
            });

            // Sign order
            signature = _signMakerBid(makerBid, makerUserPK);

            // Prepare the taker ask
            takerAsk = OrderStructs.TakerAsk(takerUser, makerBid.maxPrice, itemIds, amounts, abi.encode());

            vm.prank(takerUser);

            // Second one fails when a taker user tries to execute
            vm.expectRevert(WrongNonces.selector);
            looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _emptyMerkleTree, _emptyAffiliate);
        }
    }

    function testCancelOrderNonces() public asPrankedUser(makerUser) {
        assertEq(looksRareProtocol.userOrderNonce(makerUser, 69), bytes32(0));
        assertEq(looksRareProtocol.userOrderNonce(makerUser, 420), bytes32(0));

        uint256[] memory orderNonces = new uint256[](2);
        orderNonces[0] = 69;
        orderNonces[1] = 420;
        vm.expectEmit(true, false, false, true);
        emit OrderNoncesCancelled(orderNonces);
        looksRareProtocol.cancelOrderNonces(orderNonces);

        bytes32 expectedMagicValue = 0x000000000000000000000000000000000000000000000000000000000000002a;

        assertEq(looksRareProtocol.userOrderNonce(makerUser, 69), expectedMagicValue);
        assertEq(looksRareProtocol.userOrderNonce(makerUser, 420), expectedMagicValue);
    }

    /**
     * Cannot execute an order if its nonce has been cancelled
     */
    function testCannotExecuteAnOrderWhoseNonceIsCancelled() public {
        _setUpUsers();
        _setupRegistryRoyalties(address(mockERC721), _standardRoyaltyFee);

        price = 1 ether; // Fixed price of sale
        uint256 itemId = 0; // TokenId

        uint256 orderNonce = 69;

        uint256[] memory orderNonces = new uint256[](1);
        orderNonces[0] = orderNonce;
        vm.prank(makerUser);
        looksRareProtocol.cancelOrderNonces(orderNonces);

        {
            // Prepare the order hash
            makerBid = _createSingleItemMakerBidOrder({
                bidNonce: 0,
                subsetNonce: 0,
                strategyId: 0, // Standard sale for fixed price
                assetType: 0, // ERC721,
                orderNonce: orderNonce,
                collection: address(mockERC721),
                currency: address(weth),
                signer: makerUser,
                maxPrice: price,
                itemId: itemId
            });

            // Sign order
            signature = _signMakerBid(makerBid, makerUserPK);
        }

        // Taker user actions
        vm.startPrank(takerUser);

        {
            // Mint asset
            mockERC721.mint(takerUser, itemId);

            // Prepare the taker ask
            takerAsk = OrderStructs.TakerAsk(
                takerUser,
                makerBid.maxPrice,
                makerBid.itemIds,
                makerBid.amounts,
                abi.encode()
            );
        }

        {
            vm.expectRevert(WrongNonces.selector);
            looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _emptyMerkleTree, _emptyAffiliate);
        }

        vm.stopPrank();
    }
}
