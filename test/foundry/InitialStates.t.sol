// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Interfaces
import {IStrategyManager} from "../../contracts/interfaces/IStrategyManager.sol";

// Base test
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

        (
            bool strategyIsActive,
            uint16 strategyStandardProtocolFee,
            uint16 strategyMinTotalFee,
            uint16 strategyMaxProtocolFee,
            bytes4 strategySelector,
            bool strategyIsTakerBid,
            address strategyImplementation
        ) = looksRareProtocol.strategyInfo(0);

        assertTrue(strategyIsActive);
        assertEq(strategyStandardProtocolFee, _standardProtocolFee);
        assertEq(strategyMinTotalFee, _minTotalFee);
        assertEq(strategyMaxProtocolFee, _maxProtocolFee);
        assertEq(strategySelector, _emptyBytes4);
        assertFalse(strategyIsTakerBid);
        assertEq(strategyImplementation, address(0));
    }
}
