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

contract LooksRareProtocolExecuteMultipleTakerBidsTest is ProtocolBase {
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
        _setUpUsers();

        (OrderStructs.Maker memory makerAsk, OrderStructs.Taker memory takerBid) = _createMockMakerAskAndTakerBid(
            address(mockERC721)
        );
        makerAsk.currency = address(mockERC20);

        // Mint asset
        mockERC721.mint(makerUser, makerAsk.itemIds[0]);

        // Sign order
        bytes memory signature = _signMakerOrder(makerAsk, makerUserPK);

        // Verify validity of maker ask order
        _assertMakerOrderReturnValidationCode(makerAsk, signature, CURRENCY_NOT_ALLOWED);

        vm.prank(takerUser);
        vm.expectRevert(CurrencyInvalid.selector);
        looksRareProtocol.executeTakerBid{value: price}(
            takerBid,
            makerAsk,
            signature,
            _EMPTY_MERKLE_TREE,
            _EMPTY_AFFILIATE
        );

        BatchExecutionParameters[] memory batchExecutionParameters = new BatchExecutionParameters[](1);
        batchExecutionParameters[0].maker = makerAsk;
        batchExecutionParameters[0].taker = takerBid;
        batchExecutionParameters[0].makerSignature = signature;

        bool[2] memory boolFlags = _boolFlagsArray();
        for (uint256 i; i < boolFlags.length; i++) {
            vm.prank(takerUser);
            vm.expectRevert(CurrencyInvalid.selector);
            looksRareProtocol.executeMultipleTakerBids{value: price}(
                batchExecutionParameters,
                _EMPTY_AFFILIATE,
                boolFlags[i]
            );
        }
    }

    function testCannotCallRestrictedExecuteTakerBid() public {
        _setUpUsers();

        (OrderStructs.Maker memory makerAsk, OrderStructs.Taker memory takerBid) = _createMockMakerAskAndTakerBid(
            address(mockERC721)
        );

        // Mint asset
        mockERC721.mint(makerUser, makerAsk.itemIds[0]);

        vm.prank(takerUser);
        vm.expectRevert(CallerInvalid.selector);
        looksRareProtocol.restrictedExecuteTakerOrder(takerBid, makerAsk, takerUser, _computeOrderHash(makerAsk));
    }

    /**
     * Cannot execute two or more taker bids if the currencies are different
     */
    function testCannotExecuteMultipleTakerBidsIfDifferentCurrenciesIsAtomic() public {
        _testCannotExecuteMultipleTakerBidsIfDifferentCurrencies(true);
    }

    function testCannotExecuteMultipleTakerBidsIfDifferentCurrenciesIsNonAtomic() public {
        _testCannotExecuteMultipleTakerBidsIfDifferentCurrencies(false);
    }

    function _testCannotExecuteMultipleTakerBidsIfDifferentCurrencies(bool isAtomic) public {
        _setUpUsers();
        vm.prank(_owner);
        looksRareProtocol.updateCurrencyStatus(address(mockERC20), true);

        uint256 numberPurchases = 2;

        BatchExecutionParameters[] memory batchExecutionParameters = _batchExecutionSetUp(
            price,
            numberPurchases,
            QuoteType.Ask
        );
        batchExecutionParameters[1].maker.currency = address(mockERC20);

        vm.prank(takerUser);
        vm.expectRevert(CurrencyInvalid.selector);
        looksRareProtocol.executeMultipleTakerBids{value: price}(batchExecutionParameters, _EMPTY_AFFILIATE, isAtomic);
    }
}
