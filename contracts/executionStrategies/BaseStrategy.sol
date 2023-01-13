// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Interfaces
import {IBaseStrategy} from "../interfaces/IBaseStrategy.sol";

// Assembly
import {OrderInvalid_error_selector, OrderInvalid_error_length, Error_selector_offset} from "./StrategyConstants.sol";

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
            if and(xor(amount, 1), iszero(mul(amount, assetType))) {
                mstore(0x00, OrderInvalid_error_selector)
                revert(Error_selector_offset, OrderInvalid_error_length)
            }
        }
    }
}
