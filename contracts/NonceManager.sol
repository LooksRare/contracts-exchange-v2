// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Interfaces
import {INonceManager} from "./interfaces/INonceManager.sol";
import {WrongLengths} from "./interfaces/SharedErrors.sol";

/**
 * @title NonceManager
 * @notice This contract handles the nonce logic that is used for invalidating maker orders that exist offchain.
 *         The nonce logic revolves around three parts at the user level:
 *         - order nonce (orders sharing an order nonce are conditional, OCO-like)
 *         - subset (orders can be grouped under a same subset)
 *         - bid/ask (all orders can be executed only if the bid/ask nonce matches the user's one on-chain)
 *         Only the order nonce is invalidated at the time of the execution of a maker order that contains it.
 * @author LooksRare protocol team (👀,💎)
 */
contract NonceManager is INonceManager {
    bytes32 public immutable MAGIC_VALUE_NONCE_EXECUTED =
        0x000000000000000000000000000000000000000000000000000000000000002a;

    // Track bid and ask nonces for a user
    mapping(address => UserBidAskNonces) public userBidAskNonces;

    // Check whether the order nonce for a user was executed or cancelled
    mapping(address => mapping(uint256 => bytes32)) public userOrderNonce;

    // Check whether the subset nonce for a user was cancelled
    mapping(address => mapping(uint256 => bool)) public userSubsetNonce;

    /**
     * @notice Cancel order nonces
     * @param orderNonces Array of order nonces
     */
    function cancelOrderNonces(uint256[] calldata orderNonces) external {
        uint256 length = orderNonces.length;
        if (length == 0) revert WrongLengths();

        for (uint256 i; i < length; ) {
            userOrderNonce[msg.sender][orderNonces[i]] = MAGIC_VALUE_NONCE_EXECUTED;
            unchecked {
                ++i;
            }
        }

        emit OrderNoncesCancelled(orderNonces);
    }

    /**
     * @notice Cancel subset nonces
     * @param subsetNonces Array of subset nonces
     */
    function cancelSubsetNonces(uint256[] calldata subsetNonces) external {
        if (subsetNonces.length == 0) revert WrongLengths();

        for (uint256 i; i < subsetNonces.length; ) {
            userSubsetNonce[msg.sender][subsetNonces[i]] = true;
            unchecked {
                ++i;
            }
        }

        emit SubsetNoncesCancelled(subsetNonces);
    }

    /**
     * @notice Increment bid/ask nonces for a user
     * @param bid Whether to increment the user bid nonce
     * @param ask Whether to increment the user ask nonce
     */
    function incrementBidAskNonces(bool bid, bool ask) external {
        if (bid) {
            userBidAskNonces[msg.sender].bidNonce++;
        }
        if (ask) {
            userBidAskNonces[msg.sender].askNonce++;
        }

        emit NewBidAskNonces(userBidAskNonces[msg.sender].bidNonce, userBidAskNonces[msg.sender].askNonce);
    }
}
