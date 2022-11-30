// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";
import {IStrategyManager} from "../../contracts/interfaces/IStrategyManager.sol";
import {StrategyFloor} from "../../contracts/executionStrategies/StrategyFloor.sol";
import {ProtocolBase} from "./ProtocolBase.t.sol";
import {ChainlinkMaximumLatencyTest} from "./ChainlinkMaximumLatency.t.sol";

abstract contract FloorOrdersTest is ProtocolBase, IStrategyManager, ChainlinkMaximumLatencyTest {
    StrategyFloor internal strategyFloor;

    // At block 15740567
    // roundId         uint80  : 18446744073709552305
    // answer          int256  : 9700000000000000000
    // startedAt       uint256 : 1666100016
    // updatedAt       uint256 : 1666100016
    // answeredInRound uint80  : 18446744073709552305
    uint256 private constant FORKED_BLOCK_NUMBER = 7791270;
    uint256 private constant LATEST_CHAINLINK_ANSWER_IN_WAD = 9.7 ether;
    address internal constant AZUKI_PRICE_FEED = 0x9F6d70CDf08d893f0063742b51d3E9D1e18b7f74;

    uint256 private isFixedAmount;

    function setUp() public virtual override {
        vm.createSelectFork(vm.rpcUrl("goerli"), FORKED_BLOCK_NUMBER);
        super.setUp();
        _setUpUsers();
        _setUpNewStrategy();
    }

    function selectorTakerBid() internal view virtual returns (bytes4 selector) {
        selector = _emptyBytes4;
    }

    function selectorTakerAsk() internal view virtual returns (bytes4 selector) {
        selector = _emptyBytes4;
    }

    function selectorMakerBid() internal view virtual returns (bytes4 selector) {
        selector = _emptyBytes4;
    }

    function selectorMakerAsk() internal view virtual returns (bytes4 selector) {
        selector = _emptyBytes4;
    }

    function _setUpNewStrategy() private asPrankedUser(_owner) {
        strategyFloor = new StrategyFloor(address(looksRareProtocol));
        looksRareProtocol.addStrategy(
            _standardProtocolFee,
            _minTotalFee,
            _maxProtocolFee,
            selectorTakerAsk(),
            selectorTakerBid(),
            address(strategyFloor)
        );
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
            assetType: 0,
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
}
