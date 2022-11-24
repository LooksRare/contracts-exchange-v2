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

    event TakerBid(
        bytes32 orderHash,
        bool isNonceInvalidated,
        uint128 orderNonce,
        address bidUser,
        address bidRecipient,
        address askUser,
        uint256 strategyId,
        address currency,
        address collection,
        uint256[] itemIds,
        uint256[] amounts,
        address[] feeRecipients,
        uint256[] feeAmounts
    );

    event TakerAsk(
        bytes32 orderHash,
        bool isNonceInvalidated,
        uint128 orderNonce,
        address bidUser,
        address bidRecipient,
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
