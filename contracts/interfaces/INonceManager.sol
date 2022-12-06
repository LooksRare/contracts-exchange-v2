// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title INonceManager
 * @author LooksRare protocol team (👀,💎)
 */
interface INonceManager {
    // Custom errors
    error NoNonceToIncrement();
    error WrongLengths();

    // Events
    event NewBidAskNonces(uint112 bidNonce, uint112 askNonce);
    event OrderNoncesCancelled(uint256[] orderNonces);
    event SubsetNoncesCancelled(uint112[] subsetNonces);

    // Custom structs
    struct UserBidAskNonces {
        uint112 bidNonce;
        uint112 askNonce;
    }
}
