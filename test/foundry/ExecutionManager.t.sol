// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// LooksRare unopinionated libraries
import {IOwnableTwoSteps} from "@looksrare/contracts-libs/contracts/interfaces/IOwnableTwoSteps.sol";

// Libraries and interfaces
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";
import {IExecutionManager} from "../../contracts/interfaces/IExecutionManager.sol";
import {IStrategyManager} from "../../contracts/interfaces/IStrategyManager.sol";

// Shared errors
import {OrderInvalid} from "../../contracts/interfaces/SharedErrors.sol";
import {MAKER_ORDER_INVALID_STANDARD_SALE, STRATEGY_MAKER_BID_SELECTOR_INVALID, STRATEGY_MAKER_ASK_SELECTOR_INVALID, STRATEGY_NOT_ACTIVE, START_TIME_GREATER_THAN_END_TIME, TOO_LATE_TO_EXECUTE_ORDER, TOO_EARLY_TO_EXECUTE_ORDER} from "../../contracts/constants/ValidationCodeConstants.sol";

// Base test
import {ProtocolBase} from "./ProtocolBase.t.sol";

// Strategies
import {StrategyFloorFromChainlink} from "../../contracts/executionStrategies/Chainlink/StrategyFloorFromChainlink.sol";

// Constants
import {ASSET_TYPE_ERC721} from "../../contracts/constants/NumericConstants.sol";

contract ExecutionManagerTest is ProtocolBase, IExecutionManager, IStrategyManager {
    function testUpdateCreatorFeeManager() public asPrankedUser(_owner) {
        vm.expectEmit({checkTopic1: true, checkTopic2: false, checkTopic3: false, checkData: true});
        emit NewCreatorFeeManager(address(1));
        looksRareProtocol.updateCreatorFeeManager(address(1));
        assertEq(address(looksRareProtocol.creatorFeeManager()), address(1));
    }

    function testUpdateCreatorFeeManagerNotOwner() public {
        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        looksRareProtocol.updateCreatorFeeManager(address(1));
    }

    function testUpdateMaxCreatorFeeBp(uint16 newMaxCreatorFeeBp) public asPrankedUser(_owner) {
        vm.assume(newMaxCreatorFeeBp <= 2_500);
        vm.expectEmit({checkTopic1: true, checkTopic2: false, checkTopic3: false, checkData: true});
        emit NewMaxCreatorFeeBp(newMaxCreatorFeeBp);
        looksRareProtocol.updateMaxCreatorFeeBp(newMaxCreatorFeeBp);
        assertEq(looksRareProtocol.maxCreatorFeeBp(), newMaxCreatorFeeBp);
    }

    function testUpdateMaxCreatorFeeBpNotOwner() public {
        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        looksRareProtocol.updateMaxCreatorFeeBp(uint16(2_500));
    }

    function testUpdateMaxCreatorFeeBpTooHigh(uint16 newMaxCreatorFeeBp) public asPrankedUser(_owner) {
        vm.assume(newMaxCreatorFeeBp > 2_500);
        vm.expectRevert(CreatorFeeBpTooHigh.selector);
        looksRareProtocol.updateMaxCreatorFeeBp(newMaxCreatorFeeBp);
    }

    function testUpdateProtocolFeeRecipient() public asPrankedUser(_owner) {
        vm.expectEmit({checkTopic1: true, checkTopic2: false, checkTopic3: false, checkData: true});
        emit NewProtocolFeeRecipient(address(1));
        looksRareProtocol.updateProtocolFeeRecipient(address(1));
        assertEq(looksRareProtocol.protocolFeeRecipient(), address(1));
    }

    function testUpdateProtocolFeeRecipientCannotBeNullAddress() public asPrankedUser(_owner) {
        vm.expectRevert(IExecutionManager.NewProtocolFeeRecipientCannotBeNullAddress.selector);
        looksRareProtocol.updateProtocolFeeRecipient(address(0));
    }

    function testUpdateProtocolFeeRecipientNotOwner() public {
        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        looksRareProtocol.updateProtocolFeeRecipient(address(1));
    }

    function testCannotValidateOrderIfTooEarlyToExecute(uint256 timestamp) public asPrankedUser(takerUser) {
        // 300 because because it is deducted by 5 minutes + 1 second
        vm.assume(timestamp > 300 && timestamp < type(uint256).max);
        // Change timestamp to avoid underflow issues
        vm.warp(timestamp);

        (
            OrderStructs.MakerBid memory makerBid,
            OrderStructs.TakerOrder memory takerAsk
        ) = _createMockMakerBidAndTakerAsk(address(mockERC721), address(weth));

        makerBid.startTime = block.timestamp;
        makerBid.endTime = block.timestamp + 1 seconds;

        // Maker bid is valid if its start time is within 5 minutes into the future
        vm.warp(makerBid.startTime - 5 minutes);
        bytes memory signature = _signMakerBid(makerBid, makerUserPK);
        _doesMakerBidOrderReturnValidationCode(makerBid, signature, TOO_EARLY_TO_EXECUTE_ORDER);

        // Maker bid is invalid if its start time is not within 5 minutes into the future
        vm.warp(makerBid.startTime - 5 minutes - 1 seconds);
        vm.expectRevert(OutsideOfTimeRange.selector);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function testCannotValidateOrderIfTooLateToExecute(uint256 timestamp) public asPrankedUser(takerUser) {
        vm.assume(timestamp > 0 && timestamp < type(uint256).max);
        // Change timestamp to avoid underflow issues
        vm.warp(timestamp);

        (
            OrderStructs.MakerBid memory makerBid,
            OrderStructs.TakerOrder memory takerAsk
        ) = _createMockMakerBidAndTakerAsk(address(mockERC721), address(weth));

        makerBid.startTime = block.timestamp - 1 seconds;
        makerBid.endTime = block.timestamp;
        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        vm.warp(block.timestamp);
        _doesMakerBidOrderReturnValidationCode(makerBid, signature, TOO_LATE_TO_EXECUTE_ORDER);

        vm.warp(block.timestamp + 1 seconds);
        vm.expectRevert(OutsideOfTimeRange.selector);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function testCannotValidateOrderIfStartTimeLaterThanEndTime(uint256 timestamp) public asPrankedUser(takerUser) {
        vm.assume(timestamp < type(uint256).max);
        // Change timestamp to avoid underflow issues
        vm.warp(timestamp);

        (
            OrderStructs.MakerBid memory makerBid,
            OrderStructs.TakerOrder memory takerAsk
        ) = _createMockMakerBidAndTakerAsk(address(mockERC721), address(weth));

        makerBid.startTime = block.timestamp + 1 seconds;
        makerBid.endTime = block.timestamp;
        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        _doesMakerBidOrderReturnValidationCode(makerBid, signature, START_TIME_GREATER_THAN_END_TIME);

        vm.expectRevert(OutsideOfTimeRange.selector);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function testCannotValidateOrderIfMakerBidItemIdsIsEmpty() public {
        (
            OrderStructs.MakerBid memory makerBid,
            OrderStructs.TakerOrder memory takerAsk
        ) = _createMockMakerBidAndTakerAsk(address(mockERC721), address(weth));

        uint256[] memory itemIds = new uint256[](0);
        makerBid.itemIds = itemIds;
        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        _doesMakerBidOrderReturnValidationCode(makerBid, signature, MAKER_ORDER_INVALID_STANDARD_SALE);

        vm.expectRevert(OrderInvalid.selector);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function testCannotValidateOrderIfMakerBidItemIdsLengthMismatch(
        uint256 makerBidItemIdsLength
    ) public asPrankedUser(takerUser) {
        vm.assume(makerBidItemIdsLength > 1 && makerBidItemIdsLength < 100_000);

        (
            OrderStructs.MakerBid memory makerBid,
            OrderStructs.TakerOrder memory takerAsk
        ) = _createMockMakerBidAndTakerAsk(address(mockERC721), address(weth));

        uint256[] memory itemIds = new uint256[](makerBidItemIdsLength);
        makerBid.itemIds = itemIds;
        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        _doesMakerBidOrderReturnValidationCode(makerBid, signature, MAKER_ORDER_INVALID_STANDARD_SALE);

        vm.expectRevert(OrderInvalid.selector);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function testCannotValidateOrderIfMakerAskItemIdsIsEmpty() public asPrankedUser(takerUser) {
        vm.deal(takerUser, 100 ether);

        (
            OrderStructs.MakerAsk memory makerAsk,
            OrderStructs.TakerOrder memory takerBid
        ) = _createMockMakerAskAndTakerBid(address(mockERC721));

        // Change maker itemIds array to make its length equal to 0
        uint256[] memory itemIds = new uint256[](0);
        makerAsk.itemIds = itemIds;
        bytes memory signature = _signMakerAsk(makerAsk, makerUserPK);

        _doesMakerAskOrderReturnValidationCode(makerAsk, signature, MAKER_ORDER_INVALID_STANDARD_SALE);

        vm.expectRevert(OrderInvalid.selector);
        looksRareProtocol.executeTakerBid{value: makerAsk.minPrice}(
            takerBid,
            makerAsk,
            signature,
            _EMPTY_MERKLE_TREE,
            _EMPTY_AFFILIATE
        );
    }

    function testCannotValidateOrderIfMakerAskItemIdsLengthMismatch(
        uint256 makerAskItemIdsLength
    ) public asPrankedUser(takerUser) {
        vm.deal(takerUser, 100 ether);

        vm.assume(makerAskItemIdsLength > 1 && makerAskItemIdsLength < 100_000);

        (
            OrderStructs.MakerAsk memory makerAsk,
            OrderStructs.TakerOrder memory takerBid
        ) = _createMockMakerAskAndTakerBid(address(mockERC721));

        uint256[] memory itemIds = new uint256[](makerAskItemIdsLength);
        makerAsk.itemIds = itemIds;
        bytes memory signature = _signMakerAsk(makerAsk, makerUserPK);

        _doesMakerAskOrderReturnValidationCode(makerAsk, signature, MAKER_ORDER_INVALID_STANDARD_SALE);

        vm.expectRevert(OrderInvalid.selector);
        looksRareProtocol.executeTakerBid{value: makerAsk.minPrice}(
            takerBid,
            makerAsk,
            signature,
            _EMPTY_MERKLE_TREE,
            _EMPTY_AFFILIATE
        );
    }

    function testCannotExecuteTransactionIfMakerBidWithStrategyForMakerAsk() public {
        _setUpUsers();

        vm.prank(_owner);
        StrategyFloorFromChainlink strategy = new StrategyFloorFromChainlink(_owner, address(weth));

        bool isMakerBid = true;
        vm.prank(_owner);
        looksRareProtocol.addStrategy(
            250,
            250,
            300,
            StrategyFloorFromChainlink.executeBasisPointsDiscountCollectionOfferStrategyWithTakerAsk.selector,
            isMakerBid,
            address(strategy)
        );

        uint256 itemId = 0;
        uint256 price = 1 ether;

        // Mint asset
        mockERC721.mint(makerUser, itemId);

        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerOrder memory takerBid, bytes memory signature) = _createSingleItemMakerAskAndTakerBidOrderAndSignature({
            askNonce: 0,
            subsetNonce: 0,
            strategyId: 1, // Fake strategy
            assetType: ASSET_TYPE_ERC721,
            orderNonce: 0,
            collection: address(mockERC721),
            currency: ETH,
            signer: makerUser,
            minPrice: price,
            itemId: itemId
        });

        _doesMakerAskOrderReturnValidationCode(makerAsk, signature, STRATEGY_MAKER_ASK_SELECTOR_INVALID);

        vm.prank(takerUser);
        vm.expectRevert(IExecutionManager.NoSelectorForMakerAsk.selector);
        looksRareProtocol.executeTakerBid{value: price}(
            takerBid,
            makerAsk,
            signature,
            _EMPTY_MERKLE_TREE,
            _EMPTY_AFFILIATE
        );
    }

    function testCannotExecuteTransactionIfMakerAskWithStrategyForMakerBid() public {
        _setUpUsers();

        vm.prank(_owner);
        StrategyFloorFromChainlink strategy = new StrategyFloorFromChainlink(_owner, address(weth));

        bool isMakerBid = false;
        vm.prank(_owner);
        // All parameters are random, including the selector and the implementation
        looksRareProtocol.addStrategy(
            250,
            250,
            300,
            StrategyFloorFromChainlink.executeFixedPremiumStrategyWithTakerBid.selector,
            isMakerBid,
            address(strategy)
        );

        uint256 itemId = 0;
        uint256 price = 1 ether;

        // Mint asset to ask user
        mockERC721.mint(takerUser, itemId);

        // Prepare the order hash
        (OrderStructs.MakerBid memory makerBid, OrderStructs.TakerOrder memory takerAsk, bytes memory signature) = _createSingleItemMakerBidAndTakerAskOrderAndSignature({
            bidNonce: 0,
            subsetNonce: 0,
            strategyId: 1, // Fake strategy
            assetType: ASSET_TYPE_ERC721,
            orderNonce: 0,
            collection: address(mockERC721),
            currency: address(weth),
            signer: makerUser,
            maxPrice: price,
            itemId: itemId
        });

        _doesMakerBidOrderReturnValidationCode(makerBid, signature, STRATEGY_MAKER_BID_SELECTOR_INVALID);

        vm.prank(takerUser);
        vm.expectRevert(IExecutionManager.NoSelectorForMakerBid.selector);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }
}
