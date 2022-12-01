// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ITransferSelectorNFT} from "../../contracts/interfaces/ITransferSelectorNFT.sol";
import {INonceManager} from "../../contracts/interfaces/INonceManager.sol";
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";

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
            makerAsk = _createSingleItemMakerAskOrder(
                0, // askNonce
                subsetNonce, // subsetNonce
                0, // strategyId (Standard sale for fixed price)
                0, // assetType ERC721,
                0, // orderNonce
                address(mockERC721),
                address(0), // ETH,
                makerUser,
                price,
                itemId
            );

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
            _emptyMerkleRoot,
            _emptyMerkleProof,
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
            makerAsk = _createSingleItemMakerAskOrder(
                userGlobalAskNonce, // askNonce
                0, // subsetNonce
                0, // strategyId (Standard sale for fixed price)
                0, // assetType ERC721,
                0, // orderNonce
                address(mockERC721),
                address(0), // ETH,
                makerUser,
                price,
                itemId
            );

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
            _emptyMerkleRoot,
            _emptyMerkleProof,
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
            makerBid = _createSingleItemMakerBidOrder(
                userGlobalBidNonce, // bidNonce
                0, // subsetNonce
                0, // strategyId (Standard sale for fixed price)
                0, // assetType ERC721,
                0, // orderNonce
                address(mockERC721),
                address(weth),
                makerUser,
                price,
                itemId
            );

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
        looksRareProtocol.executeTakerAsk(
            takerAsk,
            makerBid,
            signature,
            _emptyMerkleRoot,
            _emptyMerkleProof,
            _emptyAffiliate
        );

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
            makerBid = _createSingleItemMakerBidOrder(
                0, // askNonce
                0, // subsetNonce
                0, // strategyId (Standard sale for fixed price)
                0, // assetType ERC721,
                0, // orderNonce
                address(mockERC721),
                address(weth),
                makerUser,
                price,
                itemId
            );

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
            looksRareProtocol.executeTakerAsk(
                takerAsk,
                makerBid,
                signature,
                _emptyMerkleRoot,
                _emptyMerkleProof,
                _emptyAffiliate
            );

            // Second one fails
            vm.expectRevert(WrongNonces.selector);
            looksRareProtocol.executeTakerAsk(
                takerAsk,
                makerBid,
                signature,
                _emptyMerkleRoot,
                _emptyMerkleProof,
                _emptyAffiliate
            );
        }

        vm.stopPrank();
    }

    /**
     * Cannot execute an order sharing the same order nonce as another that is being partially filled
     */
    function testCannotExecuteAnotherOrderAtNonceIfExecutionIsInProgress() public {
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

        _setUpUsers();

        price = 1 ether; // Fixed price of sale
        uint256 amountsToFill = 4;
        uint112 orderNonce = 420;

        {
            uint256[] memory itemIds = new uint256[](0);
            uint256[] memory amounts = new uint256[](1);
            amounts[0] = amountsToFill;

            {
                // Prepare the first order
                makerBid = _createMultiItemMakerBidOrder(
                    0, // bidNonce
                    0, // subsetNonce
                    1, // strategyId (Multi-fill bid offer)
                    0, // assetType ERC721,
                    orderNonce, // orderNonce
                    address(mockERC721),
                    address(weth),
                    makerUser,
                    price,
                    itemIds,
                    amounts
                );

                // Sign order
                signature = _signMakerBid(makerBid, makerUserPK);

                // Prepare the first order
                makerBid = _createMultiItemMakerBidOrder(
                    0, // bidNonce
                    0, // subsetNonce
                    1, // strategyId (Multi-fill bid offer)
                    0, // assetType ERC721,
                    orderNonce, // orderNonce
                    address(mockERC721),
                    address(weth),
                    makerUser,
                    price,
                    itemIds,
                    amounts
                );

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
            looksRareProtocol.executeTakerAsk(
                takerAsk,
                makerBid,
                signature,
                _emptyMerkleRoot,
                _emptyMerkleProof,
                _emptyAffiliate
            );
        }

        {
            uint256 itemId = 420;

            uint256[] memory itemIds = new uint256[](1);
            uint256[] memory amounts = new uint256[](1);
            itemIds[0] = itemId;
            amounts[0] = 1;

            // Prepare the second order
            makerBid = _createMultiItemMakerBidOrder(
                0, // bidNonce
                0, // subsetNonce
                0, // strategyId (normal offer)
                0, // assetType ERC721,
                orderNonce, // orderNonce
                address(mockERC721),
                address(weth),
                makerUser,
                price,
                itemIds,
                amounts
            );

            // Sign order
            signature = _signMakerBid(makerBid, makerUserPK);

            // Prepare the taker ask
            takerAsk = OrderStructs.TakerAsk(takerUser, makerBid.maxPrice, itemIds, amounts, abi.encode());

            vm.prank(takerUser);

            // Second one fails
            vm.expectRevert(WrongNonces.selector);

            // Execute taker ask transaction
            looksRareProtocol.executeTakerAsk(
                takerAsk,
                makerBid,
                signature,
                _emptyMerkleRoot,
                _emptyMerkleProof,
                _emptyAffiliate
            );
        }
    }
}
