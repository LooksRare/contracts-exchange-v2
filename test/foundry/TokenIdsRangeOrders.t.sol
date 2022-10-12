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
        uint256[] memory itemIds = new uint256[](2);
        itemIds[0] = 5;
        itemIds[1] = 10;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 3;

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
            itemIds: itemIds,
            amounts: amounts
        });

        mockERC721.mint(takerUser, 4);
        mockERC721.mint(takerUser, 5);
        mockERC721.mint(takerUser, 7);
        mockERC721.mint(takerUser, 10);
        mockERC721.mint(takerUser, 11);

        takerAsk = OrderStructs.TakerAsk({
            recipient: takerUser,
            minNetRatio: makerAsk.minNetRatio,
            minPrice: makerBid.maxPrice,
            itemIds: itemIds, // just a temporary placeholder, it needs to be replaced in each test
            amounts: amounts, // just a temporary placeholder, it needs to be replaced in each test
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

        uint256[] memory itemIds = new uint256[](3);
        itemIds[0] = 5;
        itemIds[1] = 7;
        itemIds[2] = 10;

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 1;
        amounts[1] = 1;
        amounts[2] = 1;

        takerAsk.itemIds = itemIds;
        takerAsk.amounts = amounts;

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

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(5), makerUser);
        assertEq(mockERC721.ownerOf(7), makerUser);
        assertEq(mockERC721.ownerOf(10), makerUser);

        // Taker bid user pays the whole price
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser - 1 ether);
        // Maker ask user receives 97% of the whole price (2% protocol + 1% royalties)
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser + (1 ether * 9700) / 10000);
    }

    function testCallerNotLooksRareProtocol() public {
        _setUpUsers();
        _setUpNewStrategy();
        _setUpRoyalties(address(mockERC721), _standardRoyaltyFee);
        (makerBid, takerAsk) = _createMakerBidAndTakerAsk();

        uint256[] memory itemIds = new uint256[](3);
        itemIds[0] = 5;
        itemIds[1] = 7;
        itemIds[2] = 10;

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 1;
        amounts[1] = 1;
        amounts[2] = 1;

        takerAsk.itemIds = itemIds;
        takerAsk.amounts = amounts;

        // Sign order
        signature = _signMakerBid(makerBid, makerUserPK);

        vm.expectRevert(IExecutionStrategy.WrongCaller.selector);
        // Call the function directly
        strategyTokenIdsRange.executeStrategyWithTakerAsk(takerAsk, makerBid);
    }

    // function testZeroItemIdsLength() public {
    //     _setUpUsers();
    //     _setUpNewStrategy();
    //     _setUpRoyalties(address(mockERC721), _standardRoyaltyFee);
    //     (makerAsk, takerBid) = _createMakerAskAndTakerBid(0, 0);

    //     // Sign order
    //     signature = _signMakerAsk(makerAsk, makerUserPK);

    //     vm.expectRevert(IExecutionStrategy.OrderInvalid.selector);
    //     vm.prank(takerUser);
    //     // Execute taker bid transaction
    //     looksRareProtocol.executeTakerBid(
    //         takerBid,
    //         makerAsk,
    //         signature,
    //         _emptyMerkleRoot,
    //         _emptyMerkleProof,
    //         _emptyReferrer
    //     );
    // }

    // function testItemIdsAndAmountsLengthMismatch() public {
    //     _setUpUsers();
    //     _setUpNewStrategy();
    //     _setUpRoyalties(address(mockERC721), _standardRoyaltyFee);
    //     (makerAsk, takerBid) = _createMakerAskAndTakerBid(1, 2);

    //     // Sign order
    //     signature = _signMakerAsk(makerAsk, makerUserPK);

    //     vm.expectRevert(IExecutionStrategy.OrderInvalid.selector);
    //     vm.prank(takerUser);
    //     // Execute taker bid transaction
    //     looksRareProtocol.executeTakerBid(
    //         takerBid,
    //         makerAsk,
    //         signature,
    //         _emptyMerkleRoot,
    //         _emptyMerkleProof,
    //         _emptyReferrer
    //     );
    // }

    // function testItemIdsMismatch() public {
    //     _setUpUsers();
    //     _setUpNewStrategy();
    //     _setUpRoyalties(address(mockERC721), _standardRoyaltyFee);
    //     (makerAsk, takerBid) = _createMakerAskAndTakerBid(1, 1);

    //     uint256[] memory itemIds = new uint256[](1);
    //     itemIds[0] = 2;

    //     // Bidder bidding on something else
    //     takerBid.itemIds = itemIds;

    //     // Sign order
    //     signature = _signMakerAsk(makerAsk, makerUserPK);

    //     vm.expectRevert(IExecutionStrategy.OrderInvalid.selector);
    //     vm.prank(takerUser);
    //     // Execute taker bid transaction
    //     looksRareProtocol.executeTakerBid(
    //         takerBid,
    //         makerAsk,
    //         signature,
    //         _emptyMerkleRoot,
    //         _emptyMerkleProof,
    //         _emptyReferrer
    //     );
    // }

    // function testZeroAmount() public {
    //     _setUpUsers();
    //     _setUpNewStrategy();
    //     _setUpRoyalties(address(mockERC721), _standardRoyaltyFee);
    //     (makerAsk, takerBid) = _createMakerAskAndTakerBid(1, 1);

    //     uint256[] memory amounts = new uint256[](1);
    //     amounts[0] = 0;
    //     makerAsk.amounts = amounts;

    //     // Sign order
    //     signature = _signMakerAsk(makerAsk, makerUserPK);

    //     vm.expectRevert(IExecutionStrategy.OrderInvalid.selector);
    //     vm.prank(takerUser);
    //     // Execute taker bid transaction
    //     looksRareProtocol.executeTakerBid(
    //         takerBid,
    //         makerAsk,
    //         signature,
    //         _emptyMerkleRoot,
    //         _emptyMerkleProof,
    //         _emptyReferrer
    //     );
    // }

    // function testStartPriceTooLow() public {
    //     _setUpUsers();
    //     _setUpNewStrategy();
    //     _setUpRoyalties(address(mockERC721), _standardRoyaltyFee);
    //     (makerAsk, takerBid) = _createMakerAskAndTakerBid(1, 1);

    //     // startPrice is 10 ether
    //     makerAsk.minPrice = 10 ether + 1 wei;

    //     // Sign order
    //     signature = _signMakerAsk(makerAsk, makerUserPK);

    //     vm.expectRevert(IExecutionStrategy.OrderInvalid.selector);
    //     vm.prank(takerUser);
    //     // Execute taker bid transaction
    //     looksRareProtocol.executeTakerBid(
    //         takerBid,
    //         makerAsk,
    //         signature,
    //         _emptyMerkleRoot,
    //         _emptyMerkleProof,
    //         _emptyReferrer
    //     );
    // }

    // function testTakerBidTooLow(uint256 elapsedTime) public {
    //     vm.assume(elapsedTime <= 3600);

    //     _setUpUsers();
    //     _setUpNewStrategy();
    //     _setUpRoyalties(address(mockERC721), _standardRoyaltyFee);
    //     (makerAsk, takerBid) = _createMakerAskAndTakerBid(1, 1);

    //     uint256 currentPrice = startPrice - decayPerSecond * elapsedTime;
    //     takerBid.maxPrice = currentPrice - 1 wei;

    //     // Sign order
    //     signature = _signMakerAsk(makerAsk, makerUserPK);

    //     vm.expectRevert(StrategyDutchAuction.BidTooLow.selector);
    //     vm.prank(takerUser);
    //     // Execute taker bid transaction
    //     looksRareProtocol.executeTakerBid(
    //         takerBid,
    //         makerAsk,
    //         signature,
    //         _emptyMerkleRoot,
    //         _emptyMerkleProof,
    //         _emptyReferrer
    //     );
    // }
}
