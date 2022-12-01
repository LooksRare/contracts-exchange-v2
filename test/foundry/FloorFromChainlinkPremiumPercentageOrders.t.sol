// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";
import {StrategyFloorFromChainlink} from "../../contracts/executionStrategies/StrategyFloorFromChainlink.sol";
import {FloorFromChainlinkPremiumOrdersTest} from "./FloorFromChainlinkPremiumOrders.t.sol";

/**
 * @notice The primary scenarios are tested in FloorFromChainlinkPremiumFixedAmountOrdersTest
 */
contract FloorFromChainlinkPremiumPercentageOrdersTest is FloorFromChainlinkPremiumOrdersTest {
    function setUp() public override {
        _setIsFixedAmount(0);
        _setPremium(100);
        _setSelectorTakerBid(StrategyFloorFromChainlink.executePercentagePremiumStrategyWithTakerBid.selector);
        super.setUp();
    }

    function testFloorFromChainlinkPremiumPercentageDesiredSalePriceGreaterThanMinPrice() public {
        // Floor price = 9.7 ETH, premium = 1%, desired price = 9.797 ETH
        // Min price = 9.7 ETH
        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _createMakerAskAndTakerBid({
            premium: premium
        });

        _testFloorFromChainlinkPremiumPercentageDesiredSalePriceGreaterThanOrEqualToMinPrice(makerAsk, takerBid);
    }

    function testFloorFromChainlinkPremiumPercentageDesiredSalePriceEqualToMinPrice() public {
        // Floor price = 9.7 ETH, premium = 1%, desired price = 9.797 ETH
        // Min price = 9.7 ETH
        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _createMakerAskAndTakerBid({
            premium: premium
        });
        makerAsk.minPrice = 9.797 ether;

        _testFloorFromChainlinkPremiumPercentageDesiredSalePriceGreaterThanOrEqualToMinPrice(makerAsk, takerBid);
    }

    function _testFloorFromChainlinkPremiumPercentageDesiredSalePriceGreaterThanOrEqualToMinPrice(
        OrderStructs.MakerAsk memory makerAsk,
        OrderStructs.TakerBid memory takerBid
    ) public {
        signature = _signMakerAsk(makerAsk, makerUserPK);

        _setPriceFeed();

        _assertOrderValid(makerAsk);

        _executeTakerBid(takerBid, makerAsk, signature);

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(1), takerUser);
        // Taker bid user pays the whole price
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser - 9.797 ether);
        // Maker ask user receives 98% of the whole price (2% protocol)
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser + 9.60106 ether);
    }

    function testFloorFromChainlinkPremiumPercentageDesiredSalePriceLessThanMinPrice() public {
        (, , , , , , address implementation) = looksRareProtocol.strategyInfo(1);
        strategyFloorFromChainlink = StrategyFloorFromChainlink(implementation);

        // Floor price = 9.7 ETH, premium = 1%, desired price = 9.797 ETH
        // Min price = 9.8 ETH
        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _createMakerAskAndTakerBid({
            premium: premium
        });

        makerAsk.minPrice = 9.8 ether;
        takerBid.maxPrice = makerAsk.minPrice;

        signature = _signMakerAsk(makerAsk, makerUserPK);

        _setPriceFeed();

        _assertOrderValid(makerAsk);

        _executeTakerBid(takerBid, makerAsk, signature);

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(1), takerUser);

        // Taker bid user pays the whole price
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser - 9.8 ether);
        // Maker ask user receives 98% of the whole price (2% protocol)
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser + 9.604 ether);
    }
}
