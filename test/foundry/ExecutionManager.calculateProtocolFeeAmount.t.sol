// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Libraries and interfaces
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";
import {IExecutionManager} from "../../contracts/interfaces/IExecutionManager.sol";
import {IStrategyManager} from "../../contracts/interfaces/IStrategyManager.sol";

// Base test
import {ProtocolBase} from "./ProtocolBase.t.sol";

// Constants
import {ONE_HUNDRED_PERCENT_IN_BP} from "../../contracts/constants/NumericConstants.sol";

contract ExecutionManagerCalculateProtocolFeeAmountTest is ProtocolBase, IExecutionManager, IStrategyManager {
    function setUp() public {
        _setUp();
    }

    function test_calculateProtocolFeeAmount_ProtocolFeeAmountPlusCreatorFeeAmountLessThanMinTotalFeeAmount(
        uint256 price
    ) public {
        vm.assume(price > 0 && price <= _initialETHBalanceUser);

        vm.prank(_owner);
        looksRareProtocol.updateStrategy({
            strategyId: 0,
            isActive: true,
            newStandardProtocolFeeBp: uint16(50),
            newMinTotalFeeBp: uint16(100)
        });

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
        expectedRecipients[1] = address(0);

        // Execute taker bid transaction
        vm.prank(takerUser);
        vm.expectEmit({checkTopic1: true, checkTopic2: false, checkTopic3: false, checkData: true});

        emit TakerBid(
            NonceInvalidationParameters({
                orderHash: _computeOrderHash(makerAsk),
                orderNonce: makerAsk.orderNonce,
                isNonceInvalidated: true
            }),
            takerUser,
            takerUser,
            makerAsk.strategyId,
            makerAsk.currency,
            makerAsk.collection,
            makerAsk.itemIds,
            makerAsk.amounts,
            expectedRecipients,
            expectedFees
        );

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

    function _calculateExpectedFees(uint256 price) private pure returns (uint256[3] memory expectedFees) {
        expectedFees[2] = (price * 100) / ONE_HUNDRED_PERCENT_IN_BP;
        expectedFees[0] = price - expectedFees[2];
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
        // Seller receives 99% of the whole price
        assertEq(seller.balance, _initialETHBalanceUser + expectedFees[0]);
        // Protocol fee recipient receives 1% of the whole price
        assertEq(_owner.balance, _initialETHBalanceOwner + expectedFees[2]);
    }
}
