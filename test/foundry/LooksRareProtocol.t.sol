// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// LooksRare unopinionated libraries
import {IOwnableTwoSteps} from "@looksrare/contracts-libs/contracts/interfaces/IOwnableTwoSteps.sol";

// Base test
import {ProtocolBase} from "./ProtocolBase.t.sol";

contract LooksRareProtocolTest is ProtocolBase {
    function testAdjustETHGasLimitForTransfer() public asPrankedUser(_owner) {
        vm.expectEmit(true, false, false, true);
        emit NewGasLimitETHTransfer(10_000);
        looksRareProtocol.adjustETHGasLimitForTransfer(10_000);
        assertEq(uint256(vm.load(address(looksRareProtocol), bytes32(uint256(16)))), 10_000);
    }

    function testAdjustETHGasLimitForTransferRevertsIfTooLow() public asPrankedUser(_owner) {
        uint256 newGasLimitETHTransfer = 2_300;
        vm.expectRevert(NewGasLimitETHTransferTooLow.selector);
        looksRareProtocol.adjustETHGasLimitForTransfer(newGasLimitETHTransfer - 1);

        looksRareProtocol.adjustETHGasLimitForTransfer(newGasLimitETHTransfer);
        assertEq(uint256(vm.load(address(looksRareProtocol), bytes32(uint256(16)))), newGasLimitETHTransfer);
    }

    function testAdjustETHGasLimitForTransferNotOwner() public {
        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        looksRareProtocol.adjustETHGasLimitForTransfer(10_000);
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
