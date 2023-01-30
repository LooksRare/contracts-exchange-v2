// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {OrderValidatorV2A} from "../../contracts/helpers/OrderValidatorV2A.sol";

// Libraries
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";

// Shared errors
import {STRATEGY_NOT_IMPLEMENTED} from "../../contracts/constants/ValidationCodeConstants.sol";

// Utils
import {TestParameters} from "./utils/TestParameters.sol";
import {LooksRareProtocolWithFaultyStrategies} from "./utils/LooksRareProtocolWithFaultyStrategies.sol";

contract OrderValidatorV2ATest is TestParameters {
    function testStrategyNotImplemented() public {
        OrderValidatorV2A validator = new OrderValidatorV2A(address(new LooksRareProtocolWithFaultyStrategies()));
        OrderStructs.MakerAsk memory makerAsk;
        makerAsk.strategyId = 1;
        uint256[9] memory validationCodes = validator.checkMakerAskOrderValidity(
            makerAsk,
            new bytes(65),
            _EMPTY_MERKLE_TREE
        );
        assertEq(validationCodes[0], STRATEGY_NOT_IMPLEMENTED);
        for (uint256 i = 1; i < 9; i++) {
            assertEq(validationCodes[i], 0);
        }
    }
}
