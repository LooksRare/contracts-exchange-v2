// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

interface ILooksRareProtocol {
    // Custom errors
    error NoTransferManagerForAssetType(uint16 assetType);
    error SameDomainSeparator();
    error TakerBidFail();
    error WrongAssetType(uint8 assetType);
    error WrongCaller();
    error WrongCurrency();
    error WrongMerkleProof();
    error WrongNonces();

    // Events
    event NewDomainSeparator();

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
