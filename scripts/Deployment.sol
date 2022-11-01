// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "../lib/forge-std/src/Test.sol";

import {LooksRareProtocol} from "../contracts/LooksRareProtocol.sol";
import {TransferManager} from "../contracts/TransferManager.sol";
import {AffiliateStaking} from "../contracts/AffiliateStaking.sol";

contract Deployment is Test {
    // Custom error
    error NoRegistryAddressSet();

    // Contracts
    TransferManager public transferManager;
    LooksRareProtocol public looksRareProtocol;
    AffiliateStaking public affiliateStaking;

    // Config
    address internal _looksRareToken;
    uint256 internal _timelockPeriod = 7 days;

    function deploy() public {
        if (_royaltyFeeRegistry == address(0)) {
            revert NoRegistryAddressSet();
        }

        vm.startBroadcast();
        transferManager = new TransferManager();
        looksRareProtocol = new LooksRareProtocol(address(transferManager));
        transferManager.whitelistOperator(address(looksRareProtocol));
        looksRareProtocol.addCurrency(address(0));
        looksRareProtocol.setProtocolFeeRecipient(looksRareProtocol.owner());
        affiliateStaking = AffiliateStaking(address(looksRareProtocol), _looksRareToken, _timelockPeriod);

        console.log("Transfer Manager address");
        console.log(address(transferManager));
        console.log("LooksRareProtocol address");
        console.log(address(looksRareProtocol));
        console.log("AffiliateStaking address");
        console.log(address(looksRareProtocol));
        vm.stopBroadcast();
    }
}
