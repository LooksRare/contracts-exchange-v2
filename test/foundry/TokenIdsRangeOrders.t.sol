// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";
import {IExecutionStrategy} from "../../contracts/interfaces/IExecutionStrategy.sol";
import {IStrategyManager} from "../../contracts/interfaces/IStrategyManager.sol";
import {StrategyTokenIdsRange} from "../../contracts/executionStrategies/StrategyTokenIdsRange.sol";
import {ProtocolBase} from "./ProtocolBase.t.sol";

contract TokenIdsRangeOrdersTest is ProtocolBase, IStrategyManager {
    StrategyTokenIdsRange public strategyTokenIdsRange;

    function _setUpNewStrategy() private asPrankedUser(_owner) {
        strategyTokenIdsRange = new StrategyTokenIdsRange(address(looksRareProtocol));
        looksRareProtocol.addStrategy(true, _standardProtocolFee, 300, address(strategyTokenIdsRange));
    }

    function _createMakerBidAndTakerAsk()
        private
        returns (OrderStructs.MakerBid memory makerBid, OrderStructs.TakerAsk memory takerAsk)
    {
        uint256[] memory makerBidItemIds = new uint256[](2);
        makerBidItemIds[0] = 5;
        makerBidItemIds[1] = 10;

        uint256[] memory makerBidAmounts = new uint256[](1);
        makerBidAmounts[0] = 3;

        uint16 minNetRatio = 10000 - (_standardRoyaltyFee + _standardProtocolFee); // 3% slippage protection

        makerBid = _createMultiItemMakerBidOrder({
            bidNonce: 0,
            subsetNonce: 0,
            strategyId: 2,
            assetType: 0,
            orderNonce: 0,
            minNetRatio: minNetRatio,
            collection: address(mockERC721),
            currency: address(weth),
            signer: makerUser,
            maxPrice: 1 ether,
            itemIds: makerBidItemIds,
            amounts: makerBidAmounts
        });

        mockERC721.mint(takerUser, 4);
        mockERC721.mint(takerUser, 5);
        mockERC721.mint(takerUser, 7);
        mockERC721.mint(takerUser, 10);
        mockERC721.mint(takerUser, 11);

        uint256[] memory takerAskItemIds = new uint256[](3);
        takerAskItemIds[0] = 5;
        takerAskItemIds[1] = 7;
        takerAskItemIds[2] = 10;

        uint256[] memory takerAskAmounts = new uint256[](3);
        takerAskAmounts[0] = 1;
        takerAskAmounts[1] = 1;
        takerAskAmounts[2] = 1;

        takerAsk = OrderStructs.TakerAsk({
            recipient: takerUser,
            minNetRatio: makerAsk.minNetRatio,
            minPrice: makerBid.maxPrice,
            itemIds: takerAskItemIds,
            amounts: takerAskAmounts,
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
        assertEq(strategy.implementation, address(strategyTokenIdsRange));
    }

    function testTokenIdsRange() public {
        _setUpUsers();
        _setUpNewStrategy();
        _setUpRoyalties(address(mockERC721), _standardRoyaltyFee);
        (makerBid, takerAsk) = _createMakerBidAndTakerAsk();

        // Sign order
        signature = _signMakerBid(makerBid, makerUserPK);

        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerAsk(
            takerAsk,
            makerBid,
            signature,
            _emptyMerkleRoot,
            _emptyMerkleProof,
            _emptyReferrer
        );

        // Maker user has received the asset
        assertEq(mockERC721.ownerOf(5), makerUser);
        assertEq(mockERC721.ownerOf(7), makerUser);
        assertEq(mockERC721.ownerOf(10), makerUser);

        // Maker bid user pays the whole price
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser - 1 ether);
        // Taker ask user receives 97% of the whole price (2% protocol + 1% royalties)
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser + (1 ether * 9700) / 10000);
    }

    function testCallerNotLooksRareProtocol() public {
        _setUpUsers();
        _setUpNewStrategy();
        _setUpRoyalties(address(mockERC721), _standardRoyaltyFee);
        (makerBid, takerAsk) = _createMakerBidAndTakerAsk();

        // Sign order
        signature = _signMakerBid(makerBid, makerUserPK);

        vm.expectRevert(IExecutionStrategy.WrongCaller.selector);
        // Call the function directly
        strategyTokenIdsRange.executeStrategyWithTakerAsk(takerAsk, makerBid);
    }

    function testMakerBidItemIdsLowerBandHigherThanUpperBand() public {
        _setUpUsers();
        _setUpNewStrategy();
        _setUpRoyalties(address(mockERC721), _standardRoyaltyFee);
        (makerBid, takerAsk) = _createMakerBidAndTakerAsk();

        uint256[] memory invalidItemIds = new uint256[](2);
        invalidItemIds[0] = 5;
        invalidItemIds[1] = 4;

        makerBid.itemIds = invalidItemIds;

        // Sign order
        signature = _signMakerBid(makerBid, makerUserPK);

        vm.expectRevert(IExecutionStrategy.OrderInvalid.selector);
        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerAsk(
            takerAsk,
            makerBid,
            signature,
            _emptyMerkleRoot,
            _emptyMerkleProof,
            _emptyReferrer
        );
    }

    function testTakerAskDuplicatedItemIds() public {
        _setUpUsers();
        _setUpNewStrategy();
        _setUpRoyalties(address(mockERC721), _standardRoyaltyFee);
        (makerBid, takerAsk) = _createMakerBidAndTakerAsk();

        uint256[] memory invalidItemIds = new uint256[](3);
        invalidItemIds[0] = 5;
        invalidItemIds[1] = 7;
        invalidItemIds[2] = 7;

        takerAsk.itemIds = invalidItemIds;

        // Sign order
        signature = _signMakerBid(makerBid, makerUserPK);

        vm.expectRevert(IExecutionStrategy.OrderInvalid.selector);
        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerAsk(
            takerAsk,
            makerBid,
            signature,
            _emptyMerkleRoot,
            _emptyMerkleProof,
            _emptyReferrer
        );
    }

    function testTakerAskUnsortedItemIds() public {
        _setUpUsers();
        _setUpNewStrategy();
        _setUpRoyalties(address(mockERC721), _standardRoyaltyFee);
        (makerBid, takerAsk) = _createMakerBidAndTakerAsk();

        uint256[] memory invalidItemIds = new uint256[](3);
        invalidItemIds[0] = 5;
        invalidItemIds[1] = 10;
        invalidItemIds[2] = 7;

        takerAsk.itemIds = invalidItemIds;

        // Sign order
        signature = _signMakerBid(makerBid, makerUserPK);

        vm.expectRevert(IExecutionStrategy.OrderInvalid.selector);
        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerAsk(
            takerAsk,
            makerBid,
            signature,
            _emptyMerkleRoot,
            _emptyMerkleProof,
            _emptyReferrer
        );
    }

    function testTakerAskSomeZeroAmount() public {
        _setUpUsers();
        _setUpNewStrategy();
        _setUpRoyalties(address(mockERC721), _standardRoyaltyFee);
        (makerBid, takerAsk) = _createMakerBidAndTakerAsk();

        uint256[] memory invalidAmounts = new uint256[](3);
        invalidAmounts[0] = 1;
        invalidAmounts[1] = 0;
        invalidAmounts[2] = 2;

        takerAsk.amounts = invalidAmounts;

        // Sign order
        signature = _signMakerBid(makerBid, makerUserPK);

        vm.expectRevert(IExecutionStrategy.OrderInvalid.selector);
        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerAsk(
            takerAsk,
            makerBid,
            signature,
            _emptyMerkleRoot,
            _emptyMerkleProof,
            _emptyReferrer
        );
    }

    function testTakerAskOfferedAmountNotEqualToDesiredAmount() public {
        _setUpUsers();
        _setUpNewStrategy();
        _setUpRoyalties(address(mockERC721), _standardRoyaltyFee);
        (makerBid, takerAsk) = _createMakerBidAndTakerAsk();

        uint256[] memory itemIds = new uint256[](2);
        itemIds[0] = 5;
        itemIds[1] = 10;

        takerAsk.itemIds = itemIds;

        uint256[] memory invalidAmounts = new uint256[](2);
        invalidAmounts[0] = 1;
        invalidAmounts[1] = 1;

        takerAsk.amounts = invalidAmounts;

        // Sign order
        signature = _signMakerBid(makerBid, makerUserPK);

        vm.expectRevert(IExecutionStrategy.OrderInvalid.selector);
        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerAsk(
            takerAsk,
            makerBid,
            signature,
            _emptyMerkleRoot,
            _emptyMerkleProof,
            _emptyReferrer
        );
    }
}
