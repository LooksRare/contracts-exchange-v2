// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// LooksRare unopinionated libraries
import {IOwnableTwoSteps} from "@looksrare/contracts-libs/contracts/interfaces/IOwnableTwoSteps.sol";
import {InvalidSignatureEOA} from "@looksrare/contracts-libs/contracts/errors/SignatureCheckerErrors.sol";

// Libraries and interfaces
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";
import {ILooksRareProtocol} from "../../contracts/interfaces/ILooksRareProtocol.sol";

// Base test
import {ProtocolBase} from "./ProtocolBase.t.sol";

// Constants
import {ASSET_TYPE_ERC721} from "../../contracts/constants/NumericConstants.sol";

contract DomainSeparatorUpdatesTest is ProtocolBase {
    function testUpdateDomainSeparator(uint64 newChainId) public asPrankedUser(_owner) {
        vm.assume(newChainId != block.chainid);

        vm.chainId(newChainId);
        vm.expectEmit({checkTopic1: true, checkTopic2: false, checkTopic3: false, checkData: true});
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

    function testCannotTradeIfDomainSeparatorHasBeenUpdated(uint64 newChainId) public {
        vm.assume(newChainId != block.chainid);

        _setUpUsers();
        uint256 itemId = 42;
        uint256 price = 2 ether;

        // ChainId update
        vm.chainId(newChainId);

        // Owner updates the domain separator
        vm.prank(_owner);
        looksRareProtocol.updateDomainSeparator();

        // Mint asset
        mockERC721.mint(makerUser, itemId);

        // Prepare the orders and signature
        (
            OrderStructs.MakerAsk memory makerAsk,
            OrderStructs.TakerOrder memory takerBid,
            bytes memory signature
        ) = _createSingleItemMakerAskAndTakerBidOrderAndSignature({
                askNonce: 0,
                subsetNonce: 0,
                strategyId: STANDARD_SALE_FOR_FIXED_PRICE_STRATEGY,
                assetType: ASSET_TYPE_ERC721,
                orderNonce: 0,
                collection: address(mockERC721),
                currency: ETH,
                signer: makerUser,
                minPrice: price,
                itemId: itemId
            });

        vm.prank(takerUser);
        vm.expectRevert(InvalidSignatureEOA.selector);
        looksRareProtocol.executeTakerBid{value: price}(
            takerBid,
            makerAsk,
            signature,
            _EMPTY_MERKLE_TREE,
            _EMPTY_AFFILIATE
        );
    }

    function testCannotTradeIfChainIdHasChanged(uint64 newChainId) public {
        vm.assume(newChainId != block.chainid);

        _setUpUsers();

        uint256 itemId = 42;
        uint256 price = 2 ether;

        // ChainId update
        vm.chainId(newChainId);

        // Mint asset
        mockERC721.mint(makerUser, itemId);

        // Prepare the orders and signature
        (
            OrderStructs.MakerAsk memory makerAsk,
            OrderStructs.TakerOrder memory takerBid,
            bytes memory signature
        ) = _createSingleItemMakerAskAndTakerBidOrderAndSignature({
                askNonce: 0,
                subsetNonce: 0,
                strategyId: STANDARD_SALE_FOR_FIXED_PRICE_STRATEGY,
                assetType: ASSET_TYPE_ERC721,
                orderNonce: 0,
                collection: address(mockERC721),
                currency: ETH,
                signer: makerUser,
                minPrice: price,
                itemId: itemId
            });

        vm.prank(takerUser);
        vm.expectRevert(ILooksRareProtocol.WrongChainId.selector);
        looksRareProtocol.executeTakerBid{value: price}(
            takerBid,
            makerAsk,
            signature,
            _EMPTY_MERKLE_TREE,
            _EMPTY_AFFILIATE
        );
    }

    function testUpdateDomainSeparatorSameDomainSeparator() public asPrankedUser(_owner) {
        vm.expectRevert(SameDomainSeparator.selector);
        looksRareProtocol.updateDomainSeparator();
    }

    function testUpdateDomainSeparatorNotOwner() public {
        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        looksRareProtocol.updateDomainSeparator();
    }
}
