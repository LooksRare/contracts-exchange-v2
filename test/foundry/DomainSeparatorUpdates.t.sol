// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// LooksRare unopinionated libraries
import {IOwnableTwoSteps} from "@looksrare/contracts-libs/contracts/interfaces/IOwnableTwoSteps.sol";
import {SignatureEOAInvalid} from "@looksrare/contracts-libs/contracts/errors/SignatureCheckerErrors.sol";

// Libraries and interfaces
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";
import {ILooksRareProtocol} from "../../contracts/interfaces/ILooksRareProtocol.sol";

// Base test
import {ProtocolBase} from "./ProtocolBase.t.sol";

contract DomainSeparatorUpdatesTest is ProtocolBase {
    function setUp() public {
        _setUp();
    }

    function testFuzz_UpdateDomainSeparator(uint64 newChainId) public asPrankedUser(_owner) {
        vm.assume(newChainId != block.chainid);

        vm.chainId(newChainId);
        vm.expectEmit({checkTopic1: true, checkTopic2: true, checkTopic3: true, checkData: true});
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

    function testFuzz_ExecuteTakerBid_RevertIf_DomainSeparatorHasBeenUpdated(uint64 newChainId) public {
        vm.assume(newChainId != block.chainid);

        _setUpUsers();

        // ChainId update
        vm.chainId(newChainId);

        // Owner updates the domain separator
        vm.prank(_owner);
        looksRareProtocol.updateDomainSeparator();

        (OrderStructs.Maker memory makerAsk, OrderStructs.Taker memory takerBid) = _createMockMakerAskAndTakerBid(
            address(mockERC721)
        );

        bytes memory signature = _signMakerOrder(makerAsk, makerUserPK);

        // Mint asset
        mockERC721.mint(makerUser, makerAsk.itemIds[0]);

        vm.prank(takerUser);
        vm.expectRevert(SignatureEOAInvalid.selector);
        looksRareProtocol.executeTakerBid{value: makerAsk.price}(
            takerBid,
            makerAsk,
            signature,
            _EMPTY_MERKLE_TREE,
            _EMPTY_AFFILIATE
        );
    }

    function testFuzz_ExecuteTakerBid_RevertIf_ChainIdHasChanged(uint64 newChainId) public {
        vm.assume(newChainId != block.chainid);

        _setUpUsers();

        // ChainId update
        vm.chainId(newChainId);

        (OrderStructs.Maker memory makerAsk, OrderStructs.Taker memory takerBid) = _createMockMakerAskAndTakerBid(
            address(mockERC721)
        );

        bytes memory signature = _signMakerOrder(makerAsk, makerUserPK);

        // Mint asset
        mockERC721.mint(makerUser, makerAsk.itemIds[0]);

        vm.prank(takerUser);
        vm.expectRevert(ILooksRareProtocol.ChainIdInvalid.selector);
        looksRareProtocol.executeTakerBid{value: makerAsk.price}(
            takerBid,
            makerAsk,
            signature,
            _EMPTY_MERKLE_TREE,
            _EMPTY_AFFILIATE
        );
    }

    function test_UpdateDomainSeparator_RevertIf_SameDomainSeparator() public asPrankedUser(_owner) {
        vm.expectRevert(SameDomainSeparator.selector);
        looksRareProtocol.updateDomainSeparator();
    }

    function test_UpdateDomainSeparator_RevertIf_NotOwner() public {
        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        looksRareProtocol.updateDomainSeparator();
    }
}
