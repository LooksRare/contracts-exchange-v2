// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Libraries and interfaces
import {OrderStructs} from "../../../../contracts/libraries/OrderStructs.sol";
import {IExecutionManager} from "../../../../contracts/interfaces/IExecutionManager.sol";

// Errors and constants
import {DiscountGreaterThanFloorPrice} from "../../../../contracts/errors/ChainlinkErrors.sol";
import {MAKER_ORDER_TEMPORARILY_INVALID_NON_STANDARD_SALE} from "../../../../contracts/constants/ValidationCodeConstants.sol";

// Strategies
import {StrategyChainlinkFloor} from "../../../../contracts/executionStrategies/Chainlink/StrategyChainlinkFloor.sol";

// Other tests
import {FloorFromChainlinkDiscountOrdersTest} from "./FloorFromChainlinkDiscountOrders.t.sol";

contract FloorFromChainlinkDiscountFixedAmountOrdersTest is FloorFromChainlinkDiscountOrdersTest {
    function setUp() public override {
        _setIsFixedAmount(1);
        _setDiscount(0.1 ether);
        _setSelector(StrategyChainlinkFloor.executeFixedDiscountCollectionOfferStrategyWithTakerAsk.selector, true);
        super.setUp();
    }

    function testInactiveStrategy() public {
        (OrderStructs.MakerBid memory makerBid, OrderStructs.Taker memory takerAsk) = _createMakerBidAndTakerAsk({
            discount: 0.1 ether
        });

        makerBid.maxPrice = 9.5 ether;
        takerAsk.additionalParameters = abi.encode(42, 9.5 ether);

        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        _setPriceFeed();

        _assertOrderIsValid(makerBid);
        _assertValidMakerBidOrder(makerBid, signature);

        vm.prank(_owner);
        looksRareProtocol.updateStrategy(1, false, _standardProtocolFeeBp, _minTotalFeeBp);

        vm.expectRevert(abi.encodeWithSelector(IExecutionManager.StrategyNotAvailable.selector, 1));
        _executeTakerAsk(takerAsk, makerBid, signature);
    }

    function testFloorFromChainlinkDiscountFixedAmountDesiredDiscountedPriceGreaterThanOrEqualToMaxPrice() public {
        // Floor price = 9.7 ETH, discount = 0.1 ETH, desired price = 9.6 ETH
        // Max price = 9.5 ETH
        (OrderStructs.MakerBid memory makerBid, OrderStructs.Taker memory takerAsk) = _createMakerBidAndTakerAsk({
            discount: 0.1 ether
        });

        makerBid.maxPrice = 9.5 ether;
        takerAsk.additionalParameters = abi.encode(42, 9.5 ether);

        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        _setPriceFeed();

        _assertOrderIsValid(makerBid);
        _assertValidMakerBidOrder(makerBid, signature);

        _executeTakerAsk(takerAsk, makerBid, signature);

        // Maker user has received the asset
        assertEq(mockERC721.ownerOf(42), makerUser);

        // Maker bid user pays the whole price
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser - 9.5 ether);
        // Taker ask user receives 98% of the whole price (2% protocol)
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser + 9.31 ether);
    }

    function testFloorFromChainlinkDiscountFixedAmountDesiredDiscountedPriceLessThanMaxPrice() public {
        // Floor price = 9.7 ETH, discount = 0.3 ETH, desired price = 9.4 ETH
        // Max price = 9.5 ETH
        (OrderStructs.MakerBid memory makerBid, OrderStructs.Taker memory takerAsk) = _createMakerBidAndTakerAsk({
            discount: 0.3 ether
        });

        makerBid.maxPrice = 9.41 ether;

        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        _setPriceFeed();

        _assertOrderIsValid(makerBid);
        _assertValidMakerBidOrder(makerBid, signature);

        _executeTakerAsk(takerAsk, makerBid, signature);

        // Maker user has received the asset
        assertEq(mockERC721.ownerOf(42), makerUser);

        // Maker bid user pays the whole price
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser - 9.4 ether);
        // Taker ask user receives 97% of the whole price (2% protocol)
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser + 9.212 ether);
    }

    function testFloorFromChainlinkDiscountFixedAmountDesiredDiscountedAmountGreaterThanFloorPrice() public {
        // Floor price = 9.7 ETH, discount = 9.7 ETH, desired price = 0 ETH
        // Max price = 0 ETH
        (OrderStructs.MakerBid memory makerBid, OrderStructs.Taker memory takerAsk) = _createMakerBidAndTakerAsk({
            discount: 9.7 ether
        });

        makerBid.additionalParameters = abi.encode(9.7 ether + 1);

        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        _setPriceFeed();

        (bool isValid, bytes4 errorSelector) = strategyFloorFromChainlink.isMakerBidValid(makerBid, selector);
        assertFalse(isValid);
        assertEq(errorSelector, DiscountGreaterThanFloorPrice.selector);

        _doesMakerBidOrderReturnValidationCode(makerBid, signature, MAKER_ORDER_TEMPORARILY_INVALID_NON_STANDARD_SALE);

        vm.expectRevert(errorSelector);
        _executeTakerAsk(takerAsk, makerBid, signature);

        // Floor price = 9.7 ETH, discount = 9.8 ETH, desired price = -0.1 ETH
        // Max price = -0.1 ETH
        makerBid.additionalParameters = abi.encode(9.8 ether);
        signature = _signMakerBid(makerBid, makerUserPK);

        (isValid, errorSelector) = strategyFloorFromChainlink.isMakerBidValid(makerBid, selector);
        assertFalse(isValid);
        assertEq(errorSelector, DiscountGreaterThanFloorPrice.selector);

        vm.expectRevert(errorSelector);
        _executeTakerAsk(takerAsk, makerBid, signature);
    }
}
