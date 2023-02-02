// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "../../lib/forge-std/src/Test.sol";

import {LooksRareProtocol} from "../../contracts/LooksRareProtocol.sol";
import {TransferManager} from "../../contracts/TransferManager.sol";
import {OrderValidatorV2A} from "../../contracts/helpers/OrderValidatorV2A.sol";

contract DeploymentNoCreate2 is Test {
    // Custom errors
    error NoRegistryAddressSet();
    error ChainIdInvalid(uint256 chainId);

    // Contracts
    TransferManager public transferManager;
    LooksRareProtocol public looksRareProtocol;
    OrderValidatorV2A public orderValidatorV2A;

    // WETH
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
            revert ChainIdInvalid(chainId);
        }

        vm.startBroadcast();
        transferManager = new TransferManager(msg.sender);
        looksRareProtocol = new LooksRareProtocol(msg.sender, msg.sender, address(transferManager), weth);
        transferManager.allowOperator(address(looksRareProtocol));
        looksRareProtocol.updateCurrencyStatus(address(0), true);
        looksRareProtocol.updateCurrencyStatus(weth, true);
        orderValidatorV2A = new OrderValidatorV2A(address(looksRareProtocol));

        console.log("TransferManager address: ");
        console.log(address(transferManager));
        console.log("LooksRareProtocol address: ");
        console.log(address(looksRareProtocol));
        console.log("OrderValidatorV2A address: ");
        console.log(address(orderValidatorV2A));
        vm.stopBroadcast();
    }
}
