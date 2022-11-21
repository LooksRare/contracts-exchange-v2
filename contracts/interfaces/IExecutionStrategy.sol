// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {OrderStructs} from "../libraries/OrderStructs.sol";

/**
 * @title IExecutionStrategy
 * @author LooksRare protocol team (👀,💎)
 */
interface IExecutionStrategy {
    // Custom errors
    error BidTooLow();
    error OrderInvalid();
    error WrongCaller();
}
