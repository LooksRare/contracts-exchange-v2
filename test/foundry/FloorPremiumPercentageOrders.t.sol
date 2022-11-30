// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IOwnableTwoSteps} from "@looksrare/contracts-libs/contracts/interfaces/IOwnableTwoSteps.sol";
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";
import {IExecutionStrategy} from "../../contracts/interfaces/IExecutionStrategy.sol";
import {StrategyChainlinkPriceLatency} from "../../contracts/executionStrategies/StrategyChainlinkPriceLatency.sol";
import {StrategyChainlinkMultiplePriceFeeds} from "../../contracts/executionStrategies/StrategyChainlinkMultiplePriceFeeds.sol";
import {StrategyFloorPremium} from "../../contracts/executionStrategies/StrategyFloorPremium.sol";
import {MockChainlinkAggregator} from "../mock/MockChainlinkAggregator.sol";
import {FloorPremiumOrdersTest} from "./FloorPremiumOrders.t.sol";

/**
 * @notice The primary scenarios are tested in FloorPremiumFixedAmountOrdersTest
 */
contract FloorPremiumPercentageOrdersTest is FloorPremiumOrdersTest {
    function setUp() public override {
        super.setUp();
        _setIsFixedAmount(0);
    }

    function selectorTakerBid() internal pure override returns (bytes4) {
        return StrategyFloorPremium.executePercentagePremiumStrategyWithTakerBid.selector;
    }

    function testFloorPremiumDesiredSalePriceGreaterThanOrEqualToMinPrice() public {
        (, , , , , , address implementation) = looksRareProtocol.strategyInfo(2);
        strategyFloorPremium = StrategyFloorPremium(implementation);

        // Floor price = 9.7 ETH, premium = 1%, desired price = 9.797 ETH
        // Min price = 9.7 ETH
        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _createMakerAskAndTakerBid({
            premium: 100
        });

        signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.startPrank(_owner);
        strategyFloorPremium.setMaximumLatency(3600);
        strategyFloorPremium.setPriceFeed(address(mockERC721), AZUKI_PRICE_FEED);
        vm.stopPrank();

        (bool isValid, bytes4 errorSelector) = strategyFloorPremium.isValid(makerAsk);
        assertTrue(isValid);
        assertEq(errorSelector, bytes4(0));

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
        (, , , , , , address implementation) = looksRareProtocol.strategyInfo(2);
        strategyFloorPremium = StrategyFloorPremium(implementation);

        // Floor price = 9.7 ETH, premium = 1%, desired price = 9.797 ETH
        // Min price = 9.8 ETH
        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _createMakerAskAndTakerBid({
            premium: 100
        });

        makerAsk.minPrice = 9.8 ether;
        takerBid.maxPrice = makerAsk.minPrice;

        signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.startPrank(_owner);
        strategyFloorPremium.setMaximumLatency(3600);
        strategyFloorPremium.setPriceFeed(address(mockERC721), AZUKI_PRICE_FEED);
        vm.stopPrank();

        (bool isValid, bytes4 errorSelector) = strategyFloorPremium.isValid(makerAsk);
        assertTrue(isValid);
        assertEq(errorSelector, bytes4(0));

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
