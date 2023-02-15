// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Scripting tool
import {Script} from "../../lib/forge-std/src/Script.sol";

// WETH
import {WETH} from "solmate/src/tokens/WETH.sol";

// Core contracts
import {LooksRareProtocol} from "../../contracts/LooksRareProtocol.sol";
import {TransferManager} from "../../contracts/TransferManager.sol";
import {CreatorFeeManagerWithRebates} from "../../contracts/CreatorFeeManagerWithRebates.sol";

// Create2 factory interface
import {IImmutableCreate2Factory} from "../../contracts/interfaces/IImmutableCreate2Factory.sol";

// Other contracts
import {OrderValidatorV2A} from "../../contracts/helpers/OrderValidatorV2A.sol";

contract Deployment is Script {
    IImmutableCreate2Factory private constant IMMUTABLE_CREATE2_FACTORY =
        IImmutableCreate2Factory(0x0000000000FFe8B47B3e2130213B802212439497);

    error ChainIdInvalid(uint256 chainId);

    // WETH
    address public weth;

    // Royalty fee registry
    address public royaltyFeeRegistry;

    function _run() internal {
        uint256 chainId = block.chainId;

        if (chainId == 1) {
            weth = 0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2;
            royaltyFeeRegistry = 0x55010472a93921a117aAD9b055c141060c8d8022;
            uint256 deployerPrivateKey = vm.envUint("MAINNET_KEY");
        } else if (chainId == 5) {
            weth = 0xb4fbf271143f4fbf7b91a5ded31805e42b2208d6;
            royaltyFeeRegistry = 0x12405dB79325D06a973aD913D6e9BdA1343cD526;
            uint256 deployerPrivateKey = vm.envUint("GOERLI_KEY");
        } else {
            revert ChainIdInvalid(chainId);
        }

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy TransferManager
        address transferManagerAddress = IMMUTABLE_CREATE2_FACTORY.safeCreate2({
            salt: vm.envBytes32("TRANSFER_MANAGER_SALT"),
            initializationCode: abi.encodePacked(
                type(TransferManager).creationCode,
                abi.encode(vm.envAddress("OWNER_ADDRESS"))
            )
        });

        // 2. Deploy LooksRareProtocol
        address looksRareProtocolAddress = IMMUTABLE_CREATE2_FACTORY.safeCreate2({
            salt: vm.envBytes32("LOOKSRARE_PROTOCOL_SALT"),
            initializationCode: abi.encodePacked(
                type(LooksRareProtocol).creationCode,
                abi.encode(
                    vm.envAddress("OWNER_ADDRESS"),
                    vm.envAddress("PROTOCOL_FEE_RECIPIENT_ADDRESS"),
                    transferManagerAddress,
                    weth
                )
            )
        });

        // 3. Deploy CreatorFeeManagerWithRebates
        CreatorFeeManagerWithRebates creatorFeeManager = new CreatorFeeManagerWithRebates(royaltyFeeRegistry);

        // 4. Deploy OrderValidatorV2A
        OrderValidatorV2A orderValidatorV2A = new OrderValidatorV2A(looksRareProtocolAddress);

        // 5. Other operations
        transferManager.allowOperator(address(looksRareProtocol));
        looksRareProtocol.updateCurrencyStatus(address(0), true);
        looksRareProtocol.updateCurrencyStatus(weth, true);
        looksRareProtocol.updateCreatorFeeManager(address(creatorFeeManager));

        // @dev Transfer 1 wei
        address(looksRareProtocol).transfer(1);

        console.log("TransferManager address:");
        console.log(transferManagerAddress);
        console.log("LooksRareProtocol address:");
        console.log(looksRareProtocolAddress);
        console.log("CreatorFeeManagerWithRebates address:");
        console.log(address(creatorFeeManager));
        console.log("OrderValidatorV2A address:");
        console.log(address(orderValidatorV2A));
        vm.stopBroadcast();
    }
}
