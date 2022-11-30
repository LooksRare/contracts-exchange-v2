// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title ILooksRareProtocol
 * @author LooksRare protocol team (👀,💎)
 */
interface ILooksRareProtocol {
    // Custom errors
    error SameDomainSeparator();
    error WrongCaller();
    error WrongCurrency();
    error WrongMerkleProof();
    error WrongNonces();

    // Events
    event NewDomainSeparator();
    event AffiliatePayment(address affiliate, uint256 affiliateFee);

    struct SignatureParameters {
        bytes32 orderHash;
        uint128 orderNonce;
        bool isNonceInvalidated;
        address signer;
    }

    event TakerBid(
        SignatureParameters signatureParameters,
        address bidUser,
        uint256 strategyId,
        address currency,
        address collection,
        uint256[] itemIds,
        uint256[] amounts,
        address[] feeRecipients,
        uint256[] feeAmounts
    );

    event TakerAsk(
        SignatureParameters signatureParameters,
        address askUser,
        uint256 strategyId,
        address currency,
        address collection,
        uint256[] itemIds,
        uint256[] amounts,
        address[] feeRecipients,
        uint256[] feeAmounts
    );
}
