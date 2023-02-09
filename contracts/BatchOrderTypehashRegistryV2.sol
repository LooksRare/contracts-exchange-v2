// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {FreeMemoryPointerSlot, OneWord, OneWordShift, ThirtyOneBytes} from "./constants/AssemblyConstants.sol";

import {MAX_CALLDATA_PROOF_LENGTH} from "./constants/NumericConstants.sol";

/**
 * @title BatchOrderTypehashRegistryV2
 * @author LooksRare protocol team (👀,💎)
 * @notice BatchOrderTypehashRegistryV2 is inspired by Seaport's TypehashDirectory
 *         to store batch order typehash for each merkle tree height. It stores the typehashes
 *         as bytecode that starts with the opcode 0xfe (INVALID) such that it is not
 *         executable. The typehashes are loaded using extcodecopy by LooksRareProtocol.
 */
contract BatchOrderTypehashRegistryV2 {
    // Encodes "[2]" for use in deriving typehashes.
    bytes3 internal constant twoSubstring = 0x5B325D;
    uint256 internal constant twoSubstringLength = 0x3;

    uint256 internal constant InvalidOpcode = 0xfe;

    constructor() {
        // Declare an array where each type hash will be written.
        bytes32[] memory typeHashes = new bytes32[](MAX_CALLDATA_PROOF_LENGTH);

        // Derive a string of 10 "[2]" substrings.
        bytes memory brackets = _getMaxTreeBrackets();

        // Derive a string of makerOrderString for the order parameters.
        bytes memory makerOrderString = _getMakerOrderString();

        // Cache memory pointer before each loop so memory doesn't expand by the
        // full string size on each loop.
        uint256 freeMemoryPointer;
        assembly {
            freeMemoryPointer := mload(FreeMemoryPointerSlot)
        }

        // Iterate over each tree height.
        for (uint256 i; i < MAX_CALLDATA_PROOF_LENGTH; ) {
            // The actual height is one greater than its respective index.
            uint256 height = i + 1;

            // Slice brackets length to size needed for `height`.
            assembly {
                mstore(brackets, mul(twoSubstringLength, height))
            }

            // Encode the type string for the BatchOrder struct.
            bytes memory batchOrderString = bytes.concat("BatchOrder(Maker", brackets, " tree)", makerOrderString);

            // Derive EIP712 type hash.
            bytes32 typeHash = keccak256(batchOrderString);
            typeHashes[i] = typeHash;

            // Reset the free memory pointer.
            assembly {
                mstore(FreeMemoryPointerSlot, freeMemoryPointer)
            }

            unchecked {
                ++i;
            }
        }

        assembly {
            // Overwrite length with zero to give the contract an INVALID prefix
            // and deploy the type hashes array as a contract.
            mstore(typeHashes, InvalidOpcode)

            return(add(typeHashes, ThirtyOneBytes), add(shl(OneWordShift, MAX_CALLDATA_PROOF_LENGTH), 1))
        }
    }

    /**
     * @dev Private pure function that returns a string of "[2]" substrings,
     *      with a number of substrings equal to the provided height.
     *
     * @return A bytes array representing the string.
     */
    function _getMaxTreeBrackets() private pure returns (bytes memory) {
        bytes memory suffixes = new bytes(twoSubstringLength * MAX_CALLDATA_PROOF_LENGTH);
        assembly {
            // Retrieve the pointer to the array head.
            let ptr := add(suffixes, OneWord)

            // Derive the terminal pointer.
            let endPtr := add(ptr, mul(MAX_CALLDATA_PROOF_LENGTH, twoSubstringLength))

            // Iterate over each pointer until terminal pointer is reached.
            for {

            } lt(ptr, endPtr) {
                ptr := add(ptr, twoSubstringLength)
            } {
                // Insert "[2]" substring directly at current pointer location.
                mstore(ptr, twoSubstring)
            }
        }

        // Return the fully populated array of substrings.
        return suffixes;
    }

    /**
     * @dev Private pure function that returns a string of makerOrderString used in
     *      generating batch order EIP-712 typehashes.
     *
     * @return A bytes array representing the string.
     */
    function _getMakerOrderString() private pure returns (bytes memory) {
        return
            bytes(
                "Maker("
                "uint8 quoteType,"
                "uint256 globalNonce,"
                "uint256 subsetNonce,"
                "uint256 orderNonce,"
                "uint256 strategyId,"
                "uint8 assetType,"
                "address collection,"
                "address currency,"
                "address signer,"
                "uint256 startTime,"
                "uint256 endTime,"
                "uint256 price,"
                "uint256[] itemIds,"
                "uint256[] amounts,"
                "bytes additionalParameters"
                ")"
            );
    }
}
