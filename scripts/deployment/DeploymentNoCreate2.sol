// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "../../lib/forge-std/src/Test.sol";

import {LooksRareProtocol} from "../../contracts/LooksRareProtocol.sol";
import {TransferManager} from "../../contracts/TransferManager.sol";

contract DeploymentNoCreate2 is Test {
    // WETH
    // Custom errors
    error NoRegistryAddressSet();
    error WrongChainId(uint256 chainId);

    // Contracts
    TransferManager public transferManager;
    LooksRareProtocol public looksRareProtocol;
    address public weth;

    function deploy() public {
        if (_royaltyFeeRegistry == address(0)) {
            revert NoRegistryAddressSet();
        }

        uint256 chainId = block.chainId;
        if (chainId == 1) {
            weth = 0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2;
        } else if (chainId == 5) {
            weth = 0xb4fbf271143f4fbf7b91a5ded31805e42b2208d6;
        } else {
            revert WrongChainId(chainId);
        }

        vm.startBroadcast();
        transferManager = new TransferManager();
        looksRareProtocol = new LooksRareProtocol(address(transferManager), weth);
        transferManager.whitelistOperator(address(looksRareProtocol));
        looksRareProtocol.addCurrency(address(0));
        looksRareProtocol.addCurrency(weth);
        looksRareProtocol.setProtocolFeeRecipient(looksRareProtocol.owner());

        console.log("TransferManager address: ");
        console.log(address(transferManager));
        console.log("LooksRareProtocol address: ");
        console.log(address(looksRareProtocol));
        vm.stopBroadcast();
    }
}
