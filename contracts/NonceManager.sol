// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import {INonceManager} from "./interfaces/INonceManager.sol";

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
    // Track bid and ask nonces for a user
    mapping(address => UserBidAskNonces) internal _userBidAskNonces;

    // Track order nonce for a user
    mapping(address => mapping(uint112 => bool)) internal _userOrderNonce;

    // Track subset nonce for a user
    mapping(address => mapping(uint112 => bool)) internal _userSubsetNonce;

    /**
     * @notice Cancel order nonces
     * @param orderNonces array of order nonces
     */
    function cancelOrderNonces(uint112[] calldata orderNonces) external {
        if (orderNonces.length == 0) {
            revert WrongLengths();
        }

        for (uint256 i; i < orderNonces.length; ) {
            _userOrderNonce[msg.sender][orderNonces[i]] = true;
            unchecked {
                ++i;
            }
        }

        emit OrderNoncesCancelled(orderNonces);
    }

    /**
     * @notice Cancel subset nonces
     * @param subsetNonces array of subset nonces
     */
    function cancelSubsetNonces(uint112[] calldata subsetNonces) external {
        if (subsetNonces.length == 0) {
            revert WrongLengths();
        }

        for (uint256 i; i < subsetNonces.length; ) {
            _userSubsetNonce[msg.sender][subsetNonces[i]] = true;
            unchecked {
                ++i;
            }
        }

        emit SubsetNoncesCancelled(subsetNonces);
    }

    /**
     * @notice Increment bid/ask nonces for a user
     * @param bid whether to increment the user bid nonce
     * @param ask whether to increment the user bid nonce
     */
    function incrementBidAskNonces(bool bid, bool ask) external {
        unchecked {
            if (ask && bid) {
                _userBidAskNonces[msg.sender] = UserBidAskNonces({
                    bidNonce: _userBidAskNonces[msg.sender].bidNonce + 1,
                    askNonce: _userBidAskNonces[msg.sender].askNonce + 1
                });
            } else if (bid) {
                _userBidAskNonces[msg.sender].bidNonce++;
            } else if (ask) {
                _userBidAskNonces[msg.sender].askNonce++;
            } else {
                revert NoNonceToIncrement();
            }
        }

        emit NewBidAskNonces(_userBidAskNonces[msg.sender].bidNonce, _userBidAskNonces[msg.sender].askNonce);
    }

    /**
     * @notice Check the bid/ask nonce
     * @param user address of the user
     * @return bidAskNonces user bid ask nonces
     */
    function viewUserBidAskNonces(address user) external view returns (UserBidAskNonces memory bidAskNonces) {
        return _userBidAskNonces[user];
    }

    /**
     * @notice Check whether user order nonce is executed or cancelled
     * @param user address of the user
     * @param nonce order nonce
     * @return isNonceExecutedOrCancelled whether the nonce is cancelled or executed
     */
    function viewUserOrderNonce(address user, uint112 nonce) external view returns (bool isNonceExecutedOrCancelled) {
        return _userOrderNonce[user][nonce];
    }

    /**
     * @notice Check whether user subset nonce is executed or cancelled
     * @param user address of the user
     * @param nonce subset nonce
     * @return isNonceExecutedOrCancelled whether the nonce is cancelled or executed
     */
    function viewUserSubsetNonce(address user, uint112 nonce) external view returns (bool isNonceExecutedOrCancelled) {
        return _userSubsetNonce[user][nonce];
    }
}
