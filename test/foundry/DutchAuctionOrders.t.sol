// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";
import {IExecutionStrategy} from "../../contracts/interfaces/IExecutionStrategy.sol";
import {IStrategyManager} from "../../contracts/interfaces/IStrategyManager.sol";
import {StrategyDutchAuction} from "../../contracts/executionStrategies/StrategyDutchAuction.sol";

import {ProtocolBase} from "./ProtocolBase.t.sol";

contract DutchAuctionOrdersTest is ProtocolBase, IStrategyManager {
    StrategyDutchAuction public strategyDutchAuction;
    uint256 private startingPrice = 10 ether;
    uint256 private finalPrice = 1 ether;

    function _setUpNewStrategy() private asPrankedUser(_owner) {
        strategyDutchAuction = new StrategyDutchAuction(address(looksRareProtocol));
        looksRareProtocol.addStrategy(true, _standardProtocolFee, 300, address(strategyDutchAuction));
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

        uint16 minNetRatio = 10000 - (_standardRoyaltyFee + _standardProtocolFee); // 3% slippage protection

        _setUpRoyalties(address(mockERC721), _standardRoyaltyFee);

        uint256[] memory itemIds = new uint256[](1);
        itemIds[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        mockERC721.mint(makerUser, itemIds[0]);

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
            minPrice: finalPrice,
            itemId: itemIds[0]
        });

        // TODO: stack too deep
        // 0.0025 ether cheaper per second -> (10 - 1) / 3600
        makerAsk.endTime = block.timestamp + 1 hours;
        makerAsk.additionalParameters = abi.encode(startingPrice);

        // Sign order
        signature = _signMakerAsk(makerAsk, makerUserPK);

        takerBid = OrderStructs.TakerBid({
            recipient: takerUser,
            minNetRatio: makerAsk.minNetRatio,
            maxPrice: startingPrice,
            itemIds: itemIds,
            amounts: amounts,
            additionalParameters: abi.encode()
        });

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

        uint256 decayPerSecond = 0.0025 ether;
        uint256 discount = elapsedTime * decayPerSecond;

        // Taker bid user pays the whole price
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser - startingPrice + discount);
        // Maker ask user receives 97% of the whole price (2% protocol + 1% royalties)
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser + ((startingPrice - discount) * 9700) / 10000);
    }

    function testCallerNotLooksRareProtocol() public {}

    function testZeroItemIdsLength() public {}

    function testItemIdsAndAmountsLengthMismatch() public {}

    function testStartingPriceTooLow() public {}

    function testAuctionStartingTimeTooLate() public {}

    function testCurrentPriceBelowEndPrice() public {}

    function testTakerBidPriceTooLow() public {}

    function testCurrentTimeTooEarly() public {}

    function testCurrentTimeTooLate() public {}
}
