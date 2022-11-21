// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {OwnableTwoSteps} from "@looksrare/contracts-libs/contracts/OwnableTwoSteps.sol";
import {IExecutionStrategy} from "../interfaces/IExecutionStrategy.sol";

/**
 * @title StrategyBase
 * @dev StrategyBase is needed for multiple abstract contracts to inherit from OwnableTwoSteps.
 * @author LooksRare protocol team (👀,💎)
 */
abstract contract StrategyBase is IExecutionStrategy, OwnableTwoSteps {

}
