// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";
import {StrategyFloor} from "../../contracts/executionStrategies/StrategyFloor.sol";
import {FloorPremiumOrdersTest} from "./FloorPremiumOrders.t.sol";

/**
 * @notice The primary scenarios are tested in FloorPremiumFixedAmountOrdersTest
 */
contract FloorPremiumPercentageOrdersTest is FloorPremiumOrdersTest {
    function setUp() public override {
        _setIsFixedAmount(0);
        _setPremium(100);
        _setSelectorTakerBid(StrategyFloor.executePercentagePremiumStrategyWithTakerBid.selector);
        super.setUp();
    }

    function testFloorPremiumDesiredSalePriceGreaterThanMinPrice() public {
        // Floor price = 9.7 ETH, premium = 1%, desired price = 9.797 ETH
        // Min price = 9.7 ETH
        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _createMakerAskAndTakerBid({
            premium: premium
        });

        _testFloorPremiumDesiredSalePriceGreaterThanOrEqualToMinPrice(makerAsk, takerBid);
    }

    function testFloorPremiumDesiredSalePriceEqualToMinPrice() public {
        // Floor price = 9.7 ETH, premium = 1%, desired price = 9.797 ETH
        // Min price = 9.7 ETH
        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _createMakerAskAndTakerBid({
            premium: premium
        });
        makerAsk.minPrice = 9.797 ether;

        _testFloorPremiumDesiredSalePriceGreaterThanOrEqualToMinPrice(makerAsk, takerBid);
    }

    function _testFloorPremiumDesiredSalePriceGreaterThanOrEqualToMinPrice(
        OrderStructs.MakerAsk memory makerAsk,
        OrderStructs.TakerBid memory takerBid
    ) public {
        signature = _signMakerAsk(makerAsk, makerUserPK);

        _setPriceFeed();

        bytes4 errorSelector = _assertOrderValid(makerAsk);

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
        // Taker bid user pays the whole price
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser - 9.797 ether);
        // Maker ask user receives 98% of the whole price (2% protocol)
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser + 9.60106 ether);
    }

    function testFloorPremiumDesiredSalePriceLessThanMinPrice() public {
        (, , , , , , address implementation) = looksRareProtocol.strategyInfo(1);
        strategyFloor = StrategyFloor(implementation);

        // Floor price = 9.7 ETH, premium = 1%, desired price = 9.797 ETH
        // Min price = 9.8 ETH
        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _createMakerAskAndTakerBid({
            premium: premium
        });

        makerAsk.minPrice = 9.8 ether;
        takerBid.maxPrice = makerAsk.minPrice;

        signature = _signMakerAsk(makerAsk, makerUserPK);

        _setPriceFeed();

        bytes4 errorSelector = _assertOrderValid(makerAsk);

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

        // Taker bid user pays the whole price
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser - 9.8 ether);
        // Maker ask user receives 98% of the whole price (2% protocol)
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser + 9.604 ether);
    }
}
