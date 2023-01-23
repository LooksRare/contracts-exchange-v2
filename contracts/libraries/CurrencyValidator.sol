// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Assembly
import {WrongCurrency_error_selector, WrongCurrency_error_length, Error_selector_offset} from "../constants/StrategyConstants.sol";

/**
 * @title CurrencyValidator
 * @notice This library validates the order currency to be the
 *         chain's native currency or the specified ERC20 token.
 * @author LooksRare protocol team (👀,💎)
 */
library CurrencyValidator {
    /**
     * @dev This is equivalent to
     *      if (orderCurrency != address(0)) {
     *          if (orderCurrency != allowedCurrency) {
     *              revert WrongCurrency();
     *          }
     *      }
     *
     *      1. If orderCurrency == WETH, allowedCurrency == WETH -> WETH * 0 == 0
     *      2. If orderCurrency == ETH,  allowedCurrency == WETH -> 0 * 1 == 0
     *      3. If orderCurrency == USDC, allowedCurrency == WETH -> USDC * 1 != 0
     */
    function allowNativeOrAllowedCurrency(address orderCurrency, address allowedCurrency) internal pure {
        assembly {
            if mul(orderCurrency, iszero(eq(orderCurrency, allowedCurrency))) {
                mstore(0x00, WrongCurrency_error_selector)
                revert(Error_selector_offset, WrongCurrency_error_length)
            }
        }
    }
}
