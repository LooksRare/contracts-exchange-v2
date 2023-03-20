// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Libraries and interfaces
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";
import {IExecutionManager} from "../../contracts/interfaces/IExecutionManager.sol";
import {IStrategyManager} from "../../contracts/interfaces/IStrategyManager.sol";

import {CreatorFeeManagerWithRoyalties} from "../../contracts/CreatorFeeManagerWithRoyalties.sol";

// Base test
import {ProtocolBase} from "./ProtocolBase.t.sol";

// Constants
import {ONE_HUNDRED_PERCENT_IN_BP} from "../../contracts/constants/NumericConstants.sol";

contract ExecutionManagerCalculateProtocolFeeAmountTest is ProtocolBase, IExecutionManager, IStrategyManager {
    uint256 private constant ROYALTY_FEE_BP = 10;
    uint256 private constant MIN_TOTAL_FEE_BP = 100;

    function setUp() public {
        _setUp();
        CreatorFeeManagerWithRoyalties creatorFeeManager = new CreatorFeeManagerWithRoyalties(
            address(royaltyFeeRegistry)
        );
        vm.prank(_owner);
        looksRareProtocol.updateCreatorFeeManager(address(creatorFeeManager));

        vm.prank(_owner);
        looksRareProtocol.updateStrategy({
            strategyId: 0,
            isActive: true,
            newStandardProtocolFeeBp: uint16(50),
            newMinTotalFeeBp: uint16(MIN_TOTAL_FEE_BP)
        });
        _setupRegistryRoyalties(address(mockERC721), ROYALTY_FEE_BP);
    }

    function test_executeTakerBid_ProtocolFeeAmountPlusCreatorFeeAmountLessThanMinTotalFeeAmount(uint256 price) public {
        vm.assume(price > 0 && price <= _initialETHBalanceUser);

        _setUpUsers();

        (OrderStructs.Maker memory makerAsk, OrderStructs.Taker memory takerBid) = _createMockMakerAskAndTakerBid(
            address(mockERC721)
        );
        makerAsk.price = price;

        bytes memory signature = _signMakerOrder(makerAsk, makerUserPK);

        uint256 itemId = makerAsk.itemIds[0];

        // Mint asset
        mockERC721.mint(makerUser, itemId);

        // Verify validity of maker ask order
        _assertValidMakerOrder(makerAsk, signature);

        // Arrays for events
        uint256[3] memory expectedFees = _calculateExpectedFees(price);
        address[2] memory expectedRecipients;

        expectedRecipients[0] = makerUser;
        expectedRecipients[1] = _royaltyRecipient;

        // Execute taker bid transaction
        vm.prank(takerUser);
        _assertTakerBidEvent(makerAsk, expectedRecipients, expectedFees);
        looksRareProtocol.executeTakerBid{value: price}(
            takerBid,
            makerAsk,
            signature,
            _EMPTY_MERKLE_TREE,
            _EMPTY_AFFILIATE
        );

        _assertSuccessfulExecutionThroughETH(takerUser, makerUser, itemId, price, expectedFees);

        // No leftover in the balance of the contract
        assertEq(address(looksRareProtocol).balance, 0);
        // Verify the nonce is marked as executed
        assertEq(looksRareProtocol.userOrderNonce(makerUser, makerAsk.orderNonce), MAGIC_VALUE_ORDER_NONCE_EXECUTED);
    }

    function test_executeTakerAsk_ProtocolFeeAmountPlusCreatorFeeAmountLessThanMinTotalFeeAmount(uint256 price) public {
        vm.assume(price > 0 && price <= _initialWETHBalanceUser);

        _setUpUsers();

        (OrderStructs.Maker memory makerBid, OrderStructs.Taker memory takerAsk) = _createMockMakerBidAndTakerAsk(
            address(mockERC721),
            address(weth)
        );
        makerBid.price = price;

        bytes memory signature = _signMakerOrder(makerBid, makerUserPK);

        // Verify maker bid order
        _assertValidMakerOrder(makerBid, signature);

        uint256 itemId = makerBid.itemIds[0];

        // Mint asset
        mockERC721.mint(takerUser, itemId);

        // Arrays for events
        uint256[3] memory expectedFees = _calculateExpectedFees(price);
        address[2] memory expectedRecipients;

        expectedRecipients[0] = takerUser;
        expectedRecipients[1] = _royaltyRecipient;

        vm.prank(takerUser);
        _assertTakerAskEvent(makerBid, expectedRecipients, expectedFees);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);

        _assertSuccessfulExecutionThroughWETH(makerUser, takerUser, itemId, price, expectedFees);
        // Verify the nonce is marked as executed
        assertEq(looksRareProtocol.userOrderNonce(makerUser, makerBid.orderNonce), MAGIC_VALUE_ORDER_NONCE_EXECUTED);
    }

    function _calculateExpectedFees(uint256 price) private pure returns (uint256[3] memory expectedFees) {
        expectedFees[1] = (price * ROYALTY_FEE_BP) / ONE_HUNDRED_PERCENT_IN_BP;
        expectedFees[2] = (price * MIN_TOTAL_FEE_BP) / ONE_HUNDRED_PERCENT_IN_BP - expectedFees[1];
        expectedFees[0] = price - expectedFees[1] - expectedFees[2];
    }

    function _assertSuccessfulExecutionThroughETH(
        address buyer,
        address seller,
        uint256 itemId,
        uint256 price,
        uint256[3] memory expectedFees
    ) private {
        assertEq(mockERC721.ownerOf(itemId), buyer);
        _assertBuyerPaidETH(buyer, price);
        assertEq(
            seller.balance,
            _initialETHBalanceUser + expectedFees[0],
            "Seller should receive 99% of the whole price"
        );
        assertEq(
            _royaltyRecipient.balance,
            _initialETHBalanceRoyaltyRecipient + expectedFees[1],
            "Royalty recipient should receive 0.1% of the whole price"
        );
        assertEq(
            _owner.balance,
            _initialETHBalanceOwner + expectedFees[2],
            "Protocol fee recipient receives 0.9% of the whole price"
        );
    }

    function _assertSuccessfulExecutionThroughWETH(
        address buyer,
        address seller,
        uint256 itemId,
        uint256 price,
        uint256[3] memory expectedFees
    ) private {
        assertEq(mockERC721.ownerOf(itemId), buyer);
        _assertBuyerPaidWETH(buyer, price);
        assertEq(
            weth.balanceOf(seller),
            _initialWETHBalanceUser + expectedFees[0],
            "Seller should receive 99% of the whole price"
        );
        assertEq(
            weth.balanceOf(_royaltyRecipient),
            _initialWETHBalanceRoyaltyRecipient + expectedFees[1],
            "Royalty recipient should receive 0.1% of the whole price"
        );
        assertEq(
            weth.balanceOf(_owner),
            _initialWETHBalanceOwner + expectedFees[2],
            "Protocol fee recipient should receive 0.9% of the whole price"
        );
    }
}
