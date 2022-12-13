// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Libraries and interfaces
import {OrderStructs} from "../../../contracts/libraries/OrderStructs.sol";
import {IExecutionStrategy} from "../../../contracts/interfaces/IExecutionStrategy.sol";
import {IExecutionManager} from "../../../contracts/interfaces/IExecutionManager.sol";

// Strategies
import {StrategyFloorFromChainlink} from "../../../contracts/executionStrategies/StrategyFloorFromChainlink.sol";

// Other tests
import {FloorFromChainlinkDiscountOrdersTest} from "./FloorFromChainlinkDiscountOrders.t.sol";

contract FloorFromChainlinkDiscountFixedAmountOrdersTest is FloorFromChainlinkDiscountOrdersTest {
    function setUp() public override {
        _setIsFixedAmount(1);
        _setDiscount(0.1 ether);
        _setValidityFunctionSelector(StrategyFloorFromChainlink.isFixedDiscountMakerBidValid.selector);
        _setSelector(StrategyFloorFromChainlink.executeFixedDiscountStrategyWithTakerAsk.selector, false);
        super.setUp();
    }

    function testInactiveStrategy() public {
        (makerBid, takerAsk) = _createMakerBidAndTakerAsk({discount: 0.1 ether});

        makerBid.maxPrice = 9.5 ether;
        takerAsk.minPrice = 9.5 ether;

        signature = _signMakerBid(makerBid, makerUserPK);

        _setPriceFeed();

        _assertOrderValid(makerBid);

        vm.prank(_owner);
        looksRareProtocol.updateStrategy(1, _standardProtocolFee, _minTotalFee, false);

        vm.expectRevert(abi.encodeWithSelector(IExecutionManager.StrategyNotAvailable.selector, uint16(1)));
        _executeTakerAsk(takerAsk, makerBid, signature);
    }

    function testFloorFromChainlinkDiscountFixedAmountDesiredDiscountedPriceGreaterThanOrEqualToMaxPrice() public {
        // Floor price = 9.7 ETH, discount = 0.1 ETH, desired price = 9.6 ETH
        // Max price = 9.5 ETH
        (makerBid, takerAsk) = _createMakerBidAndTakerAsk({discount: 0.1 ether});

        makerBid.maxPrice = 9.5 ether;
        takerAsk.minPrice = 9.5 ether;

        signature = _signMakerBid(makerBid, makerUserPK);

        _setPriceFeed();

        _assertOrderValid(makerBid);

        _executeTakerAsk(takerAsk, makerBid, signature);

        // Maker user has received the asset
        assertEq(mockERC721.ownerOf(1), makerUser);

        // Maker bid user pays the whole price
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser - 9.5 ether);
        // Taker ask user receives 98% of the whole price (2% protocol)
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser + 9.31 ether);
    }

    function testFloorFromChainlinkDiscountFixedAmountDesiredDiscountedPriceLessThanMaxPrice() public {
        // Floor price = 9.7 ETH, discount = 0.3 ETH, desired price = 9.4 ETH
        // Max price = 9.5 ETH
        (makerBid, takerAsk) = _createMakerBidAndTakerAsk({discount: 0.3 ether});

        makerBid.maxPrice = 9.41 ether;

        signature = _signMakerBid(makerBid, makerUserPK);

        _setPriceFeed();

        _assertOrderValid(makerBid);

        _executeTakerAsk(takerAsk, makerBid, signature);

        // Maker user has received the asset
        assertEq(mockERC721.ownerOf(1), makerUser);

        // Maker bid user pays the whole price
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser - 9.4 ether);
        // Taker ask user receives 97% of the whole price (2% protocol)
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser + 9.212 ether);
    }

    function testFloorFromChainlinkDiscountFixedAmountDesiredDiscountedAmountGreaterThanOrEqualToFloorPrice() public {
        // Floor price = 9.7 ETH, discount = 9.7 ETH, desired price = 0 ETH
        // Max price = 0 ETH
        (makerBid, takerAsk) = _createMakerBidAndTakerAsk({discount: 9.7 ether});

        signature = _signMakerBid(makerBid, makerUserPK);

        _setPriceFeed();

        bytes4 errorSelector = _assertOrderInvalid(makerBid);

        vm.expectRevert(errorSelector);
        _executeTakerAsk(takerAsk, makerBid, signature);

        // Floor price = 9.7 ETH, discount = 9.8 ETH, desired price = -0.1 ETH
        // Max price = -0.1 ETH
        makerBid.additionalParameters = abi.encode(9.8 ether);
        signature = _signMakerBid(makerBid, makerUserPK);

        vm.expectRevert(IExecutionStrategy.OrderInvalid.selector);
        _executeTakerAsk(takerAsk, makerBid, signature);
    }
}
