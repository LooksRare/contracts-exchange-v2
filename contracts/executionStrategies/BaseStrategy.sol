// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Interfaces
import {IBaseStrategy} from "../interfaces/IBaseStrategy.sol";

// Assembly
import {OrderInvalid_error_selector, OrderInvalid_error_length, WrongCurrency_error_selector, WrongCurrency_error_length, Error_selector_offset} from "./StrategyConstants.sol";

/**
 * @title BaseStrategy
 * @author LooksRare protocol team (👀,💎)
 */
abstract contract BaseStrategy is IBaseStrategy {
    /**
     * @inheritdoc IBaseStrategy
     */
    function isLooksRareV2Strategy() external pure override returns (bool) {
        return true;
    }

    /**
     * @dev This is equivalent to
     *      if (amount == 0 || (amount != 1 && assetType == 0)) {
     *          revert OrderInvalid();
     *      }
     *
     *      ERC721
     *      1. assetType == 0, amount == 0 -> 1 && 1 == true
     *      2. assetType == 0, amount == 1 -> 0 && 1 == false
     *      3. assetType == 0, amount == 2 -> 1 && 1 == true
     *
     *      ERC1155
     *      1. assetType == 1, amount == 0 -> 1 && 1 == true
     *      2. assetType == 1, amount == 1 -> 0 && 0 == false
     *      3. assetType == 1, amount == 2 -> 1 && 0 == false
     */
    function _validateAmount(uint256 amount, uint256 assetType) internal pure {
        assembly {
            if or(iszero(amount), and(xor(amount, 1), iszero(assetType))) {
                mstore(0x00, OrderInvalid_error_selector)
                revert(Error_selector_offset, OrderInvalid_error_length)
            }
        }
    }

    /**
     * @dev This is equivalent to
     *      if (makerAsk.currency != address(0)) {
     *          if (makerAsk.currency != WETH) {
     *              revert WrongCurrency();
     *          }
     *      }
     *
     *      1. If orderCurrency == WETH, allowedCurrency == WETH -> WETH * 0 == 0
     *      2. If orderCurrency == ETH,  allowedCurrency == WETH -> 0 * 1 == 0
     *      3. If orderCurrency == USDC, allowedCurrency == WETH -> USDC * 1 != 0
     */
    function _allowNativeOrAllowedCurrency(address orderCurrency, address allowedCurrency) internal pure {
        assembly {
            if mul(orderCurrency, iszero(eq(orderCurrency, allowedCurrency))) {
                mstore(0x00, WrongCurrency_error_selector)
                revert(Error_selector_offset, WrongCurrency_error_length)
            }
        }
    }
}
