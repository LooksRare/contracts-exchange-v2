// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";
import {IStrategyManager} from "../../contracts/interfaces/IStrategyManager.sol";
import {StrategyFloor} from "../../contracts/executionStrategies/StrategyFloor.sol";
import {ProtocolBase} from "./ProtocolBase.t.sol";
import {ChainlinkMaximumLatencyTest} from "./ChainlinkMaximumLatency.t.sol";

abstract contract FloorPremiumOrdersTest is ProtocolBase, IStrategyManager, ChainlinkMaximumLatencyTest {
    StrategyFloor internal strategyFloor;
    bytes4 internal selectorTakerAsk = _emptyBytes4;

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

    function selectorTakerBid() internal pure virtual returns (bytes4) {
        return StrategyFloor.executeFixedPremiumStrategyWithTakerBid.selector;
    }

    function _setUpNewStrategy() private asPrankedUser(_owner) {
        strategyFloor = new StrategyFloor(address(looksRareProtocol));
        looksRareProtocol.addStrategy(
            _standardProtocolFee,
            _minTotalFee,
            _maxProtocolFee,
            selectorTakerAsk,
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

        newMakerAsk.additionalParameters = abi.encode(premium, isFixedAmount);

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

    function _setIsFixedAmount(uint256 _isFixedAmount) internal {
        isFixedAmount = _isFixedAmount;
    }
}
