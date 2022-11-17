// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IExecutionManager} from "../../contracts/interfaces/IExecutionManager.sol";
import {IStrategyManager} from "../../contracts/interfaces/IStrategyManager.sol";
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";
import {ProtocolBase} from "./ProtocolBase.t.sol";

contract InitialStatesTest is ProtocolBase, IStrategyManager {
    /**
     * Verify initial post-deployment states are as expected
     */
    function testInitialStates() public {
        bytes32 domainSeparator = looksRareProtocol.domainSeparator();

        bytes32 expectedDomainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("LooksRareProtocol"),
                keccak256(bytes("2")),
                block.chainid,
                address(looksRareProtocol)
            )
        );

        assertEq(domainSeparator, expectedDomainSeparator);

        for (uint16 i = 0; i < 2; i++) {
            Strategy memory strategy = looksRareProtocol.strategyInfo(i);
            assertTrue(strategy.isActive);
            assertEq(strategy.standardProtocolFee, _standardProtocolFee);
            assertEq(strategy.maxProtocolFee, uint16(300));
            assertEq(strategy.implementation, address(0));
        }
    }
}
