// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Libraries and interfaces
import {OrderStructs} from "../../../../contracts/libraries/OrderStructs.sol";
import {IExecutionManager} from "../../../../contracts/interfaces/IExecutionManager.sol";

// Strategies
import {StrategyChainlinkFloor} from "../../../../contracts/executionStrategies/Chainlink/StrategyChainlinkFloor.sol";

// Other tests
import {FloorFromChainlinkPremiumOrdersTest} from "./FloorFromChainlinkPremiumOrders.t.sol";

// Errors and constants
import {STRATEGY_NOT_ACTIVE} from "../../../../contracts/constants/ValidationCodeConstants.sol";

contract FloorFromChainlinkPremiumFixedAmountOrdersTest is FloorFromChainlinkPremiumOrdersTest {
    function setUp() public override {
        _setPremium(0.1 ether);
        _setIsFixedAmount(1);
        _setSelector(StrategyChainlinkFloor.executeFixedPremiumStrategyWithTakerBid.selector, false);
        super.setUp();
    }

    function test_RevertIf_InactiveStrategy() public {
        (OrderStructs.Maker memory makerAsk, OrderStructs.Taker memory takerBid) = _createMakerAskAndTakerBid({
            premium: premium
        });
        bytes memory signature = _signMakerOrder(makerAsk, makerUserPK);

        _setPriceFeed();

        vm.prank(_owner);
        looksRareProtocol.updateStrategy(1, false, _standardProtocolFeeBp, _minTotalFeeBp);

        _assertOrderIsValid(makerAsk);
        _assertMakerOrderReturnValidationCode(makerAsk, signature, STRATEGY_NOT_ACTIVE);

        vm.expectRevert(abi.encodeWithSelector(IExecutionManager.StrategyNotAvailable.selector, 1));
        _executeTakerBid(takerBid, makerAsk, signature);
    }

    function test_FloorFromChainlinkPremiumFixedAmountDesiredSalePriceGreaterThanMinPrice() public {
        (, , , , , , address implementation) = looksRareProtocol.strategyInfo(1);
        strategyFloorFromChainlink = StrategyChainlinkFloor(implementation);

        // Floor price = 9.7 ETH, premium = 0.1 ETH, desired price = 9.8 ETH
        // Min price = 9.7 ETH
        (OrderStructs.Maker memory makerAsk, OrderStructs.Taker memory takerBid) = _createMakerAskAndTakerBid({
            premium: premium
        });
        _testFloorFromChainlinkPremiumFixedAmountDesiredSalePriceGreaterThanOrEqualToMinPrice(makerAsk, takerBid);
    }

    function test_FloorFromChainlinkPremiumFixedAmountDesiredSalePriceEqualToMinPrice() public {
        (, , , , , , address implementation) = looksRareProtocol.strategyInfo(1);
        strategyFloorFromChainlink = StrategyChainlinkFloor(implementation);

        // Floor price = 9.7 ETH, premium = 0.1 ETH, desired price = 9.8 ETH
        // Min price = 9.8 ETH
        (OrderStructs.Maker memory makerAsk, OrderStructs.Taker memory takerBid) = _createMakerAskAndTakerBid({
            premium: premium
        });
        makerAsk.price = 9.8 ether;
        _testFloorFromChainlinkPremiumFixedAmountDesiredSalePriceGreaterThanOrEqualToMinPrice(makerAsk, takerBid);
    }

    function _testFloorFromChainlinkPremiumFixedAmountDesiredSalePriceGreaterThanOrEqualToMinPrice(
        OrderStructs.Maker memory makerAsk,
        OrderStructs.Taker memory takerBid
    ) public {
        bytes memory signature = _signMakerOrder(makerAsk, makerUserPK);

        _setPriceFeed();

        _assertOrderIsValid(makerAsk);
        _assertValidMakerOrder(makerAsk, signature);

        _executeTakerBid(takerBid, makerAsk, signature);

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(1), takerUser);
        _assertBuyerPaidWETH(takerUser, 9.8 ether);
        _assertSellerReceivedWETHAfterStandardProtocolFee(makerUser, 9.8 ether);
    }

    function test_FloorFromChainlinkPremiumFixedAmountDesiredSalePriceLessThanMinPrice() public {
        (, , , , , , address implementation) = looksRareProtocol.strategyInfo(1);
        strategyFloorFromChainlink = StrategyChainlinkFloor(implementation);

        // Floor price = 9.7 ETH, premium = 0.1 ETH, desired price = 9.8 ETH
        // Min price = 9.9 ETH
        (OrderStructs.Maker memory makerAsk, OrderStructs.Taker memory takerBid) = _createMakerAskAndTakerBid({
            premium: premium
        });

        makerAsk.price = 9.9 ether;
        takerBid.additionalParameters = abi.encode(makerAsk.price);

        bytes memory signature = _signMakerOrder(makerAsk, makerUserPK);

        _setPriceFeed();

        _assertOrderIsValid(makerAsk);
        _assertValidMakerOrder(makerAsk, signature);

        _executeTakerBid(takerBid, makerAsk, signature);

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(1), takerUser);

        _assertBuyerPaidWETH(takerUser, 9.9 ether);
        _assertSellerReceivedWETHAfterStandardProtocolFee(makerUser, 9.9 ether);
    }
}
