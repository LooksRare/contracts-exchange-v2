// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import {Test} from "../lib/forge-std/src/Test.sol";

import {LooksRareProtocol} from "../contracts/LooksRareProtocol.sol";
import {TransferManager} from "../contracts/TransferManager.sol";

contract Deployment is Test {
    // Custom error
    error NoRegistryAddressSet();

    // Config
    address internal _royaltyFeeRegistry;

    function deploy() public {
        if (_royaltyFeeRegistry == address(0)) {
            revert NoRegistryAddressSet();
        }

        vm.startBroadcast();
        transferManager = new TransferManager();
        looksRareProtocol = new LooksRareProtocol(address(transferManager), _royaltyFeeRegistry);
        transferManager.whitelistOperator(address(looksRareProtocol));
        looksRareProtocol.addCurrency(address(0));
        looksRareProtocol.setProtocolFeeRecipient(looksRareProtocol.owner());
        console.log(address(transferManager));
        console.log(address(looksRareProtocol));
        vm.stopBroadcast();
    }
}
