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
            (
                bool strategyIsActive,
                uint16 strategyStandardProtocolFee,
                uint16 strategyMinTotalFee,
                uint16 strategyMaxProtocolFee,
                bytes4 strategySelectorTakerAsk,
                bytes4 strategySelectorTakerBid,
                address strategyImplementation
            ) = looksRareProtocol.strategyInfo(i);

            assertTrue(strategyIsActive);
            assertEq(strategyStandardProtocolFee, _standardProtocolFee);
            assertEq(strategyMinTotalFee, _minTotalFee);
            assertEq(strategyMaxProtocolFee, _maxProtocolFee);
            assertEq(strategySelectorTakerAsk, _emptyBytes4);
            assertEq(strategySelectorTakerBid, _emptyBytes4);
            assertEq(strategyImplementation, address(0));
        }
    }
}
