// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Shared errors
import {MerkleProofTooLarge} from "../../interfaces/SharedErrors.sol";

// Constants
import {MAX_CALLDATA_PROOF_LENGTH} from "../../constants/NumericConstants.sol";

/**
 * @title MerkleProofCalldataWithProofLimit
 * @notice This library is adjusted from the work of OpenZeppelin.
 *         It is based on the 4.7.0 (utils/cryptography/MerkleProof.sol).
 * @dev This contract implements a maximum proof size to reduce the size of merkle trees.
 * @author OpenZeppelin (adjusted by LooksRare)
 */
library MerkleProofCalldataWithProofLimit {
    /**
     * @notice This returns true if a `leaf` can be proved to be a part of a Merkle tree defined by `root`.
     *         For this, a `proof` must be provided, containing sibling hashes on the branch from the leaf to the
     *         root of the tree. Each pair of leaves and each pair of pre-images are assumed to be sorted.
     */
    function verifyCalldata(bytes32[] calldata proof, bytes32 root, bytes32 leaf) internal pure returns (bool) {
        return processProofCalldata(proof, leaf) == root;
    }

    /**
     * @notice This returns the rebuilt hash obtained by traversing a Merkle tree up from `leaf` using `proof`.
     *         A `proof` is valid if and only if the rebuilt hash matches the root of the tree.
     *         When processing the proof, the pairs of leafs & pre-images are assumed to be sorted.
     * @dev This contract implements a maximum length for the proof.
     *      The maximum number of orders that can be signed is 2**MAX_CALLDATA_PROOF_LENGTH.
     *      Since MAX_CALLDATA_PROOF_LENGTH = 10, the maximum number of orders per tree is 2**10 = 1_024 orders.
     */
    function processProofCalldata(bytes32[] calldata proof, bytes32 leaf) internal pure returns (bytes32) {
        bytes32 computedHash = leaf;
        uint256 length = proof.length;

        if (length > MAX_CALLDATA_PROOF_LENGTH) {
            revert MerkleProofTooLarge(length);
        }

        for (uint256 i = 0; i < length; ) {
            computedHash = _hashPair(computedHash, proof[i]);
            unchecked {
                ++i;
            }
        }
        return computedHash;
    }

    function _hashPair(bytes32 a, bytes32 b) private pure returns (bytes32) {
        return a < b ? _efficientHash(a, b) : _efficientHash(b, a);
    }

    function _efficientHash(bytes32 a, bytes32 b) private pure returns (bytes32 value) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            value := keccak256(0x00, 0x40)
        }
    }
}
