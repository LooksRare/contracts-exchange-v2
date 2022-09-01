// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

// LooksRare unopinionated libraries
import {SignatureChecker} from "@looksrare/contracts-libs/contracts/SignatureChecker.sol";

// Order structs
import {OrderStructs} from "./libraries/OrderStructs.sol";

// LooksRareProtocol
import {LooksRareProtocol} from "./LooksRareProtocol.sol";

/**
 * @title LooksRareProtocolHelpers
 * @notice This contract contains helper view functions for order creation.
 * @author LooksRare protocol team (👀,💎)
 */
contract LooksRareProtocolHelpers is SignatureChecker {
    using OrderStructs for OrderStructs.MakerAsk;
    using OrderStructs for OrderStructs.MakerBid;
    using OrderStructs for bytes32;

    // Encoding prefix for EIP-712 signatures
    string internal constant _ENCODING_PREFIX = "\x19\x01";

    // LooksRareProtocol
    LooksRareProtocol public looksRareProtocol;

    /**
     * @notice Constructor
     * @param looksRareProtocolAddress address of the LooksRareProtocol
     */
    constructor(address looksRareProtocolAddress) {
        looksRareProtocol = LooksRareProtocol(looksRareProtocolAddress);
    }

    /**
     * @notice Verify maker ask order
     * @param makerAsk makerAsk
     * @param makerSignature signature of the maker
     * @param signer address of signer
     */
    function verifyMakerAskOrder(
        OrderStructs.MakerAsk memory makerAsk,
        bytes memory makerSignature,
        address signer
    ) public view returns (bool) {
        bytes32 digest = computeDigestMakerAsk(makerAsk);
        _verify(digest, signer, makerSignature);
        return true;
    }

    /**
     * @notice Verify maker bid order
     * @param makerBid makerBid
     * @param makerSignature signature of the maker
     * @param signer address of signer
     */
    function verifyMakerBidOrder(
        OrderStructs.MakerBid memory makerBid,
        bytes memory makerSignature,
        address signer
    ) public view returns (bool) {
        bytes32 digest = computeDigestMakerBid(makerBid);
        _verify(digest, signer, makerSignature);
        return true;
    }

    /**
     * @notice Compute digest for maker ask
     * @param makerAsk makerAsk
     */
    function computeDigestMakerAsk(OrderStructs.MakerAsk memory makerAsk) public view returns (bytes32 digest) {
        (, , bytes32 domainSeparator, ) = looksRareProtocol.information();
        return keccak256(abi.encodePacked(_ENCODING_PREFIX, domainSeparator, makerAsk.hash()));
    }

    /**
     * @notice Compute digest for maker bid
     * @param makerBid makerBid
     */
    function computeDigestMakerBid(OrderStructs.MakerBid memory makerBid) public view returns (bytes32 digest) {
        (, , bytes32 domainSeparator, ) = looksRareProtocol.information();
        return keccak256(abi.encodePacked(_ENCODING_PREFIX, domainSeparator, makerBid.hash()));
    }
}
