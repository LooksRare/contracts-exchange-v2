// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// LooksRare libraries
import {IOwnableTwoSteps} from "@looksrare/contracts-libs/contracts/interfaces/IOwnableTwoSteps.sol";

// Libraries and interfaces
import {OrderStructs} from "../../../../contracts/libraries/OrderStructs.sol";
import {IStrategyManager} from "../../../../contracts/interfaces/IStrategyManager.sol";

// Shared errors
import {WrongFunctionSelector} from "../../../../contracts/interfaces/SharedErrors.sol";

// Strategies
import {BaseStrategyChainlinkMultiplePriceFeeds} from "../../../../contracts/executionStrategies/Chainlink/BaseStrategyChainlinkMultiplePriceFeeds.sol";
import {StrategyFloorFromChainlink} from "../../../../contracts/executionStrategies/Chainlink/StrategyFloorFromChainlink.sol";

// Mocks and other tests
import {MockChainlinkAggregator} from "../../../mock/MockChainlinkAggregator.sol";
import {ProtocolBase} from "../../ProtocolBase.t.sol";

// Constants
import {ONE_HUNDRED_PERCENT_IN_BP, ASSET_TYPE_ERC721} from "../../../../contracts/constants/NumericConstants.sol";

abstract contract FloorFromChainlinkOrdersTest is ProtocolBase, IStrategyManager {
    StrategyFloorFromChainlink internal strategyFloorFromChainlink;

    // At block 15740567
    // roundId         uint80  : 18446744073709552305
    // answer          int256  : 9700000000000000000
    // startedAt       uint256 : 1666100016
    // updatedAt       uint256 : 1666100016
    // answeredInRound uint80  : 18446744073709552305
    uint256 internal constant CHAINLINK_PRICE_UPDATED_AT = 1666100016;
    uint256 private constant FORKED_BLOCK_NUMBER = 7_791_270;
    uint256 internal constant LATEST_CHAINLINK_ANSWER_IN_WAD = 9.7 ether;
    uint256 internal constant MAXIMUM_LATENCY = 86_400 seconds;
    address internal constant AZUKI_PRICE_FEED = 0x9F6d70CDf08d893f0063742b51d3E9D1e18b7f74;

    uint256 private isFixedAmount;
    bytes4 internal selector;
    bool internal isMakerBid;

    function setUp() public virtual override {
        vm.createSelectFork(vm.rpcUrl("goerli"), FORKED_BLOCK_NUMBER);
        super.setUp();
        _setUpUsers();
        _setUpNewStrategy();
    }

    function testNewStrategy() public {
        (
            bool strategyIsActive,
            uint16 strategyStandardProtocolFee,
            uint16 strategyMinTotalFee,
            uint16 strategyMaxProtocolFee,
            bytes4 strategySelector,
            bool strategyIsMakerBid,
            address strategyImplementation
        ) = looksRareProtocol.strategyInfo(1);

        assertTrue(strategyIsActive);
        assertEq(strategyStandardProtocolFee, _standardProtocolFeeBp);
        assertEq(strategyMinTotalFee, _minTotalFeeBp);
        assertEq(strategyMaxProtocolFee, _maxProtocolFeeBp);
        assertEq(strategySelector, selector);
        assertEq(strategyIsMakerBid, isMakerBid);
        assertEq(strategyImplementation, address(strategyFloorFromChainlink));
    }

    function testMaxLatency() public {
        assertEq(strategyFloorFromChainlink.maxLatency(), MAXIMUM_LATENCY);
    }

    event PriceFeedUpdated(address indexed collection, address indexed priceFeed);

    function testSetPriceFeed() public asPrankedUser(_owner) {
        vm.expectEmit({checkTopic1: true, checkTopic2: true, checkTopic3: true, checkData: false});
        emit PriceFeedUpdated(address(mockERC721), AZUKI_PRICE_FEED);
        strategyFloorFromChainlink.setPriceFeed(address(mockERC721), AZUKI_PRICE_FEED);
        assertEq(strategyFloorFromChainlink.priceFeeds(address(mockERC721)), AZUKI_PRICE_FEED);
    }

    function testSetPriceFeedInvalidDecimals(uint8 decimals) public asPrankedUser(_owner) {
        vm.assume(decimals != 18);

        MockChainlinkAggregator priceFeed = new MockChainlinkAggregator();
        priceFeed.setDecimals(decimals);
        vm.expectRevert(BaseStrategyChainlinkMultiplePriceFeeds.InvalidDecimals.selector);
        strategyFloorFromChainlink.setPriceFeed(address(mockERC721), address(priceFeed));
    }

    function testPriceFeedCannotBeSetTwice() public asPrankedUser(_owner) {
        strategyFloorFromChainlink.setPriceFeed(address(mockERC721), AZUKI_PRICE_FEED);
        vm.expectRevert(BaseStrategyChainlinkMultiplePriceFeeds.PriceFeedAlreadySet.selector);
        strategyFloorFromChainlink.setPriceFeed(address(mockERC721), AZUKI_PRICE_FEED);
    }

    function testSetPriceFeedNotOwner() public {
        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        strategyFloorFromChainlink.setPriceFeed(address(mockERC721), AZUKI_PRICE_FEED);
    }

    function testWrongSelector() public {
        OrderStructs.MakerAsk memory makerAsk = _createSingleItemMakerAskOrder({
            askNonce: 0,
            subsetNonce: 0,
            strategyId: 2,
            assetType: ASSET_TYPE_ERC721,
            orderNonce: 0,
            collection: address(mockERC721),
            currency: address(weth),
            signer: makerUser,
            minPrice: 1 ether,
            itemId: 0
        });

        (bool orderIsValid, bytes4 errorSelector) = strategyFloorFromChainlink.isMakerAskValid(makerAsk, bytes4(0));
        assertFalse(orderIsValid);
        assertEq(errorSelector, WrongFunctionSelector.selector);

        OrderStructs.MakerBid memory makerBid = _createSingleItemMakerBidOrder({
            bidNonce: 0,
            subsetNonce: 0,
            strategyId: 2,
            assetType: ASSET_TYPE_ERC721,
            orderNonce: 0,
            collection: address(mockERC721),
            currency: address(weth),
            signer: makerUser,
            maxPrice: 1 ether,
            itemId: 0
        });

        (orderIsValid, errorSelector) = strategyFloorFromChainlink.isMakerBidValid(makerBid, bytes4(0));
        assertFalse(orderIsValid);
        assertEq(errorSelector, WrongFunctionSelector.selector);
    }

    function _setSelector(bytes4 _selector, bool _isMakerBid) internal {
        selector = _selector;
        isMakerBid = _isMakerBid;
    }

    function _createMakerAskAndTakerBid(
        uint256 premium
    ) internal returns (OrderStructs.MakerAsk memory newMakerAsk, OrderStructs.TakerBid memory newTakerBid) {
        mockERC721.mint(makerUser, 1);

        // Prepare the order hash
        newMakerAsk = _createSingleItemMakerAskOrder({
            askNonce: 0,
            subsetNonce: 0,
            strategyId: 1,
            assetType: ASSET_TYPE_ERC721,
            orderNonce: 0,
            collection: address(mockERC721),
            currency: address(weth),
            signer: makerUser,
            minPrice: LATEST_CHAINLINK_ANSWER_IN_WAD,
            itemId: 1
        });

        newMakerAsk.additionalParameters = abi.encode(premium);

        newTakerBid = OrderStructs.TakerBid(
            takerUser,
            isFixedAmount != 0
                ? LATEST_CHAINLINK_ANSWER_IN_WAD + premium
                : (LATEST_CHAINLINK_ANSWER_IN_WAD * (ONE_HUNDRED_PERCENT_IN_BP + premium)) / ONE_HUNDRED_PERCENT_IN_BP,
            abi.encode(1, 1)
        );
    }

    function _createMakerBidAndTakerAsk(
        uint256 discount
    ) internal returns (OrderStructs.MakerBid memory newMakerBid, OrderStructs.TakerAsk memory newTakerAsk) {
        mockERC721.mint(takerUser, 1);

        uint256 price;
        if (isFixedAmount != 0) {
            price = LATEST_CHAINLINK_ANSWER_IN_WAD - discount;
        } else {
            if (discount > ONE_HUNDRED_PERCENT_IN_BP) {
                price = 0;
            } else {
                price =
                    (LATEST_CHAINLINK_ANSWER_IN_WAD * (ONE_HUNDRED_PERCENT_IN_BP - discount)) /
                    ONE_HUNDRED_PERCENT_IN_BP;
            }
        }

        // Prepare the order hash
        newMakerBid = _createSingleItemMakerBidOrder({
            bidNonce: 0,
            subsetNonce: 0,
            strategyId: 1,
            assetType: ASSET_TYPE_ERC721,
            orderNonce: 0,
            collection: address(mockERC721),
            currency: address(weth),
            signer: makerUser,
            maxPrice: price,
            itemId: 0 // Doesn't matter, not used
        });

        newMakerBid.additionalParameters = abi.encode(discount);

        newTakerAsk = OrderStructs.TakerAsk({
            recipient: takerUser,
            minPrice: price,
            additionalParameters: abi.encode(1, 1)
        });
    }

    function _setIsFixedAmount(uint256 _isFixedAmount) internal {
        isFixedAmount = _isFixedAmount;
    }

    function _setUpNewStrategy() private asPrankedUser(_owner) {
        strategyFloorFromChainlink = new StrategyFloorFromChainlink(_owner, address(weth));
        looksRareProtocol.addStrategy(
            _standardProtocolFeeBp,
            _minTotalFeeBp,
            _maxProtocolFeeBp,
            selector,
            isMakerBid,
            address(strategyFloorFromChainlink)
        );
    }

    function _setPriceFeed() internal asPrankedUser(_owner) {
        strategyFloorFromChainlink.setPriceFeed(address(mockERC721), AZUKI_PRICE_FEED);
    }
}
