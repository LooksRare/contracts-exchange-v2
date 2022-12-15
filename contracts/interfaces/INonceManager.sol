// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title INonceManager
 * @author LooksRare protocol team (👀,💎)
 */
interface INonceManager {
    // Events
    event NewBidAskNonces(uint128 bidNonce, uint128 askNonce);
    event OrderNoncesCancelled(uint256[] orderNonces);
    event SubsetNoncesCancelled(uint256[] subsetNonces);

    // Custom structs
    struct UserBidAskNonces {
        uint128 bidNonce;
        uint128 askNonce;
    }
}
