// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// LooksRare unopinionated libraries
import {IOwnableTwoSteps} from "@looksrare/contracts-libs/contracts/interfaces/IOwnableTwoSteps.sol";

// Libraries
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";

// Interfaces
import {IAffiliateManager} from "../../contracts/interfaces/IAffiliateManager.sol";
import {ILooksRareProtocol} from "../../contracts/interfaces/ILooksRareProtocol.sol";

// Mocks and other tests
import {ProtocolBase} from "./ProtocolBase.t.sol";
import {MockERC20} from "../mock/MockERC20.sol";

// Constants
import {ONE_HUNDRED_PERCENT_IN_BP} from "../../contracts/constants/NumericConstants.sol";

// Enums
import {CollectionType} from "../../contracts/enums/CollectionType.sol";
import {QuoteType} from "../../contracts/enums/QuoteType.sol";

contract AffiliateOrdersTest is ProtocolBase, IAffiliateManager {
    function setUp() public {
        _setUp();
    }

    // Affiliate rate
    uint256 internal _affiliateRate = 2_000;
    uint256 private constant price = 1 ether; // Fixed price of sale

    function _calculateAffiliateFee(
        uint256 originalAmount,
        uint256 tierRate
    ) private pure returns (uint256 affiliateFee) {
        affiliateFee = (originalAmount * tierRate) / (ONE_HUNDRED_PERCENT_IN_BP * ONE_HUNDRED_PERCENT_IN_BP);
    }

    function _setUpAffiliate() private {
        vm.startPrank(_owner);
        looksRareProtocol.updateAffiliateController(_owner);
        looksRareProtocol.updateAffiliateProgramStatus(true);
        looksRareProtocol.updateAffiliateRate(_affiliate, _affiliateRate);
        vm.stopPrank();

        vm.deal(_affiliate, _initialETHBalanceAffiliate + _initialWETHBalanceAffiliate);
        vm.prank(_affiliate);
        weth.deposit{value: _initialWETHBalanceAffiliate}();
    }

    function testEventsAreEmittedAsExpected() public asPrankedUser(_owner) {
        // 1. NewAffiliateController
        vm.expectEmit({checkTopic1: true, checkTopic2: false, checkTopic3: false, checkData: true});
        emit NewAffiliateController(_owner);
        looksRareProtocol.updateAffiliateController(_owner);

        // 2. NewAffiliateProgramStatus
        bool[2] memory boolFlags = _boolFlagsArray();
        for (uint256 i; i < boolFlags.length; i++) {
            vm.expectEmit({checkTopic1: true, checkTopic2: false, checkTopic3: false, checkData: true});
            emit NewAffiliateProgramStatus(boolFlags[i]);
            looksRareProtocol.updateAffiliateProgramStatus(boolFlags[i]);
        }

        // 3. NewAffiliateRate
        vm.expectEmit({checkTopic1: true, checkTopic2: false, checkTopic3: false, checkData: true});
        emit NewAffiliateRate(takerUser, 30);
        looksRareProtocol.updateAffiliateRate(takerUser, 30);
    }

    function testCannotUpdateAffiliateRateIfNotAffiliateController() public {
        vm.expectRevert(IAffiliateManager.NotAffiliateController.selector);
        looksRareProtocol.updateAffiliateRate(address(42), 100);
    }

    function testCannotUpdateAffiliateRateIfRateHigherthan10000() public asPrankedUser(_owner) {
        looksRareProtocol.updateAffiliateController(_owner);

        address randomAffiliate = address(42);
        uint256 affiliateRateLimitBp = ONE_HUNDRED_PERCENT_IN_BP;
        vm.expectRevert(IAffiliateManager.PercentageTooHigh.selector);
        looksRareProtocol.updateAffiliateRate(randomAffiliate, affiliateRateLimitBp + 1);

        // It does not revert
        looksRareProtocol.updateAffiliateRate(randomAffiliate, affiliateRateLimitBp);
        assertEq(looksRareProtocol.affiliateRates(randomAffiliate), affiliateRateLimitBp);
    }

    function testUpdateAffiliateControllerNotOwner() public {
        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        looksRareProtocol.updateAffiliateController(address(0));
    }

    function testUpdateAffiliateProgramStatusNotOwner() public {
        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        looksRareProtocol.updateAffiliateProgramStatus(false);
    }

    /**
     * TakerBid matches makerAsk. Protocol fee is set, no royalties, affiliate is set.
     */
    function testTakerBidERC721WithAffiliateButWithoutRoyalty() public {
        _setUpUsers();
        _setUpAffiliate();

        (OrderStructs.Maker memory makerAsk, OrderStructs.Taker memory takerBid) = _createMockMakerAskAndTakerBid(
            address(mockERC721)
        );

        // Mint asset
        mockERC721.mint(makerUser, makerAsk.itemIds[0]);

        // Sign order
        bytes memory signature = _signMakerOrder(makerAsk, makerUserPK);

        // Verify validity of maker ask order
        _assertValidMakerOrder(makerAsk, signature);

        uint256 expectedAffiliateFeeAmount = _calculateAffiliateFee(price * _minTotalFeeBp, _affiliateRate);

        // Execute taker bid transaction
        vm.prank(takerUser);
        vm.expectEmit({checkTopic1: true, checkTopic2: false, checkTopic3: false, checkData: true});
        emit AffiliatePayment(_affiliate, makerAsk.currency, expectedAffiliateFeeAmount);
        looksRareProtocol.executeTakerBid{value: price}(takerBid, makerAsk, signature, _EMPTY_MERKLE_TREE, _affiliate);

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(makerAsk.itemIds[0]), takerUser);
        // Taker bid user pays the whole price
        assertEq(address(takerUser).balance, _initialETHBalanceUser - price);
        // Maker ask user receives 99.5% of the whole price (0.5% protocol)
        assertEq(
            address(makerUser).balance,
            _initialETHBalanceUser + (price * (ONE_HUNDRED_PERCENT_IN_BP - _minTotalFeeBp)) / ONE_HUNDRED_PERCENT_IN_BP
        );
        // Affiliate user receives 20% of protocol fee
        assertEq(address(_affiliate).balance, _initialETHBalanceAffiliate + expectedAffiliateFeeAmount);
        // Owner receives 80% of protocol fee
        assertEq(
            address(_owner).balance,
            _initialETHBalanceOwner +
                ((price * _minTotalFeeBp) / ONE_HUNDRED_PERCENT_IN_BP - expectedAffiliateFeeAmount)
        );
        // No leftover in the balance of the contract
        assertEq(address(looksRareProtocol).balance, 0);
        // Verify the nonce is marked as executed
        assertEq(looksRareProtocol.userOrderNonce(makerUser, makerAsk.orderNonce), MAGIC_VALUE_ORDER_NONCE_EXECUTED);
    }

    /**
     * Multiple takerBids match makerAsk orders. Protocol fee is set, no royalties, affiliate is set.
     */
    function testMultipleTakerBidsERC721WithAffiliateButWithoutRoyalty() public {
        _setUpUsers();
        _setUpAffiliate();

        uint256 numberOfPurchases = 8;
        uint256 faultyTokenId = numberOfPurchases - 1;

        BatchExecutionParameters[] memory batchExecutionParameters = _batchERC721ExecutionSetUp(
            price,
            numberOfPurchases,
            QuoteType.Ask
        );

        // Transfer tokenId=7 to random user
        vm.prank(makerUser);
        mockERC721.transferFrom(makerUser, _randomUser, faultyTokenId);

        uint256 expectedAffiliateFeeAmount = _calculateAffiliateFee(
            (numberOfPurchases - 1) * price * _minTotalFeeBp,
            _affiliateRate
        );

        // Execute taker bid transaction
        vm.prank(takerUser);
        vm.expectEmit({checkTopic1: true, checkTopic2: false, checkTopic3: false, checkData: true});
        emit AffiliatePayment(_affiliate, ETH, expectedAffiliateFeeAmount);
        looksRareProtocol.executeMultipleTakerBids{value: price * numberOfPurchases}(
            batchExecutionParameters,
            _affiliate,
            false
        );

        for (uint256 i; i < faultyTokenId; i++) {
            // Taker user has received the first seven assets
            assertEq(mockERC721.ownerOf(i), takerUser);
            // Verify the first seven nonces are marked as executed
            assertEq(looksRareProtocol.userOrderNonce(makerUser, i), MAGIC_VALUE_ORDER_NONCE_EXECUTED);
        }

        // Taker user has not received the asset
        assertEq(mockERC721.ownerOf(faultyTokenId), _randomUser);
        // Verify the nonce is NOT marked as executed
        assertEq(looksRareProtocol.userOrderNonce(makerUser, faultyTokenId), bytes32(0));
        // Taker bid user pays the whole price
        assertEq(address(takerUser).balance, _initialETHBalanceUser - 1 - ((numberOfPurchases - 1) * price));
        // Maker ask user receives 99.5% of the whole price (0.5% protocol)
        assertEq(
            address(makerUser).balance,
            _initialETHBalanceUser +
                ((price * _sellerProceedBpWithStandardProtocolFeeBp) * (numberOfPurchases - 1)) /
                ONE_HUNDRED_PERCENT_IN_BP
        );
        // Affiliate user receives 20% of protocol fee
        assertEq(address(_affiliate).balance, _initialETHBalanceAffiliate + expectedAffiliateFeeAmount);
        // Owner receives 80% of protocol fee
        assertEq(
            address(_owner).balance,
            _initialETHBalanceOwner +
                (((numberOfPurchases - 1) * (price * _minTotalFeeBp)) /
                    ONE_HUNDRED_PERCENT_IN_BP -
                    expectedAffiliateFeeAmount)
        );
        // Only 1 wei left in the balance of the contract
        assertEq(address(looksRareProtocol).balance, 1);
    }

    /**
     * Multiple takerAsks match makerBid orders. Protocol fee is set, no royalties, affiliate is set.
     */
    function testMultipleTakerAsksERC721WithAffiliateButWithoutRoyalty() public {
        _setUpUsers();
        _setUpAffiliate();

        uint256 numberOfPurchases = 8;
        uint256 faultyTokenId = numberOfPurchases - 1;

        BatchExecutionParameters[] memory batchExecutionParameters = _batchERC721ExecutionSetUp(
            price,
            numberOfPurchases,
            QuoteType.Bid
        );

        // Transfer tokenId=7 to random user
        vm.prank(takerUser);
        mockERC721.transferFrom(takerUser, _randomUser, faultyTokenId);

        uint256 perTradeExpectedAffiliateFeeAmount = _calculateAffiliateFee(price * _minTotalFeeBp, _affiliateRate);

        // Execute taker bid transaction
        vm.prank(takerUser);
        vm.expectEmit({checkTopic1: true, checkTopic2: false, checkTopic3: false, checkData: true});
        emit AffiliatePayment(_affiliate, address(weth), perTradeExpectedAffiliateFeeAmount);
        looksRareProtocol.executeMultipleTakerAsks(batchExecutionParameters, _affiliate, false);

        for (uint256 i; i < faultyTokenId; i++) {
            assertEq(mockERC721.ownerOf(i), makerUser, "Maker user should have received the first seven assets");
            assertEq(
                looksRareProtocol.userOrderNonce(makerUser, i),
                MAGIC_VALUE_ORDER_NONCE_EXECUTED,
                "The first seven nonces should be marked as executed"
            );
        }

        assertEq(mockERC721.ownerOf(faultyTokenId), _randomUser, "Maker user should not have received the asset");
        assertEq(
            looksRareProtocol.userOrderNonce(makerUser, faultyTokenId),
            bytes32(0),
            "The nonce should not be marked as executed"
        );
        uint256 totalCost = (numberOfPurchases - 1) * price;
        assertEq(
            weth.balanceOf(makerUser),
            _initialWETHBalanceUser - totalCost,
            "Maker bid user should pay the whole price"
        );
        _assertSellerReceivedWETHAfterStandardProtocolFee(takerUser, totalCost);
        assertEq(
            weth.balanceOf(_affiliate),
            _initialWETHBalanceAffiliate + perTradeExpectedAffiliateFeeAmount * (numberOfPurchases - 1),
            "Affiliate user should receive 20% of protocol fee"
        );
        assertEq(
            weth.balanceOf(_owner),
            _initialWETHBalanceOwner +
                (totalCost * _minTotalFeeBp) /
                ONE_HUNDRED_PERCENT_IN_BP -
                perTradeExpectedAffiliateFeeAmount *
                (numberOfPurchases - 1),
            "Owner should receive 80% of protocol fee"
        );
    }

    /**
     * TakerAsk matches makerBid. Protocol fee is set, no royalties, affiliate is set.
     */
    function testTakerAskERC721WithAffiliateButWithoutRoyalty() public {
        _setUpUsers();
        _setUpAffiliate();

        (OrderStructs.Maker memory makerBid, OrderStructs.Taker memory takerAsk) = _createMockMakerBidAndTakerAsk(
            address(mockERC721),
            address(weth)
        );

        // Sign order
        bytes memory signature = _signMakerOrder(makerBid, makerUserPK);

        // Verify validity of maker bid order
        _assertValidMakerOrder(makerBid, signature);

        // Mint asset
        mockERC721.mint(takerUser, makerBid.itemIds[0]);

        uint256 expectedAffiliateFeeAmount = _calculateAffiliateFee(price * _minTotalFeeBp, _affiliateRate);

        // Execute taker ask transaction
        vm.prank(takerUser);
        vm.expectEmit({checkTopic1: true, checkTopic2: false, checkTopic3: false, checkData: true});
        emit AffiliatePayment(_affiliate, makerBid.currency, expectedAffiliateFeeAmount);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _affiliate);

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(makerBid.itemIds[0]), makerUser);
        // Maker bid user pays the whole price
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser - price);
        _assertSellerReceivedWETHAfterStandardProtocolFee(takerUser, price);
        // Affiliate user receives 20% of protocol fee
        assertEq(weth.balanceOf(_affiliate), _initialWETHBalanceAffiliate + expectedAffiliateFeeAmount);
        // Owner receives 80% of protocol fee
        assertEq(
            weth.balanceOf(_owner),
            _initialWETHBalanceOwner +
                ((price * _minTotalFeeBp) / ONE_HUNDRED_PERCENT_IN_BP - expectedAffiliateFeeAmount)
        );
        // Verify the nonce is marked as executed
        assertEq(looksRareProtocol.userOrderNonce(makerUser, makerBid.orderNonce), MAGIC_VALUE_ORDER_NONCE_EXECUTED);
    }
}
