// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";
import {IExecutionStrategy} from "../../contracts/interfaces/IExecutionStrategy.sol";
import {IStrategyManager} from "../../contracts/interfaces/IStrategyManager.sol";
import {StrategyDutchAuction} from "../../contracts/executionStrategies/StrategyDutchAuction.sol";
import {ProtocolBase} from "./ProtocolBase.t.sol";

contract DutchAuctionOrdersTest is ProtocolBase, IStrategyManager {
    StrategyDutchAuction public strategyDutchAuction;
    bytes4 public selectorTakerAsk = _emptyBytes4;
    bytes4 public selectorTakerBid = StrategyDutchAuction.executeStrategyWithTakerBid.selector;

    uint256 private startPrice = 10 ether;
    uint256 private endPrice = 1 ether;
    uint256 private decayPerSecond = 0.0025 ether;

    function _setUpNewStrategy() private asPrankedUser(_owner) {
        strategyDutchAuction = new StrategyDutchAuction(address(looksRareProtocol));
        looksRareProtocol.addStrategy(
            _standardProtocolFee,
            _minTotalFee,
            _maxProtocolFee,
            selectorTakerAsk,
            selectorTakerBid,
            address(strategyDutchAuction)
        );
    }

    function _createMakerAskAndTakerBid(uint256 numberOfItems, uint256 numberOfAmounts)
        private
        returns (OrderStructs.MakerAsk memory newMakerAsk, OrderStructs.TakerBid memory newTakerBid)
    {
        uint256[] memory itemIds = new uint256[](numberOfItems);
        for (uint256 i; i < numberOfItems; ) {
            mockERC721.mint(makerUser, i + 1);
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

        // Prepare the order hash
        newMakerAsk = _createSingleItemMakerAskOrder({
            askNonce: 0,
            subsetNonce: 0,
            strategyId: 2,
            assetType: 0,
            orderNonce: 0,
            collection: address(mockERC721),
            currency: address(weth),
            signer: makerUser,
            minPrice: endPrice,
            itemId: 1
        });

        newMakerAsk.itemIds = itemIds;
        newMakerAsk.amounts = amounts;

        // 0.0025 ether cheaper per second -> (10 - 1) / 3600
        newMakerAsk.endTime = block.timestamp + 1 hours;
        newMakerAsk.additionalParameters = abi.encode(startPrice);

        newTakerBid = OrderStructs.TakerBid(takerUser, startPrice, itemIds, amounts, abi.encode());
    }

    function testNewStrategy() public {
        _setUpNewStrategy();

        (
            bool strategyIsActive,
            uint16 strategyStandardProtocolFee,
            uint16 strategyMinTotalFee,
            uint16 strategyMaxProtocolFee,
            bytes4 strategySelectorTakerAsk,
            bytes4 strategySelectorTakerBid,
            address strategyImplementation
        ) = looksRareProtocol.strategyInfo(2);

        assertTrue(strategyIsActive);
        assertEq(strategyStandardProtocolFee, _standardProtocolFee);
        assertEq(strategyMinTotalFee, _minTotalFee);
        assertEq(strategyMaxProtocolFee, _maxProtocolFee);
        assertEq(strategySelectorTakerAsk, selectorTakerAsk);
        assertEq(strategySelectorTakerBid, selectorTakerBid);
        assertEq(strategyImplementation, address(strategyDutchAuction));
    }

    function testDutchAuction(uint256 elapsedTime) public {
        vm.assume(elapsedTime <= 3600);

        _setUpUsers();
        _setUpNewStrategy();
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
            _emptyAffiliate
        );

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(1), takerUser);

        uint256 discount = elapsedTime * decayPerSecond;

        // Taker bid user pays the whole price
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser - startPrice + discount);
        // Maker ask user receives 98% of the whole price (2% protocol)
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser + ((startPrice - discount) * 9800) / 10000);
    }

    function testCallerNotLooksRareProtocol() public {
        _setUpUsers();
        _setUpNewStrategy();
        (makerAsk, takerBid) = _createMakerAskAndTakerBid(1, 1);

        vm.expectRevert(IExecutionStrategy.WrongCaller.selector);
        // Call the function directly
        strategyDutchAuction.executeStrategyWithTakerBid(takerBid, makerAsk);
    }

    function testZeroItemIdsLength() public {
        _setUpUsers();
        _setUpNewStrategy();
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
            _emptyAffiliate
        );
    }

    function testItemIdsAndAmountsLengthMismatch() public {
        _setUpUsers();
        _setUpNewStrategy();
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
            _emptyAffiliate
        );
    }

    function testItemIdsMismatch() public {
        _setUpUsers();
        _setUpNewStrategy();
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
            _emptyAffiliate
        );
    }

    function testZeroAmount() public {
        _setUpUsers();
        _setUpNewStrategy();
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
            _emptyAffiliate
        );
    }

    function testStartPriceTooLow() public {
        _setUpUsers();
        _setUpNewStrategy();
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
            _emptyAffiliate
        );
    }

    function testTakerBidTooLow(uint256 elapsedTime) public {
        vm.assume(elapsedTime <= 3600);

        _setUpUsers();
        _setUpNewStrategy();
        (makerAsk, takerBid) = _createMakerAskAndTakerBid(1, 1);

        uint256 currentPrice = startPrice - decayPerSecond * elapsedTime;
        takerBid.maxPrice = currentPrice - 1 wei;

        // Sign order
        signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.expectRevert(IExecutionStrategy.BidTooLow.selector);
        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerBid(
            takerBid,
            makerAsk,
            signature,
            _emptyMerkleRoot,
            _emptyMerkleProof,
            _emptyAffiliate
        );
    }
}
