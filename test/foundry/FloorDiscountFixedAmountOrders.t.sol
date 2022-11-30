// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";
import {IExecutionStrategy} from "../../contracts/interfaces/IExecutionStrategy.sol";
import {StrategyFloor} from "../../contracts/executionStrategies/StrategyFloor.sol";
import {FloorDiscountOrdersTest} from "./FloorDiscountOrders.t.sol";

contract FloorDiscountFixedAmountOrdersTest is FloorDiscountOrdersTest {
    function setUp() public override {
        _setIsFixedAmount(1);
        _setDiscount(0.1 ether);
        _setValidityFunctionSelector(StrategyFloor.isFixedDiscountMakerBidValid.selector);
        _setSelectorTakerAsk(StrategyFloor.executeFixedDiscountStrategyWithTakerAsk.selector);
        super.setUp();
    }

    function testFloorDiscountFixedAmountDesiredDiscountedPriceGreaterThanOrEqualToMaxPrice() public {
        // Floor price = 9.7 ETH, discount = 0.1 ETH, desired price = 9.6 ETH
        // Max price = 9.5 ETH
        (makerBid, takerAsk) = _createMakerBidAndTakerAsk({discount: 0.1 ether});

        makerBid.maxPrice = 9.5 ether;
        takerAsk.minPrice = 9.5 ether;

        signature = _signMakerBid(makerBid, makerUserPK);

        _setPriceFeed();

        _assertOrderValid(makerBid);

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

        // Maker user has received the asset
        assertEq(mockERC721.ownerOf(1), makerUser);

        // Maker bid user pays the whole price
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser - 9.5 ether);
        // Taker ask user receives 98% of the whole price (2% protocol)
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser + 9.31 ether);
    }

    function testFloorDiscountFixedAmountDesiredDiscountedPriceLessThanMaxPrice() public {
        // Floor price = 9.7 ETH, discount = 0.3 ETH, desired price = 9.4 ETH
        // Max price = 9.5 ETH
        (makerBid, takerAsk) = _createMakerBidAndTakerAsk({discount: 0.3 ether});

        takerAsk.minPrice = 9.4 ether;

        signature = _signMakerBid(makerBid, makerUserPK);

        _setPriceFeed();

        _assertOrderValid(makerBid);

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

        // Maker user has received the asset
        assertEq(mockERC721.ownerOf(1), makerUser);

        // Maker bid user pays the whole price
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser - 9.4 ether);
        // Taker ask user receives 97% of the whole price (2% protocol)
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser + 9.212 ether);
    }

    function testFloorDiscountFixedAmountDesiredDiscountedAmountGreaterThanOrEqualToFloorPrice() public {
        // Floor price = 9.7 ETH, discount = 9.7 ETH, desired price = 0 ETH
        // Max price = 0 ETH
        (makerBid, takerAsk) = _createMakerBidAndTakerAsk({discount: 9.7 ether});

        signature = _signMakerBid(makerBid, makerUserPK);

        _setPriceFeed();

        bytes4 errorSelector = _assertOrderInvalid(makerBid);

        vm.expectRevert(errorSelector);
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

        // Floor price = 9.7 ETH, discount = 9.8 ETH, desired price = -0.1 ETH
        // Max price = -0.1 ETH
        makerBid.additionalParameters = abi.encode(9.8 ether);
        signature = _signMakerBid(makerBid, makerUserPK);

        vm.expectRevert(IExecutionStrategy.OrderInvalid.selector);
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
}
