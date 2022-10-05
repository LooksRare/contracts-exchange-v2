// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

interface ILooksRareProtocol {
    // Custom errors
    error SameDomainSeparator();
    error WrongCaller();
    error WrongCurrency();
    error WrongMerkleProof();
    error WrongNonces();

    // Events
    event NewDomainSeparator();
    event ProtocolPayment(address currency, uint256 protocolFee);
    event ProtocolPaymentWithReferrer(address currency, uint256 protocolFee, address referrer, uint256 referralFee);

    event TakerBid(
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
        uint128 orderNonce,
        address bidUser,
        address bidRecipient,
        address askUser,
        address askRecipient,
        uint256 strategyId,
        address currency,
        address collection,
        uint256[] itemIds,
        uint256[] amounts,
        address[] feeRecipients,
        uint256[] feeAmounts
    );
}
