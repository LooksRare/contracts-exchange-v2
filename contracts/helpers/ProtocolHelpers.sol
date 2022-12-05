// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// LooksRare unopinionated libraries
import {SignatureChecker} from "@looksrare/contracts-libs/contracts/SignatureChecker.sol";

// Libraries
import {OrderStructs} from "../libraries/OrderStructs.sol";

// Other dependencies
import {LooksRareProtocol} from "../LooksRareProtocol.sol";

/**
 * @title ProtocolHelpers
 * @notice This contract contains helper view functions for order creation.
 * @author LooksRare protocol team (👀,💎)
 */
contract ProtocolHelpers {
    using OrderStructs for OrderStructs.MakerAsk;
    using OrderStructs for OrderStructs.MakerBid;
    using OrderStructs for OrderStructs.MerkleRoot;

    // Encoding prefix for EIP-712 signatures
    string internal constant _ENCODING_PREFIX = "\x19\x01";

    // LooksRareProtocol
    LooksRareProtocol public looksRareProtocol;

    /**
     * @notice Constructor
     * @param _looksRareProtocol LooksRare protocol address
     */
    constructor(address _looksRareProtocol) {
        looksRareProtocol = LooksRareProtocol(_looksRareProtocol);
    }

    /**
     * @notice Compute digest for maker ask
     * @param makerAsk Maker ask struct
     * @return digest Digest
     */
    function computeDigestMakerAsk(OrderStructs.MakerAsk memory makerAsk) public view returns (bytes32 digest) {
        bytes32 domainSeparator = looksRareProtocol.domainSeparator();
        return keccak256(abi.encodePacked(_ENCODING_PREFIX, domainSeparator, makerAsk.hash()));
    }

    /**
     * @notice Compute digest for maker bid
     * @param makerBid Maker bid struct
     * @return digest Digest
     */
    function computeDigestMakerBid(OrderStructs.MakerBid memory makerBid) public view returns (bytes32 digest) {
        bytes32 domainSeparator = looksRareProtocol.domainSeparator();
        return keccak256(abi.encodePacked(_ENCODING_PREFIX, domainSeparator, makerBid.hash()));
    }

    /**
     * @notice Compute digest for merkle root
     * @param merkleRoot Merkle root struct
     */
    function computeDigestMerkleRoot(OrderStructs.MerkleRoot memory merkleRoot) public view returns (bytes32 digest) {
        bytes32 domainSeparator = looksRareProtocol.domainSeparator();
        return keccak256(abi.encodePacked(_ENCODING_PREFIX, domainSeparator, merkleRoot.hash()));
    }

    /**
     * @notice Verify maker ask order
     * @param makerAsk Maker ask struct
     * @param makerSignature Maker signature
     * @param signer Signer address
     */
    function verifyMakerAskOrder(
        OrderStructs.MakerAsk memory makerAsk,
        bytes calldata makerSignature,
        address signer
    ) public view returns (bool) {
        bytes32 digest = computeDigestMakerAsk(makerAsk);
        SignatureChecker.verify(digest, signer, makerSignature);
        return true;
    }

    /**
     * @notice Verify maker bid order
     * @param makerBid Maker bid struct
     * @param makerSignature Maker signature
     * @param signer Signer address
     */
    function verifyMakerBidOrder(
        OrderStructs.MakerBid memory makerBid,
        bytes calldata makerSignature,
        address signer
    ) public view returns (bool) {
        bytes32 digest = computeDigestMakerBid(makerBid);
        SignatureChecker.verify(digest, signer, makerSignature);
        return true;
    }

    /**
     * @notice Verify merkle root
     * @param merkleRoot Merkle root struct
     * @param makerSignature Maker signature
     * @param signer Signer address
     */
    function verifyMerkleRoot(
        OrderStructs.MerkleRoot memory merkleRoot,
        bytes calldata makerSignature,
        address signer
    ) public view returns (bool) {
        bytes32 digest = computeDigestMerkleRoot(merkleRoot);
        SignatureChecker.verify(digest, signer, makerSignature);
        return true;
    }
}
