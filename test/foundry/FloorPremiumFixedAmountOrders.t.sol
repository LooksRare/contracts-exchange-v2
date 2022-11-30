// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";
import {StrategyFloor} from "../../contracts/executionStrategies/StrategyFloor.sol";
import {FloorPremiumOrdersTest} from "./FloorPremiumOrders.t.sol";

contract FloorPremiumFixedAmountOrdersTest is FloorPremiumOrdersTest {
    function setUp() public override {
        super.setUp();
        _setPremium(0.1 ether);
        _setIsFixedAmount(1);
    }

    function testFloorPremiumDesiredSalePriceGreaterThanMinPrice() public {
        (, , , , , , address implementation) = looksRareProtocol.strategyInfo(1);
        strategyFloor = StrategyFloor(implementation);

        // Floor price = 9.7 ETH, premium = 0.1 ETH, desired price = 9.8 ETH
        // Min price = 9.7 ETH
        (makerAsk, takerBid) = _createMakerAskAndTakerBid({premium: premium});
        _testFloorPremiumDesiredSalePriceGreaterThanOrEqualToMinPrice(makerAsk, takerBid);
    }

    function testFloorPremiumDesiredSalePriceEqualToMinPrice() public {
        (, , , , , , address implementation) = looksRareProtocol.strategyInfo(1);
        strategyFloor = StrategyFloor(implementation);

        // Floor price = 9.7 ETH, premium = 0.1 ETH, desired price = 9.8 ETH
        // Min price = 9.8 ETH
        (makerAsk, takerBid) = _createMakerAskAndTakerBid({premium: premium});
        makerAsk.minPrice = 9.8 ether;
        _testFloorPremiumDesiredSalePriceGreaterThanOrEqualToMinPrice(makerAsk, takerBid);
    }

    function _testFloorPremiumDesiredSalePriceGreaterThanOrEqualToMinPrice(
        OrderStructs.MakerAsk memory makerAsk,
        OrderStructs.TakerBid memory takerBid
    ) public {
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

    function testFloorPremiumDesiredSalePriceLessThanMinPrice() public {
        (, , , , , , address implementation) = looksRareProtocol.strategyInfo(1);
        strategyFloor = StrategyFloor(implementation);

        // Floor price = 9.7 ETH, premium = 0.1 ETH, desired price = 9.8 ETH
        // Min price = 9.9 ETH
        (makerAsk, takerBid) = _createMakerAskAndTakerBid({premium: premium});

        makerAsk.minPrice = 9.9 ether;
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
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser - 9.9 ether);
        // Maker ask user receives 98% of the whole price (2% protocol)
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser + 9.702 ether);
    }

    function selectorTakerBid() internal pure override returns (bytes4) {
        return StrategyFloor.executeFixedPremiumStrategyWithTakerBid.selector;
    }
}
