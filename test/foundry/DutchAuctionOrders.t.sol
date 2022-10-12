// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";
import {IExecutionStrategy} from "../../contracts/interfaces/IExecutionStrategy.sol";
import {IStrategyManager} from "../../contracts/interfaces/IStrategyManager.sol";
import {StrategyDutchAuction} from "../../contracts/executionStrategies/StrategyDutchAuction.sol";
import {ProtocolBase} from "./ProtocolBase.t.sol";

contract DutchAuctionOrdersTest is ProtocolBase, IStrategyManager {
    StrategyDutchAuction public strategyDutchAuction;
    uint256 private startPrice = 10 ether;
    uint256 private endPrice = 1 ether;
    uint256 private decayPerSecond = 0.0025 ether;

    function _setUpNewStrategy() private asPrankedUser(_owner) {
        strategyDutchAuction = new StrategyDutchAuction(address(looksRareProtocol));
        looksRareProtocol.addStrategy(true, _standardProtocolFee, 300, address(strategyDutchAuction));
    }

    function _createMakerAskAndTakerBid(uint256 numberOfItems, uint256 numberOfAmounts)
        private
        returns (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid)
    {
        uint256[] memory itemIds = new uint256[](numberOfItems);
        for (uint256 i; i < numberOfItems; ) {
            itemIds[i] = i + 1;
            unchecked {
                ++i;
            }
        }

        uint256[] memory amounts = new uint256[](numberOfAmounts);
        for (uint256 i; i < numberOfAmounts; ) {
            amounts[i] = 1;
            unchecked {
                ++i;
            }
        }

        mockERC721.mint(makerUser, 1);

        uint16 minNetRatio = 10000 - (_standardRoyaltyFee + _standardProtocolFee); // 3% slippage protection

        // Prepare the order hash
        makerAsk = _createSingleItemMakerAskOrder({
            askNonce: 0,
            subsetNonce: 0,
            strategyId: 2,
            assetType: 0,
            orderNonce: 0,
            minNetRatio: minNetRatio,
            collection: address(mockERC721),
            currency: address(weth),
            signer: makerUser,
            minPrice: endPrice,
            itemId: 1
        });

        makerAsk.itemIds = itemIds;
        makerAsk.amounts = amounts;

        // 0.0025 ether cheaper per second -> (10 - 1) / 3600
        makerAsk.endTime = block.timestamp + 1 hours;
        makerAsk.additionalParameters = abi.encode(startPrice);

        takerBid = OrderStructs.TakerBid({
            recipient: takerUser,
            minNetRatio: makerAsk.minNetRatio,
            maxPrice: startPrice,
            itemIds: itemIds,
            amounts: amounts,
            additionalParameters: abi.encode()
        });
    }

    function testNewStrategy() public {
        _setUpNewStrategy();
        Strategy memory strategy = looksRareProtocol.strategyInfo(2);
        assertTrue(strategy.isActive);
        assertTrue(strategy.hasRoyalties);
        assertEq(strategy.protocolFee, _standardProtocolFee);
        assertEq(strategy.maxProtocolFee, uint16(300));
        assertEq(strategy.implementation, address(strategyDutchAuction));
    }

    function testDutchAuction(uint256 elapsedTime) public {
        vm.assume(elapsedTime <= 3600);

        _setUpUsers();
        _setUpNewStrategy();
        _setUpRoyalties(address(mockERC721), _standardRoyaltyFee);
        (makerAsk, takerBid) = _createMakerAskAndTakerBid(1, 1);

        // Sign order
        signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.warp(block.timestamp + elapsedTime);

        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerBid(
            takerBid,
            makerAsk,
            signature,
            _emptyMerkleRoot,
            _emptyMerkleProof,
            _emptyReferrer
        );

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(1), takerUser);

        uint256 discount = elapsedTime * decayPerSecond;

        // Taker bid user pays the whole price
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser - startPrice + discount);
        // Maker ask user receives 97% of the whole price (2% protocol + 1% royalties)
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser + ((startPrice - discount) * 9700) / 10000);
    }

    function testCallerNotLooksRareProtocol() public {
        _setUpUsers();
        _setUpNewStrategy();
        _setUpRoyalties(address(mockERC721), _standardRoyaltyFee);
        (makerAsk, takerBid) = _createMakerAskAndTakerBid(1, 1);

        vm.expectRevert(IExecutionStrategy.WrongCaller.selector);
        // Call the function directly
        strategyDutchAuction.executeStrategyWithTakerBid(takerBid, makerAsk);
    }

    function testZeroItemIdsLength() public {
        _setUpUsers();
        _setUpNewStrategy();
        _setUpRoyalties(address(mockERC721), _standardRoyaltyFee);
        (makerAsk, takerBid) = _createMakerAskAndTakerBid(0, 0);

        // Sign order
        signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.expectRevert(IExecutionStrategy.OrderInvalid.selector);
        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerBid(
            takerBid,
            makerAsk,
            signature,
            _emptyMerkleRoot,
            _emptyMerkleProof,
            _emptyReferrer
        );
    }

    function testItemIdsAndAmountsLengthMismatch() public {
        _setUpUsers();
        _setUpNewStrategy();
        _setUpRoyalties(address(mockERC721), _standardRoyaltyFee);
        (makerAsk, takerBid) = _createMakerAskAndTakerBid(1, 2);

        // Sign order
        signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.expectRevert(IExecutionStrategy.OrderInvalid.selector);
        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerBid(
            takerBid,
            makerAsk,
            signature,
            _emptyMerkleRoot,
            _emptyMerkleProof,
            _emptyReferrer
        );
    }

    function testItemIdsMismatch() public {
        _setUpUsers();
        _setUpNewStrategy();
        _setUpRoyalties(address(mockERC721), _standardRoyaltyFee);
        (makerAsk, takerBid) = _createMakerAskAndTakerBid(1, 1);

        uint256[] memory itemIds = new uint256[](1);
        itemIds[0] = 2;

        // Bidder bidding on something else
        takerBid.itemIds = itemIds;

        // Sign order
        signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.expectRevert(IExecutionStrategy.OrderInvalid.selector);
        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerBid(
            takerBid,
            makerAsk,
            signature,
            _emptyMerkleRoot,
            _emptyMerkleProof,
            _emptyReferrer
        );
    }

    function testZeroAmount() public {
        _setUpUsers();
        _setUpNewStrategy();
        _setUpRoyalties(address(mockERC721), _standardRoyaltyFee);
        (makerAsk, takerBid) = _createMakerAskAndTakerBid(1, 1);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0;
        makerAsk.amounts = amounts;

        // Sign order
        signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.expectRevert(IExecutionStrategy.OrderInvalid.selector);
        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerBid(
            takerBid,
            makerAsk,
            signature,
            _emptyMerkleRoot,
            _emptyMerkleProof,
            _emptyReferrer
        );
    }

    function testStartPriceTooLow() public {
        _setUpUsers();
        _setUpNewStrategy();
        _setUpRoyalties(address(mockERC721), _standardRoyaltyFee);
        (makerAsk, takerBid) = _createMakerAskAndTakerBid(1, 1);

        // startPrice is 10 ether
        makerAsk.minPrice = 10 ether + 1 wei;

        // Sign order
        signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.expectRevert(IExecutionStrategy.OrderInvalid.selector);
        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerBid(
            takerBid,
            makerAsk,
            signature,
            _emptyMerkleRoot,
            _emptyMerkleProof,
            _emptyReferrer
        );
    }

    function testTakerBidTooLow(uint256 elapsedTime) public {
        vm.assume(elapsedTime <= 3600);

        _setUpUsers();
        _setUpNewStrategy();
        _setUpRoyalties(address(mockERC721), _standardRoyaltyFee);
        (makerAsk, takerBid) = _createMakerAskAndTakerBid(1, 1);

        uint256 currentPrice = startPrice - decayPerSecond * elapsedTime;
        takerBid.maxPrice = currentPrice - 1 wei;

        // Sign order
        signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.expectRevert(StrategyDutchAuction.BidTooLow.selector);
        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerBid(
            takerBid,
            makerAsk,
            signature,
            _emptyMerkleRoot,
            _emptyMerkleProof,
            _emptyReferrer
        );
    }
}