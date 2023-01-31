// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../../../contracts/interfaces/IStrategyManager.sol";
import "../../../contracts/CreatorFeeManagerWithRoyalties.sol";
import "../../../contracts/TransferManager.sol";

// Mocks
import {MockRoyaltyFeeRegistry} from "../../mock/MockRoyaltyFeeRegistry.sol";

/**
 * @dev Tha main purpose of having a mock LooksRareProtocol is to be able to return
 *      an invalid strategy with implementation/selector being 0 for strategyId > 0.
 *      If we were to use the real one, we wouldn't be able to do so because addStrategy
 *      does not allow the value 0 for implementation/selector.
 *      The other mock functions need to be available for OrderValidatorV2A to run properly.
 */
contract MockLooksRareProtocol {
    CreatorFeeManagerWithRoyalties public immutable creatorFeeManager;
    TransferManager public immutable transferManager;

    constructor() {
        creatorFeeManager = new CreatorFeeManagerWithRoyalties(address(new MockRoyaltyFeeRegistry(msg.sender, 1_000)));
        transferManager = new TransferManager(msg.sender);
    }

    function userBidAskNonces(address) external pure returns (uint256, uint256) {
        return (0, 0);
    }

    function userOrderNonce(address, uint256) external pure returns (uint256) {
        return 0;
    }

    function userSubsetNonce(address, uint256) external pure returns (uint256) {
        return 0;
    }

    function domainSeparator() external pure returns (bytes32) {
        return bytes32("420");
    }

    function maxCreatorFeeBp() external pure returns (uint256) {
        return 69;
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
