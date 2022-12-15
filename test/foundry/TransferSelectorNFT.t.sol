// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// LooksRare unopinionated libraries
import {IOwnableTwoSteps} from "@looksrare/contracts-libs/contracts/interfaces/IOwnableTwoSteps.sol";

// Interfaces
import {ITransferSelectorNFT} from "../../contracts/interfaces/ITransferSelectorNFT.sol";

// Base test
import {ProtocolBase} from "./ProtocolBase.t.sol";

contract TransferSelectorNFTTest is ProtocolBase, ITransferSelectorNFT {
    address public newTransferManager = address(69_420);

    // Wrong selector
    bytes4 public newSelector = 0x69696969;

    function testInitialStates() public {
        (address transferManager0, bytes4 selector0) = looksRareProtocol.managerSelectorOfAssetType(0);
        assertEq(transferManager0, address(transferManager));
        assertEq(uint32(selector0), uint32(0xa7bc96d3));

        (address transferManager1, bytes4 selector1) = looksRareProtocol.managerSelectorOfAssetType(1);
        assertEq(transferManager1, address(transferManager));
        assertEq(uint32(selector1), uint32(0xa0a406c6));
    }

    function testAddTransferManagerForAssetType() public asPrankedUser(_owner) {
        vm.expectEmit(true, false, false, true);
        emit NewAssetType(2, newTransferManager, newSelector);
        looksRareProtocol.addTransferManagerForAssetType(2, newTransferManager, newSelector);

        (address transferManager, bytes4 selector) = looksRareProtocol.managerSelectorOfAssetType(2);
        assertEq(transferManager, newTransferManager);
        assertEq(uint32(selector), uint32(newSelector));
    }

    function testAddTransferManagerForAssetTypeNotOwner() public {
        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        looksRareProtocol.addTransferManagerForAssetType(2, newTransferManager, newSelector);
    }

    function testAddTransferManagerForAssetTypeAlreadySet() public asPrankedUser(_owner) {
        vm.expectRevert(AlreadySet.selector);
        looksRareProtocol.addTransferManagerForAssetType(0, newTransferManager, newSelector);
    }
}
