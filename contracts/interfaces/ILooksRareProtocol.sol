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
    event ProtocolPayment(address currency, uint256 protocolFee);
    event ProtocolPaymentWithAffiliate(address currency, uint256 protocolFee, address affiliate, uint256 affiliateFee);

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
