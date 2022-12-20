// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title IExecutionStrategy
 * @author LooksRare protocol team (👀,💎)
 */
interface IExecutionStrategy {
    // Custom errors
    error AskTooHigh();
    error BidTooLow();
    error OrderInvalid();
    error WrongCaller();
}
