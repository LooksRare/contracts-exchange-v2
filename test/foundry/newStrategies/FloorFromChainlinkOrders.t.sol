// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// LooksRare libraries
import {IOwnableTwoSteps} from "@looksrare/contracts-libs/contracts/interfaces/IOwnableTwoSteps.sol";

// Libraries and interfaces
import {OrderStructs} from "../../../contracts/libraries/OrderStructs.sol";
import {IStrategyManager} from "../../../contracts/interfaces/IStrategyManager.sol";

// Strategies
import {StrategyFloorFromChainlink} from "../../../contracts/executionStrategies/StrategyFloorFromChainlink.sol";

// Other tests
import {ChainlinkMaximumLatencyTest} from "./ChainlinkMaximumLatency.t.sol";
import {ProtocolBase} from "../ProtocolBase.t.sol";

abstract contract FloorFromChainlinkOrdersTest is ProtocolBase, IStrategyManager, ChainlinkMaximumLatencyTest {
    StrategyFloorFromChainlink internal strategyFloorFromChainlink;

    // At block 15740567
    // roundId         uint80  : 18446744073709552305
    // answer          int256  : 9700000000000000000
    // startedAt       uint256 : 1666100016
    // updatedAt       uint256 : 1666100016
    // answeredInRound uint80  : 18446744073709552305
    uint256 private constant FORKED_BLOCK_NUMBER = 7_791_270;
    uint256 internal constant LATEST_CHAINLINK_ANSWER_IN_WAD = 9.7 ether;
    uint256 internal constant MAXIMUM_LATENCY = 3_600 seconds;
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
        assertEq(strategyStandardProtocolFee, _standardProtocolFee);
        assertEq(strategyMinTotalFee, _minTotalFee);
        assertEq(strategyMaxProtocolFee, _maxProtocolFee);
        assertEq(strategySelector, selector);
        assertEq(strategyIsMakerBid, isMakerBid);
        assertEq(strategyImplementation, address(strategyFloorFromChainlink));
    }

    function testSetMaximumLatency() public {
        _testSetMaximumLatency(address(strategyFloorFromChainlink));
    }

    function testSetMaximumLatencyLatencyToleranceTooHigh() public {
        _testSetMaximumLatencyLatencyToleranceTooHigh(address(strategyFloorFromChainlink));
    }

    function testSetMaximumLatencyNotOwner() public {
        _testSetMaximumLatencyNotOwner(address(strategyFloorFromChainlink));
    }

    event PriceFeedUpdated(address indexed collection, address indexed priceFeed);

    function testSetPriceFeed() public asPrankedUser(_owner) {
        vm.expectEmit(true, true, true, false);
        emit PriceFeedUpdated(address(mockERC721), AZUKI_PRICE_FEED);
        strategyFloorFromChainlink.setPriceFeed(address(mockERC721), AZUKI_PRICE_FEED);
        assertEq(strategyFloorFromChainlink.priceFeeds(address(mockERC721)), AZUKI_PRICE_FEED);
    }

    function testSetPriceFeedNotOwner() public {
        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        strategyFloorFromChainlink.setPriceFeed(address(mockERC721), AZUKI_PRICE_FEED);
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
            assetType: 0,
            orderNonce: 0,
            collection: address(mockERC721),
            currency: address(weth),
            signer: makerUser,
            minPrice: LATEST_CHAINLINK_ANSWER_IN_WAD,
            itemId: 1
        });

        newMakerAsk.additionalParameters = abi.encode(premium);

        uint256[] memory itemIds = new uint256[](1);
        itemIds[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        newTakerBid = OrderStructs.TakerBid(
            takerUser,
            isFixedAmount != 0
                ? LATEST_CHAINLINK_ANSWER_IN_WAD + premium
                : (LATEST_CHAINLINK_ANSWER_IN_WAD * (10_000 + premium)) / 10_000,
            itemIds,
            amounts,
            abi.encode()
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
            if (discount > 10_000) {
                price = 0;
            } else {
                price = (LATEST_CHAINLINK_ANSWER_IN_WAD * (10_000 - discount)) / 10_000;
            }
        }

        // Prepare the order hash
        newMakerBid = _createSingleItemMakerBidOrder({
            bidNonce: 0,
            subsetNonce: 0,
            strategyId: 1,
            assetType: 0, // ERC721,
            orderNonce: 0,
            collection: address(mockERC721),
            currency: address(weth),
            signer: makerUser,
            maxPrice: price,
            itemId: 0 // Doesn't matter, not used
        });

        newMakerBid.additionalParameters = abi.encode(discount);

        uint256[] memory itemIds = new uint256[](1);
        itemIds[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        newTakerAsk = OrderStructs.TakerAsk({
            recipient: takerUser,
            minPrice: price,
            itemIds: itemIds,
            amounts: amounts,
            additionalParameters: abi.encode()
        });
    }

    function _setIsFixedAmount(uint256 _isFixedAmount) internal {
        isFixedAmount = _isFixedAmount;
    }

    function _setUpNewStrategy() private asPrankedUser(_owner) {
        strategyFloorFromChainlink = new StrategyFloorFromChainlink(address(looksRareProtocol), address(weth));
        looksRareProtocol.addStrategy(
            _standardProtocolFee,
            _minTotalFee,
            _maxProtocolFee,
            selector,
            isMakerBid,
            address(strategyFloorFromChainlink)
        );
    }

    function _setPriceFeed() internal {
        vm.startPrank(_owner);
        strategyFloorFromChainlink.setMaximumLatency(MAXIMUM_LATENCY);
        strategyFloorFromChainlink.setPriceFeed(address(mockERC721), AZUKI_PRICE_FEED);
        vm.stopPrank();
    }
}
