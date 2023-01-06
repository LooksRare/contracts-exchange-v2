// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IBaseStrategy} from "../interfaces/IBaseStrategy.sol";

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
}
