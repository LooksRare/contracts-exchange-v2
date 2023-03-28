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

contract LooksRareProtocolTest is ProtocolBase {
    // Fixed price of sale
    uint256 private constant price = 1 ether;

    // Mock files
    MockERC20 private mockERC20;

    function setUp() public {
        _setUp();
        vm.prank(_owner);
        mockERC20 = new MockERC20();
    }

    function test_Trade_RevertIf_InvalidAmounts() public {
        _setUpUsers();

        (OrderStructs.Maker memory makerAsk, OrderStructs.Taker memory takerBid) = _createMockMakerAskAndTakerBid(
            address(mockERC721)
        );

        // Mint asset
        mockERC721.mint(makerUser, makerAsk.itemIds[0]);

        // 1. Amount = 0
        makerAsk.amounts[0] = 0;

        // Sign order
        bytes memory signature = _signMakerOrder(makerAsk, makerUserPK);

        _assertMakerOrderReturnValidationCode(makerAsk, signature, MAKER_ORDER_INVALID_STANDARD_SALE);

        vm.prank(takerUser);
        vm.expectRevert(OrderInvalid.selector);
        looksRareProtocol.executeTakerBid{value: price}(
            takerBid,
            makerAsk,
            signature,
            _EMPTY_MERKLE_TREE,
            _EMPTY_AFFILIATE
        );

        // 2. Amount > 1 for ERC721
        makerAsk.amounts[0] = 2;

        // Sign order
        signature = _signMakerOrder(makerAsk, makerUserPK);

        _assertMakerOrderReturnValidationCode(makerAsk, signature, MAKER_ORDER_INVALID_STANDARD_SALE);

        vm.prank(takerUser);
        vm.expectRevert(AmountInvalid.selector);
        looksRareProtocol.executeTakerBid{value: price}(
            takerBid,
            makerAsk,
            signature,
            _EMPTY_MERKLE_TREE,
            _EMPTY_AFFILIATE
        );
    }

    function test_Trade_RevertIf_ETHIsUsedForMakerBid() public {
        (OrderStructs.Maker memory makerBid, OrderStructs.Taker memory takerAsk) = _createMockMakerBidAndTakerAsk(
            address(mockERC721),
            ETH
        );

        // Sign order
        bytes memory signature = _signMakerOrder(makerBid, makerUserPK);

        // Verify maker bid order
        _assertMakerOrderReturnValidationCode(makerBid, signature, CURRENCY_NOT_ALLOWED);

        // Mint asset
        mockERC721.mint(takerUser, makerBid.itemIds[0]);

        // Execute taker ask transaction
        vm.prank(takerUser);
        vm.expectRevert(CurrencyInvalid.selector);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function test_Trade_RevertIf_InvalidQuoteType() public {
        // 1. QuoteType = BID but executeTakerBid
        (OrderStructs.Maker memory makerBid, OrderStructs.Taker memory takerAsk) = _createMockMakerBidAndTakerAsk(
            address(mockERC721),
            address(weth)
        );

        // Sign order
        bytes memory signature = _signMakerOrder(makerBid, makerUserPK);

        vm.prank(takerUser);
        vm.expectRevert(QuoteTypeInvalid.selector);
        looksRareProtocol.executeTakerBid(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);

        // 2. QuoteType = ASK but executeTakerAsk
        (OrderStructs.Maker memory makerAsk, OrderStructs.Taker memory takerBid) = _createMockMakerAskAndTakerBid(
            address(mockERC721)
        );
        makerAsk.currency = address(weth);

        // Sign order
        signature = _signMakerOrder(makerAsk, makerUserPK);

        vm.prank(takerUser);
        vm.expectRevert(QuoteTypeInvalid.selector);
        looksRareProtocol.executeTakerAsk(takerBid, makerAsk, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function test_UpdateETHGasLimitForTransfer() public asPrankedUser(_owner) {
        vm.expectEmit({checkTopic1: true, checkTopic2: true, checkTopic3: true, checkData: true});
        emit NewGasLimitETHTransfer(10_000);
        looksRareProtocol.updateETHGasLimitForTransfer(10_000);
        assertEq(uint256(vm.load(address(looksRareProtocol), bytes32(uint256(14)))), 10_000);
    }

    function test_UpdateETHGasLimitForTransfer_RevertIf_TooLow() public asPrankedUser(_owner) {
        uint256 newGasLimitETHTransfer = 2_300;
        vm.expectRevert(NewGasLimitETHTransferTooLow.selector);
        looksRareProtocol.updateETHGasLimitForTransfer(newGasLimitETHTransfer - 1);

        looksRareProtocol.updateETHGasLimitForTransfer(newGasLimitETHTransfer);
        assertEq(uint256(vm.load(address(looksRareProtocol), bytes32(uint256(14)))), newGasLimitETHTransfer);
    }

    function test_UpdateETHGasLimitForTransfer_RevertIf_NotOwner() public {
        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        looksRareProtocol.updateETHGasLimitForTransfer(10_000);
    }
}
