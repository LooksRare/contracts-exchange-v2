// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../../../contracts/interfaces/IStrategyManager.sol";
import "../../../contracts/CreatorFeeManagerWithRoyalties.sol";

contract LooksRareProtocolWithFaultyStrategies {
    CreatorFeeManagerWithRoyalties public creatorFeeManager;

    constructor() {
        creatorFeeManager = new CreatorFeeManagerWithRoyalties(address(0));
    }

    function transferManager() external pure returns (address) {
        return address(0);
    }

    function domainSeparator() external pure returns (address) {
        return address(0);
    }

    function maxCreatorFeeBp() external pure returns (uint256) {
        return 0;
    }

    function isCurrencyWhitelisted(address) external pure returns (bool isWhitelisted) {
        isWhitelisted = true;
    }

    function strategyInfo(uint256) external pure returns (IStrategyManager.Strategy memory strategy) {
        strategy = IStrategyManager.Strategy({
            isActive: true,
            standardProtocolFeeBp: 150,
            minTotalFeeBp: 200,
            maxProtocolFeeBp: 300,
            selector: bytes4(0),
            isMakerBid: false,
            implementation: address(0)
        });
    }
}
