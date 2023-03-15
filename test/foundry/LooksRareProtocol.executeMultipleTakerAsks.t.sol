// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// LooksRare unopinionated libraries
import {IOwnableTwoSteps} from "@looksrare/contracts-libs/contracts/interfaces/IOwnableTwoSteps.sol";

// Libraries
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";

// Base test
import {ProtocolBase} from "./ProtocolBase.t.sol";

// Shared errors
import {AmountInvalid, CallerInvalid, CurrencyInvalid, OrderInvalid, QuoteTypeInvalid} from "../../contracts/errors/SharedErrors.sol";
import {CURRENCY_NOT_ALLOWED, MAKER_ORDER_INVALID_STANDARD_SALE} from "../../contracts/constants/ValidationCodeConstants.sol";

// Other mocks and utils
import {MockERC20} from "../mock/MockERC20.sol";

// Enums
import {CollectionType} from "../../contracts/enums/CollectionType.sol";
import {QuoteType} from "../../contracts/enums/QuoteType.sol";

contract LooksRareProtocolExecuteMultipleTakerAsksTest is ProtocolBase {
    // Fixed price of sale
    uint256 private constant price = 1 ether;

    // Mock files
    MockERC20 private mockERC20;

    function setUp() public {
        _setUp();
        vm.prank(_owner);
        mockERC20 = new MockERC20();
    }

    function testCannotTradeIfCurrencyInvalid() public {
        _testCannotTradeIfCurrencyInvalid(address(mockERC20));
    }

    function testCannotTradeIfETHIsUsedForMakerBid() public {
        _testCannotTradeIfCurrencyInvalid(ETH);
    }

    function testCannotCallRestrictedExecuteTakerAsk() public {
        _setUpUsers();

        (OrderStructs.Maker memory makerBid, OrderStructs.Taker memory takerAsk) = _createMockMakerBidAndTakerAsk(
            address(mockERC721),
            address(mockERC20)
        );

        // Mint asset
        mockERC721.mint(takerUser, makerBid.itemIds[0]);

        vm.prank(takerUser);
        vm.expectRevert(CallerInvalid.selector);
        looksRareProtocol.restrictedExecuteTakerAsk(takerAsk, makerBid, takerUser, _computeOrderHash(makerBid));
    }

    /**
     * Cannot execute two or more taker bids if the currencies are different
     */
    function testCannotExecuteMultipleTakerAsksIfDifferentCurrenciesIsAtomic() public {
        _testCannotExecuteMultipleTakerAsksIfDifferentCurrencies(true);
    }

    function testCannotExecuteMultipleTakerAsksIfDifferentCurrenciesIsNonAtomic() public {
        _testCannotExecuteMultipleTakerAsksIfDifferentCurrencies(false);
    }

    function _testCannotExecuteMultipleTakerAsksIfDifferentCurrencies(bool isAtomic) public {
        _setUpUsers();
        vm.prank(_owner);
        looksRareProtocol.updateCurrencyStatus(address(weth), true);

        uint256 numberPurchases = 2;

        BatchExecutionParameters[] memory batchExecutionParameters = new BatchExecutionParameters[](numberPurchases);

        for (uint256 i; i < numberPurchases; i++) {
            // Mint asset
            mockERC721.mint(takerUser, i);

            batchExecutionParameters[i].maker = _createSingleItemMakerOrder({
                quoteType: QuoteType.Bid,
                globalNonce: 0,
                subsetNonce: 0,
                strategyId: STANDARD_SALE_FOR_FIXED_PRICE_STRATEGY,
                collectionType: CollectionType.ERC721,
                orderNonce: i,
                collection: address(mockERC721),
                currency: address(weth),
                signer: makerUser,
                price: price, // Fixed
                itemId: i // (0, 1, etc.)
            });

            if (i == 1) {
                batchExecutionParameters[i].maker.currency = address(mockERC20);
            }

            // Sign order
            batchExecutionParameters[i].makerSignature = _signMakerOrder(
                batchExecutionParameters[i].maker,
                makerUserPK
            );

            batchExecutionParameters[i].taker = _genericTakerOrder();
        }

        vm.prank(takerUser);
        vm.expectRevert(CurrencyInvalid.selector);
        looksRareProtocol.executeMultipleTakerAsks(batchExecutionParameters, _EMPTY_AFFILIATE, isAtomic);
    }

    function _testCannotTradeIfCurrencyInvalid(address currency) private {
        _setUpUsers();

        (OrderStructs.Maker memory makerBid, OrderStructs.Taker memory takerAsk) = _createMockMakerBidAndTakerAsk(
            address(mockERC721),
            currency
        );

        // Mint asset
        mockERC721.mint(takerUser, makerBid.itemIds[0]);

        // Sign order
        bytes memory signature = _signMakerOrder(makerBid, makerUserPK);

        // Verify validity of maker ask order
        _assertMakerOrderReturnValidationCode(makerBid, signature, CURRENCY_NOT_ALLOWED);

        BatchExecutionParameters[] memory batchExecutionParameters = new BatchExecutionParameters[](1);

        batchExecutionParameters[0].maker = makerBid;
        batchExecutionParameters[0].taker = takerAsk;
        batchExecutionParameters[0].makerSignature = signature;

        bool[2] memory boolFlags = _boolFlagsArray();
        for (uint256 i; i < boolFlags.length; i++) {
            vm.prank(takerUser);
            vm.expectRevert(CurrencyInvalid.selector);
            looksRareProtocol.executeMultipleTakerAsks(batchExecutionParameters, _EMPTY_AFFILIATE, boolFlags[i]);
        }
    }
}
