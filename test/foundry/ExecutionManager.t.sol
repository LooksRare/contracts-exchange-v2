// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// LooksRare unopinionated libraries
import {IOwnableTwoSteps} from "@looksrare/contracts-libs/contracts/interfaces/IOwnableTwoSteps.sol";

// Libraries and interfaces
import {IExecutionManager} from "../../contracts/interfaces/IExecutionManager.sol";
import {IStrategyManager} from "../../contracts/interfaces/IStrategyManager.sol";
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";

// Base test
import {ProtocolBase} from "./ProtocolBase.t.sol";

contract ExecutionManagerTest is ProtocolBase, IExecutionManager, IStrategyManager {
    error OrderInvalid();

    function testUpdateCreatorFeeManager() public asPrankedUser(_owner) {
        vm.expectEmit(true, false, false, true);
        emit NewCreatorFeeManager(address(1));
        looksRareProtocol.updateCreatorFeeManager(address(1));
        assertEq(address(looksRareProtocol.creatorFeeManager()), address(1));
    }

    function testUpdateCreatorFeeManagerNotOwner() public {
        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        looksRareProtocol.updateCreatorFeeManager(address(1));
    }

    function testUpdateMaxCreatorFeeBp() public asPrankedUser(_owner) {
        uint16 newMaxCreatorFeeBp = uint16(2_500);
        vm.expectEmit(true, false, false, true);
        emit NewMaxCreatorFeeBp(newMaxCreatorFeeBp);
        looksRareProtocol.updateMaxCreatorFeeBp(newMaxCreatorFeeBp);
        assertEq(looksRareProtocol.maxCreatorFeeBp(), newMaxCreatorFeeBp);
    }

    function testUpdateMaxCreatorFeeBpNotOwner() public {
        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        looksRareProtocol.updateMaxCreatorFeeBp(uint16(2_500));
    }

    function testUpdateMaxCreatorFeeBpTooHigh() public asPrankedUser(_owner) {
        vm.expectRevert(CreatorFeeBpTooHigh.selector);
        looksRareProtocol.updateMaxCreatorFeeBp(uint16(2_501));
    }

    function testUpdateProtocolFeeRecipient() public asPrankedUser(_owner) {
        vm.expectEmit(true, false, false, true);
        emit NewProtocolFeeRecipient(address(1));
        looksRareProtocol.updateProtocolFeeRecipient(address(1));
        assertEq(looksRareProtocol.protocolFeeRecipient(), address(1));
    }

    function testUpdateProtocolFeeRecipientNotOwner() public {
        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        looksRareProtocol.updateProtocolFeeRecipient(address(1));
    }

    function testCannotValidateOrderIfWrongTimestamps() public asPrankedUser(takerUser) {
        // Change timestamp to avoid underflow issues
        vm.warp(12_000_000);

        /**
         * 1. Too early to execute
         */
        (OrderStructs.MakerBid memory makerBid, OrderStructs.TakerAsk memory takerAsk) = _createMockMakerBidAndTakerAsk(
            address(mockERC721),
            address(weth)
        );

        vm.warp(block.timestamp - 1);
        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        vm.expectRevert(OutsideOfTimeRange.selector);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _emptyMerkleTree, _emptyAffiliate);

        /**
         * 2. Too late to execute
         */
        vm.warp(block.timestamp);

        makerBid.startTime = 0;
        makerBid.endTime = block.timestamp - 1;
        signature = _signMakerBid(makerBid, makerUserPK);

        vm.expectRevert(OutsideOfTimeRange.selector);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _emptyMerkleTree, _emptyAffiliate);

        /**
         * 3. start time > end time
         */
        makerBid.startTime = block.timestamp;
        makerBid.endTime = block.timestamp - 1;
        signature = _signMakerBid(makerBid, makerUserPK);

        vm.expectRevert(OutsideOfTimeRange.selector);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _emptyMerkleTree, _emptyAffiliate);
    }

    function testCannotValidateOrderIfWrongFormat() public asPrankedUser(takerUser) {
        // (For takerBid tests)
        vm.deal(takerUser, 100 ether);

        uint256[] memory itemIds = new uint256[](2);

        /**
         * 1. STANDARD STRATEGY/MAKER BID: itemIds' length is equal to 0
         */
        (OrderStructs.MakerBid memory makerBid, OrderStructs.TakerAsk memory takerAsk) = _createMockMakerBidAndTakerAsk(
            address(mockERC721),
            address(weth)
        );

        // Change makerBid itemIds array's length to make it equal to 0
        itemIds = new uint256[](0);
        makerBid.itemIds = itemIds;
        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        vm.expectRevert(OrderInvalid.selector);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _emptyMerkleTree, _emptyAffiliate);

        /**
         * 2. STANDARD STRATEGY/MAKER BID: maker itemIds' length is not equal to maker amounts' length
         */
        (makerBid, takerAsk) = _createMockMakerBidAndTakerAsk(address(mockERC721), address(weth));

        // Change itemIds array for maker to make its length equal to 2
        itemIds = new uint256[](2);
        makerBid.itemIds = itemIds;
        signature = _signMakerBid(makerBid, makerUserPK);

        vm.expectRevert(OrderInvalid.selector);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _emptyMerkleTree, _emptyAffiliate);

        /**
         * 3. STANDARD STRATEGY/MAKER BID: itemIds' length of maker is not equal to length of taker
         */
        (makerBid, takerAsk) = _createMockMakerBidAndTakerAsk(address(mockERC721), address(weth));

        // Change itemIds array for taker to make its length equal to 2
        itemIds = new uint256[](2);
        takerAsk.itemIds = itemIds;
        signature = _signMakerBid(makerBid, makerUserPK);

        vm.expectRevert(OrderInvalid.selector);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _emptyMerkleTree, _emptyAffiliate);

        /**
         * 4. STANDARD STRATEGY/MAKER BID: amounts' length of maker is not equal to length of taker
         */
        (makerBid, takerAsk) = _createMockMakerBidAndTakerAsk(address(mockERC721), address(weth));

        // Change amounts array for taker to make its length equal to 2
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 1;
        takerAsk.amounts = amounts;
        signature = _signMakerBid(makerBid, makerUserPK);

        vm.expectRevert(OrderInvalid.selector);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _emptyMerkleTree, _emptyAffiliate);

        /**
         * 5. STANDARD STRATEGY/MAKER BID: maxPrice of maker is not equal to minPrice of taker
         */
        (makerBid, takerAsk) = _createMockMakerBidAndTakerAsk(address(mockERC721), address(weth));
        signature = _signMakerBid(makerBid, makerUserPK);

        // Change price of takerAsk to be higher than makerAsk price
        takerAsk.minPrice = makerBid.maxPrice + 1;

        vm.expectRevert(OrderInvalid.selector);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _emptyMerkleTree, _emptyAffiliate);

        // Change price of takerAsk to be higher than makerAsk price
        takerAsk.minPrice = makerBid.maxPrice - 1;

        vm.expectRevert(OrderInvalid.selector);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _emptyMerkleTree, _emptyAffiliate);

        /**
         * 6. STANDARD STRATEGY/MAKER ASK: itemIds' length of maker is equal to 0
         */
        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _createMockMakerAskAndTakerBid(
            address(mockERC721)
        );

        // Change maker itemIds array to make its length equal to 0
        itemIds = new uint256[](0);
        makerAsk.itemIds = itemIds;
        signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.expectRevert(OrderInvalid.selector);
        looksRareProtocol.executeTakerBid{value: takerBid.maxPrice}(
            takerBid,
            makerAsk,
            signature,
            _emptyMerkleTree,
            _emptyAffiliate
        );

        /**
         * 7. STANDARD STRATEGY/MAKER ASK: maker itemIds' length is not equal to maker amounts' length
         */
        (makerAsk, takerBid) = _createMockMakerAskAndTakerBid(address(mockERC721));

        // Change itemIds array to make it equal to 2
        itemIds = new uint256[](2);
        makerAsk.itemIds = itemIds;
        signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.expectRevert(OrderInvalid.selector);
        looksRareProtocol.executeTakerBid{value: takerBid.maxPrice}(
            takerBid,
            makerAsk,
            signature,
            _emptyMerkleTree,
            _emptyAffiliate
        );

        /**
         * 8. STANDARD STRATEGY/MAKER ASK: itemIds' length of maker is not equal to length of taker
         */
        (makerAsk, takerBid) = _createMockMakerAskAndTakerBid(address(mockERC721));

        // Change itemIds array to make it equal to 2
        itemIds = new uint256[](2);
        takerBid.itemIds = itemIds;
        signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.expectRevert(OrderInvalid.selector);
        looksRareProtocol.executeTakerBid{value: takerBid.maxPrice}(
            takerBid,
            makerAsk,
            signature,
            _emptyMerkleTree,
            _emptyAffiliate
        );

        /**
         * 9. STANDARD STRATEGY/MAKER ASK: amounts' length of maker is not equal to length of taker
         */

        // Change amounts array' length to make it equal to 2
        (makerAsk, takerBid) = _createMockMakerAskAndTakerBid(address(mockERC721));
        amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 1;
        takerBid.amounts = amounts;
        signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.expectRevert(OrderInvalid.selector);
        looksRareProtocol.executeTakerBid{value: takerBid.maxPrice}(
            takerBid,
            makerAsk,
            signature,
            _emptyMerkleTree,
            _emptyAffiliate
        );

        /**
         * 10. STANDARD STRATEGY/MAKER ASK: minPrice of maker is not equal to maxPrice of taker
         */
        (makerAsk, takerBid) = _createMockMakerAskAndTakerBid(address(mockERC721));
        signature = _signMakerAsk(makerAsk, makerUserPK);

        // Change price of takerBid to be lower than makerAsk price
        takerBid.maxPrice = makerAsk.minPrice - 1;

        vm.expectRevert(OrderInvalid.selector);
        looksRareProtocol.executeTakerBid{value: takerBid.maxPrice}(
            takerBid,
            makerAsk,
            signature,
            _emptyMerkleTree,
            _emptyAffiliate
        );

        // Change price of takerBid to be higher than makerAsk price
        takerBid.maxPrice = makerAsk.minPrice + 1;

        vm.expectRevert(OrderInvalid.selector);
        looksRareProtocol.executeTakerBid{value: takerBid.maxPrice}(
            takerBid,
            makerAsk,
            signature,
            _emptyMerkleTree,
            _emptyAffiliate
        );
    }
}
