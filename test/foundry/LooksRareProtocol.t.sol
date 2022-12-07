// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IOwnableTwoSteps} from "@looksrare/contracts-libs/contracts/interfaces/IOwnableTwoSteps.sol";
import {ProtocolBase} from "./ProtocolBase.t.sol";

contract LooksRareProtocolTest is ProtocolBase {
    function testAdjustETHGasLimitForTransfer() public asPrankedUser(_owner) {
        vm.expectEmit(true, false, false, true);
        emit NewGasLimitETHTransfer(10_000);
        looksRareProtocol.adjustETHGasLimitForTransfer(10_000);
        assertEq(looksRareProtocol.gasLimitETHTransfer(), 10_000);
    }

    function testAdjustETHGasLimitForTransferNotOwner() public {
        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        looksRareProtocol.adjustETHGasLimitForTransfer(10_000);
    }
}
