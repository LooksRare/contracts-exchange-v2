// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Libraries and interfaces
import {OrderStructs} from "../../../contracts/libraries/OrderStructs.sol";
import {IExecutionManager} from "../../../contracts/interfaces/IExecutionManager.sol";

// Strategies
import {StrategyFloorFromChainlink} from "../../../contracts/executionStrategies/StrategyFloorFromChainlink.sol";

// Other tests
import {FloorFromChainlinkPremiumOrdersTest} from "./FloorFromChainlinkPremiumOrders.t.sol";

/**
 * @notice The primary scenarios are tested in FloorFromChainlinkPremiumFixedAmountOrdersTest
 */
contract FloorFromChainlinkPremiumBasisPointsOrdersTest is FloorFromChainlinkPremiumOrdersTest {
    function setUp() public override {
        _setIsFixedAmount(0);
        _setPremium(100);
        _setSelector(StrategyFloorFromChainlink.executeBasisPointsPremiumStrategyWithTakerBid.selector, false);
        super.setUp();
    }

    function testInactiveStrategy() public {
        (makerAsk, takerBid) = _createMakerAskAndTakerBid({premium: premium});

        signature = _signMakerAsk(makerAsk, makerUserPK);

        _setPriceFeed();

        vm.prank(_owner);
        looksRareProtocol.updateStrategy(1, _standardProtocolFee, _minTotalFee, false);

        _assertOrderValid(makerAsk);

        vm.expectRevert(abi.encodeWithSelector(IExecutionManager.StrategyNotAvailable.selector, uint16(1)));
        _executeTakerBid();
    }

    function testFloorFromChainlinkPremiumBasisPointsDesiredSalePriceGreaterThanMinPrice() public {
        // Floor price = 9.7 ETH, premium = 1%, desired price = 9.797 ETH
        // Min price = 9.7 ETH
        (makerAsk, takerBid) = _createMakerAskAndTakerBid({premium: premium});

        _testFloorFromChainlinkPremiumBasisPointsDesiredSalePriceGreaterThanOrEqualToMinPrice();
    }

    function testFloorFromChainlinkPremiumBasisPointsDesiredSalePriceEqualToMinPrice() public {
        // Floor price = 9.7 ETH, premium = 1%, desired price = 9.797 ETH
        // Min price = 9.7 ETH
        (makerAsk, takerBid) = _createMakerAskAndTakerBid({premium: premium});
        makerAsk.minPrice = 9.797 ether;

        _testFloorFromChainlinkPremiumBasisPointsDesiredSalePriceGreaterThanOrEqualToMinPrice();
    }

    function _testFloorFromChainlinkPremiumBasisPointsDesiredSalePriceGreaterThanOrEqualToMinPrice() private {
        signature = _signMakerAsk(makerAsk, makerUserPK);

        _setPriceFeed();
        _assertOrderValid(makerAsk);
        _executeTakerBid();

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(1), takerUser);
        // Taker bid user pays the whole price
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser - 9.797 ether);
        // Maker ask user receives 98% of the whole price (2% protocol)
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser + 9.60106 ether);
    }

    function testFloorFromChainlinkPremiumBasisPointsDesiredSalePriceLessThanMinPrice() public {
        (, , , , , , address implementation) = looksRareProtocol.strategyInfo(1);
        strategyFloorFromChainlink = StrategyFloorFromChainlink(implementation);

        // Floor price = 9.7 ETH, premium = 1%, desired price = 9.797 ETH
        // Min price = 9.8 ETH
        (makerAsk, takerBid) = _createMakerAskAndTakerBid({premium: premium});

        makerAsk.minPrice = 9.8 ether;
        takerBid.maxPrice = makerAsk.minPrice;

        signature = _signMakerAsk(makerAsk, makerUserPK);

        _setPriceFeed();
        _assertOrderValid(makerAsk);
        _executeTakerBid();

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(1), takerUser);

        // Taker bid user pays the whole price
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser - 9.8 ether);
        // Maker ask user receives 98% of the whole price (2% protocol)
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser + 9.604 ether);
    }
}
