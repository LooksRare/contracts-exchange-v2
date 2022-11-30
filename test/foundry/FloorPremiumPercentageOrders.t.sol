// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";
import {IExecutionStrategy} from "../../contracts/interfaces/IExecutionStrategy.sol";
import {StrategyChainlinkPriceLatency} from "../../contracts/executionStrategies/StrategyChainlinkPriceLatency.sol";
import {StrategyChainlinkMultiplePriceFeeds} from "../../contracts/executionStrategies/StrategyChainlinkMultiplePriceFeeds.sol";
import {StrategyFloor} from "../../contracts/executionStrategies/StrategyFloor.sol";
import {MockChainlinkAggregator} from "../mock/MockChainlinkAggregator.sol";
import {FloorOrdersTest} from "./FloorOrders.t.sol";

/**
 * @notice The primary scenarios are tested in FloorPremiumFixedAmountOrdersTest
 */
contract FloorPremiumPercentageOrdersTest is FloorOrdersTest {
    function setUp() public override {
        super.setUp();
        _setIsFixedAmount(0);
    }

    function testFloorPremiumDesiredSalePriceGreaterThanOrEqualToMinPrice() public {
        (, , , , , , address implementation) = looksRareProtocol.strategyInfo(1);
        strategyFloor = StrategyFloor(implementation);

        // Floor price = 9.7 ETH, premium = 1%, desired price = 9.797 ETH
        // Min price = 9.7 ETH
        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _createMakerAskAndTakerBid({
            premium: 100
        });

        signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.startPrank(_owner);
        strategyFloor.setMaximumLatency(3600);
        strategyFloor.setPriceFeed(address(mockERC721), AZUKI_PRICE_FEED);
        vm.stopPrank();

        (bool isValid, bytes4 errorSelector) = strategyFloor.isMakerAskValid(makerAsk);
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
        (, , , , , , address implementation) = looksRareProtocol.strategyInfo(1);
        strategyFloor = StrategyFloor(implementation);

        // Floor price = 9.7 ETH, premium = 1%, desired price = 9.797 ETH
        // Min price = 9.8 ETH
        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _createMakerAskAndTakerBid({
            premium: 100
        });

        makerAsk.minPrice = 9.8 ether;
        takerBid.maxPrice = makerAsk.minPrice;

        signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.startPrank(_owner);
        strategyFloor.setMaximumLatency(3600);
        strategyFloor.setPriceFeed(address(mockERC721), AZUKI_PRICE_FEED);
        vm.stopPrank();

        (bool isValid, bytes4 errorSelector) = strategyFloor.isMakerAskValid(makerAsk);
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

    function selectorTakerBid() internal pure override returns (bytes4) {
        return StrategyFloor.executePercentagePremiumStrategyWithTakerBid.selector;
    }
}
