// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// LooksRare unopinionated libraries
import {IOwnableTwoSteps} from "@looksrare/contracts-libs/contracts/interfaces/IOwnableTwoSteps.sol";

// Libraries
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";

// Base test
import {ProtocolBase} from "./ProtocolBase.t.sol";

// Shared errors
import {WrongCaller, WrongCurrency} from "../../contracts/interfaces/SharedErrors.sol";
import {CURRENCY_NOT_WHITELISTED} from "../../contracts/helpers/ValidationCodeConstants.sol";

// Other mocks and utils
import {MockERC20} from "../mock/MockERC20.sol";

contract LooksRareProtocolTest is ProtocolBase {
    // Fixed price of sale
    uint256 private constant price = 1 ether;

    // Mock files
    MockERC20 private mockERC20;

    function setUp() public override {
        super.setUp();
        vm.prank(_owner);
        mockERC20 = new MockERC20();
    }

    function testCannotTradeIfWrongCurrency() public {
        _setUpUsers();
        uint256 itemId = 0; // TokenId

        // Mint asset
        mockERC721.mint(makerUser, itemId);

        // Prepare the order hash
        OrderStructs.MakerAsk memory makerAsk = _createSingleItemMakerAskOrder({
            askNonce: 0,
            subsetNonce: 0,
            strategyId: 0, // Standard sale for fixed price
            assetType: 0, // ERC721,
            orderNonce: 0,
            collection: address(mockERC721),
            currency: address(mockERC20),
            signer: makerUser,
            minPrice: price,
            itemId: itemId
        });

        // Sign order
        bytes memory signature = _signMakerAsk(makerAsk, makerUserPK);

        // Verify validity of maker ask order
        _doesMakerAskOrderReturnValidationCode(makerAsk, signature, CURRENCY_NOT_WHITELISTED);

        // Prepare the taker bid
        OrderStructs.TakerBid memory takerBid = OrderStructs.TakerBid(
            takerUser,
            makerAsk.minPrice,
            makerAsk.itemIds,
            makerAsk.amounts,
            abi.encode()
        );

        vm.prank(takerUser);
        vm.expectRevert(WrongCurrency.selector);
        looksRareProtocol.executeTakerBid{value: price}(
            takerBid,
            makerAsk,
            signature,
            _EMPTY_MERKLE_TREE,
            _EMPTY_AFFILIATE
        );
    }

    function testCannotTradeIfETHIsUsedForMakerBid() public {
        uint256 itemId = 0; // TokenId

        // Prepare the order hash
        OrderStructs.MakerBid memory makerBid = _createSingleItemMakerBidOrder({
            bidNonce: 0,
            subsetNonce: 0,
            strategyId: 0, // Standard sale for fixed price
            assetType: 0, // ERC721,
            orderNonce: 0,
            collection: address(mockERC721),
            currency: address(0), // ETH
            signer: makerUser,
            maxPrice: price,
            itemId: itemId
        });

        // Sign order
        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        // Verify maker bid order
        _doesMakerBidOrderReturnValidationCode(makerBid, signature, CURRENCY_NOT_WHITELISTED);

        // Mint asset
        mockERC721.mint(takerUser, itemId);

        // Prepare the taker ask
        OrderStructs.TakerAsk memory takerAsk = OrderStructs.TakerAsk(
            takerUser,
            makerBid.maxPrice,
            makerBid.itemIds,
            makerBid.amounts,
            abi.encode()
        );

        // Execute taker ask transaction
        vm.prank(takerUser);
        vm.expectRevert(WrongCurrency.selector);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function testUpdateETHGasLimitForTransfer() public asPrankedUser(_owner) {
        vm.expectEmit(true, false, false, true);
        emit NewGasLimitETHTransfer(10_000);
        looksRareProtocol.updateETHGasLimitForTransfer(10_000);
        assertEq(uint256(vm.load(address(looksRareProtocol), bytes32(uint256(16)))), 10_000);
    }

    function testUpdateETHGasLimitForTransferRevertsIfTooLow() public asPrankedUser(_owner) {
        uint256 newGasLimitETHTransfer = 2_300;
        vm.expectRevert(NewGasLimitETHTransferTooLow.selector);
        looksRareProtocol.updateETHGasLimitForTransfer(newGasLimitETHTransfer - 1);

        looksRareProtocol.updateETHGasLimitForTransfer(newGasLimitETHTransfer);
        assertEq(uint256(vm.load(address(looksRareProtocol), bytes32(uint256(16)))), newGasLimitETHTransfer);
    }

    function testUpdateETHGasLimitForTransferNotOwner() public {
        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        looksRareProtocol.updateETHGasLimitForTransfer(10_000);
    }

    function testCannotCallRestrictedExecuteTakerBid() public {
        _setUpUsers();
        uint256 itemId = 0;

        // Mint asset
        mockERC721.mint(makerUser, itemId);

        // Prepare the orders and signature
        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid, ) = _createSingleItemMakerAskAndTakerBidOrderAndSignature({
            askNonce: 0,
            subsetNonce: 0,
            strategyId: 0, // Standard sale for fixed price
            assetType: 0, // ERC721,
            orderNonce: 0,
            collection: address(mockERC721),
            currency: address(0), // ETH
            signer: makerUser,
            minPrice: price,
            itemId: itemId
        });

        vm.prank(takerUser);
        vm.expectRevert(WrongCaller.selector);
        looksRareProtocol.restrictedExecuteTakerBid(takerBid, makerAsk, takerUser, _computeOrderHashMakerAsk(makerAsk));
    }

    function testUpdateDomainSeparator() public {
        uint256 newChainId = 69_420;
        vm.chainId(newChainId);
        vm.expectEmit(true, false, false, false);
        emit NewDomainSeparator();
        looksRareProtocol.updateDomainSeparator();
        assertEq(looksRareProtocol.chainId(), newChainId);
        assertEq(
            looksRareProtocol.domainSeparator(),
            keccak256(
                abi.encode(
                    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                    keccak256("LooksRareProtocol"),
                    keccak256(bytes("2")),
                    newChainId,
                    address(looksRareProtocol)
                )
            )
        );
    }

    function testUpdateDomainSeparatorSameDomainSeparator() public {
        vm.expectRevert(SameDomainSeparator.selector);
        looksRareProtocol.updateDomainSeparator();
    }
}
