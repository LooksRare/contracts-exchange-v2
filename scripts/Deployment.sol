// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import {Test} from "../lib/forge-std/src/Test.sol";

import {LooksRareProtocol} from "../contracts/LooksRareProtocol.sol";
import {TransferManager} from "../contracts/TransferManager.sol";
import {ReferralStaking} from "../contracts/ReferralStaking.sol";

contract Deployment is Test {
    // Custom error
    error NoRegistryAddressSet();

    // Contracts
    TransferManager public transferManager;
    LooksRareProtocol public looksRareProtocol;
    ReferralStaking public referralStaking;

    // Config
    address internal _royaltyFeeRegistry;
    address internal _looksRareToken;
    uint256 internal _timelockPeriod = 7 days;

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
        referralStaking = ReferralStaking(address(looksRareProtocol), _looksRareToken, _timelockPeriod);

        console.log("Transfer Manager address");
        console.log(address(transferManager));
        console.log("LooksRareProtocol address");
        console.log(address(looksRareProtocol));
        console.log("ReferralStaking address");
        console.log(address(looksRareProtocol));
        vm.stopBroadcast();
    }
}
