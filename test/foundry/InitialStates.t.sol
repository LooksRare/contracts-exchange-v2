// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IExecutionManager} from "../../contracts/interfaces/IExecutionManager.sol";
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";
import {ProtocolBase} from "./ProtocolBase.t.sol";

contract InitialStatesTest is ProtocolBase, IExecutionManager {
    /**
     * Verify initial post-deployment states are as expected
     */
    function testInitialStates() public {
        (
            bytes32 initialDomainSeparator,
            uint256 initialChainId,
            bytes32 currentDomainSeparator,
            uint256 currentChainId
        ) = looksRareProtocol.information();

        bytes32 expectedDomainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("LooksRareProtocol"),
                keccak256(bytes("2")),
                block.chainid,
                address(looksRareProtocol)
            )
        );

        assertEq(initialDomainSeparator, expectedDomainSeparator);
        assertEq(initialChainId, block.chainid);
        assertEq(initialDomainSeparator, currentDomainSeparator);
        assertEq(initialChainId, currentChainId);

        for (uint16 i = 0; i < 2; i++) {
            Strategy memory strategy = looksRareProtocol.viewStrategy(i);
            assertTrue(strategy.isActive);
            assertTrue(strategy.hasRoyalties);
            assertEq(strategy.protocolFee, _standardProtocolFee);
            assertEq(strategy.maxProtocolFee, uint16(300));
            assertEq(strategy.implementation, address(0));
        }
    }
}
