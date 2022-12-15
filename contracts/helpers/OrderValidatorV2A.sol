// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// LooksRare unopinionated libraries
import {SignatureChecker} from "@looksrare/contracts-libs/contracts/SignatureChecker.sol";
import {IERC165} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC165.sol";
import {IERC20} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC20.sol";
import {IERC721} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC721.sol";
import {IERC1155} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC1155.sol";
import {IERC1271} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC1271.sol";

// Libraries
import {OrderStructs} from "../libraries/OrderStructs.sol";
import {MerkleProofCalldata} from "../libraries/OpenZeppelin/MerkleProofCalldata.sol";

// Interfaces
import {ICreatorFeeManager} from "../interfaces/ICreatorFeeManager.sol";
import {IExecutionManager} from "../interfaces/IExecutionManager.sol";
import {IStrategyManager} from "../interfaces/IStrategyManager.sol";

// Other dependencies
import {LooksRareProtocol} from "../LooksRareProtocol.sol";
import {TransferManager} from "../TransferManager.sol";

// Validation codes
import "./ValidationCodeConstants.sol";

/**
 * @title OrderValidatorV2A
 * @notice This contract is used to check the validity of maker ask/bid orders in the LooksRareProtocol (v2).
 *         It performs checks for:
 *         1. Nonce-related issues (e.g., nonce executed or cancelled)
 *         2. Signature-related issues and merkle tree parameters
 *         3. Internal whitelist-related issues (i.e., currency or strategy not whitelisted)
 *         4. Timestamp-related issues (e.g., order expired)
 *         5. Transfer-related issues for ERC20/ERC721/ERC1155 (approvals and balances)
 *         6. Maker order struct-related issues
 *         7. Creator-fee related issues (e.g., creator fee too high)
 * @author LooksRare protocol team (👀,💎)
 */
contract OrderValidatorV2A {
    using OrderStructs for OrderStructs.MakerAsk;
    using OrderStructs for OrderStructs.MakerBid;
    using OrderStructs for OrderStructs.MerkleTree;

    // Number of distinct criteria groups checked to evaluate the validity of an order
    uint256 public immutable CRITERIA_GROUPS = 7;

    // Magic value nonce returned if executed
    bytes32 public immutable MAGIC_VALUE_NONCE_EXECUTED =
        0x000000000000000000000000000000000000000000000000000000000000002a;

    // LooksRareProtocol domain separator
    bytes32 public domainSeparator;

    // CreatorFeeManager
    ICreatorFeeManager public creatorFeeManager;

    // LooksRareProtocol
    LooksRareProtocol public looksRareProtocol;

    // TransferManager
    TransferManager public transferManager;

    /**
     * @notice Constructor
     * @param _looksRareProtocol LooksRare protocol address
     * @dev It derives automatically other external variables such as the creator fee manager and domain separator.
     */
    constructor(address _looksRareProtocol) {
        looksRareProtocol = LooksRareProtocol(_looksRareProtocol);
        _adjustExternalParameters();
    }

    /**
     * @notice Adjust external parameters. Anyone can call this function.
     * @dev It allows adjusting if the domain separator or creator fee manager address were to change.
     */
    function adjustExternalParameters() external {
        _adjustExternalParameters();
    }

    /**
     * @notice Verify the validity of an array of maker ask orders.
     * @param makerAsks Array of maker ask structs
     * @param signatures Array of signatures
     * @param merkleTrees Array of merkle trees
     */
    function verifyMultipleMakerAskOrders(
        OrderStructs.MakerAsk[] calldata makerAsks,
        bytes[] calldata signatures,
        OrderStructs.MerkleTree[] calldata merkleTrees
    ) external view returns (uint256[][] memory validationCodes) {
        uint256 length = makerAsks.length;

        validationCodes = new uint256[][](length);

        for (uint256 i; i < length; ) {
            validationCodes[i] = checkMakerAskOrderValidity(makerAsks[i], signatures[i], merkleTrees[i]);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Verify the validity of an array of maker bid orders.
     * @param makerBids Array of maker bid structs
     * @param signatures Array of signatures
     * @param merkleTrees Array of merkle trees
     */
    function verifyMultipleMakerBidOrders(
        OrderStructs.MakerBid[] calldata makerBids,
        bytes[] calldata signatures,
        OrderStructs.MerkleTree[] calldata merkleTrees
    ) external view returns (uint256[][] memory validationCodes) {
        uint256 length = makerBids.length;

        validationCodes = new uint256[][](length);

        for (uint256 i; i < length; ) {
            validationCodes[i] = checkMakerBidOrderValidity(makerBids[i], signatures[i], merkleTrees[i]);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Verify the validity of a maker ask order.
     * @param makerAsk Maker ask struct
     * @param signature Signature
     * @param merkleTree Merkle tree
     */
    function checkMakerAskOrderValidity(
        OrderStructs.MakerAsk calldata makerAsk,
        bytes calldata signature,
        OrderStructs.MerkleTree calldata merkleTree
    ) public view returns (uint256[] memory validationCodes) {
        validationCodes = new uint256[](CRITERIA_GROUPS);
        bytes32 orderHash = makerAsk.hash();

        validationCodes[0] = _checkMakerAskValidityForNonces(
            makerAsk.signer,
            makerAsk.askNonce,
            makerAsk.orderNonce,
            makerAsk.subsetNonce,
            orderHash
        );
        validationCodes[1] = _checkValidityMerkleProofAndOrderHash(merkleTree, orderHash, signature, makerAsk.signer);
        validationCodes[2] = _checkMakerAskValidityWhitelists(makerAsk.currency, makerAsk.strategyId);
        validationCodes[3] = _checkValidityTimestamps(makerAsk.startTime, makerAsk.endTime);
        validationCodes[4] = _checkMakerAskValidityNFTAssets(
            makerAsk.collection,
            makerAsk.assetType,
            makerAsk.signer,
            makerAsk.itemIds,
            makerAsk.amounts
        );
    }

    /**
     * @notice Verify the validity of a maker bid order.
     * @param makerBid Maker bid struct
     * @param signature Signature
     * @param merkleTree Merkle tree
     */
    function checkMakerBidOrderValidity(
        OrderStructs.MakerBid calldata makerBid,
        bytes calldata signature,
        OrderStructs.MerkleTree calldata merkleTree
    ) public view returns (uint256[] memory validationCodes) {
        validationCodes = new uint256[](CRITERIA_GROUPS);
        bytes32 orderHash = makerBid.hash();
        validationCodes[0] = _checkMakerBidValidityForNonces(
            makerBid.signer,
            makerBid.bidNonce,
            makerBid.orderNonce,
            makerBid.subsetNonce,
            orderHash
        );
        validationCodes[1] = _checkValidityMerkleProofAndOrderHash(merkleTree, orderHash, signature, makerBid.signer);
        validationCodes[2] = _checkMakerBidValidityWhitelists(makerBid.currency, makerBid.strategyId);
        validationCodes[3] = _checkValidityTimestamps(makerBid.startTime, makerBid.endTime);
        // @dev It is possible the order is still valid in some cases since the price can be lower
        validationCodes[4] = _checkMakerBidValidityERC20Assets(makerBid.currency, makerBid.signer, makerBid.maxPrice);
    }

    /**
     * @notice Check the validity of nonces for maker ask user
     * @param makerSigner Address of the maker signer
     * @param askNonce Ask nonce
     * @param orderNonce Order nonce
     * @param subsetNonce Subset nonce
     * @param orderHash Order hash
     * @return validationCode Validation code
     */
    function _checkMakerAskValidityForNonces(
        address makerSigner,
        uint112 askNonce,
        uint256 orderNonce,
        uint256 subsetNonce,
        bytes32 orderHash
    ) internal view returns (uint256 validationCode) {
        validationCode = _checkSubsetAndOrderNonceValidity(makerSigner, orderNonce, subsetNonce, orderHash);

        if (validationCode == ORDER_EXPECTED_TO_BE_VALID) {
            (, uint112 globalAskNonce) = looksRareProtocol.userBidAskNonces(makerSigner);
            if (askNonce < globalAskNonce) return USER_GLOBAL_ASK_NONCE_HIGHER;
            if (askNonce > globalAskNonce) return USER_GLOBAL_ASK_NONCE_LOWER;
        }
    }

    /**
     * @notice Check the validity of nonces for maker bid user
     * @param makerSigner Address of the maker signer
     * @param bidNonce Bid nonce
     * @param orderNonce Order nonce
     * @param subsetNonce Subset nonce
     * @param orderHash Order hash
     * @return validationCode Validation code
     */
    function _checkMakerBidValidityForNonces(
        address makerSigner,
        uint112 bidNonce,
        uint256 orderNonce,
        uint256 subsetNonce,
        bytes32 orderHash
    ) internal view returns (uint256 validationCode) {
        validationCode = _checkSubsetAndOrderNonceValidity(makerSigner, orderNonce, subsetNonce, orderHash);

        if (validationCode == ORDER_EXPECTED_TO_BE_VALID) {
            (uint112 globalBidNonce, ) = looksRareProtocol.userBidAskNonces(makerSigner);
            if (bidNonce < globalBidNonce) return USER_GLOBAL_BID_NONCE_HIGHER;
            if (bidNonce > globalBidNonce) return USER_GLOBAL_BID_NONCE_LOWER;
        }
    }

    /**
     * @notice Check the validity of subset and order nonce
     * @param makerSigner Address of the maker signer
     * @param orderNonce Order nonce
     * @param subsetNonce Subset nonce
     * @param orderHash Order hash
     * @return validationCode Validation code
     */
    function _checkSubsetAndOrderNonceValidity(
        address makerSigner,
        uint256 orderNonce,
        uint256 subsetNonce,
        bytes32 orderHash
    ) internal view returns (uint256 validationCode) {
        // 1. Check subset nonce
        if (looksRareProtocol.userSubsetNonce(makerSigner, subsetNonce)) return USER_SUBSET_NONCE_CANCELLED;

        // 2. Check order nonce
        bytes32 orderNonceStatus = looksRareProtocol.userOrderNonce(makerSigner, orderNonce);
        if (orderNonceStatus == MAGIC_VALUE_NONCE_EXECUTED) return USER_ORDER_NONCE_EXECUTED_OR_CANCELLED;
        if (orderNonceStatus != orderHash) return USER_ORDER_NONCE_IN_EXECUTION_WITH_OTHER_HASH;
    }

    /**
     * @notice Check the validity for currency/strategy whitelists
     * @param currency Address of the currency
     * @param strategyId Strategy id
     * @return validationCode Validation code
     */
    function _checkMakerAskValidityWhitelists(
        address currency,
        uint256 strategyId
    ) public view returns (uint256 validationCode) {
        // Verify whether the currency is whitelisted
        if (!looksRareProtocol.isCurrencyWhitelisted(currency)) return CURRENCY_NOT_WHITELISTED;

        // Verify whether the strategy is valid
        (
            bool strategyIsActive,
            ,
            ,
            ,
            bytes4 strategySelector,
            bool strategyIsMakerBid,
            address strategyImplementation
        ) = looksRareProtocol.strategyInfo(strategyId);

        if (strategyId != 0 && strategyImplementation == address(0)) return STRATEGY_NOT_IMPLEMENTED;
        if (strategyId != 0 && (strategySelector == bytes4(0) || strategyIsMakerBid))
            return STRATEGY_TAKER_BID_SELECTOR_INVALID;
        if (!strategyIsActive) return STRATEGY_NOT_ACTIVE;
    }

    /**
     * @notice Check the validity for makerBid currency/strategy whitelists
     * @param currency Address of the currency
     * @param strategyId Strategy id
     * @return validationCode Validation code
     */
    function _checkMakerBidValidityWhitelists(
        address currency,
        uint256 strategyId
    ) public view returns (uint256 validationCode) {
        // Verify whether the currency is whitelisted
        if (currency == address(0) || !looksRareProtocol.isCurrencyWhitelisted(currency))
            return CURRENCY_NOT_WHITELISTED;

        // Verify whether the strategy is valid
        (
            bool strategyIsActive,
            ,
            ,
            ,
            bytes4 strategySelector,
            bool strategyIsMakerBid,
            address strategyImplementation
        ) = looksRareProtocol.strategyInfo(strategyId);

        if (strategyId != 0 && strategyImplementation == address(0)) return STRATEGY_NOT_IMPLEMENTED;
        if (strategyId != 0 && (strategySelector == bytes4(0) || !strategyIsMakerBid))
            return STRATEGY_TAKER_ASK_SELECTOR_INVALID;
        if (!strategyIsActive) return STRATEGY_NOT_ACTIVE;
    }

    /**
     * @notice Check the validity for order timestamps
     * @param startTime Start time
     * @param endTime End time
     * @return validationCode Validation code
     */
    function _checkValidityTimestamps(
        uint256 startTime,
        uint256 endTime
    ) internal view returns (uint256 validationCode) {
        if (endTime < block.timestamp) return TOO_LATE_TO_EXECUTE_ORDER;
        if (startTime + 5 minutes > block.timestamp) return TOO_EARLY_TO_EXECUTE_ORDER;
    }

    /**
     * @notice Check if potential wrong asset types
     * @param collection Address of the collection
     * @param assetType Asset type in the maker order
     * @return validationCode Validation code
     * @dev This function may return false positives (i.e., assets that are tradable but don't implement the proper interfaceId). Use with care.
     *      If ERC165 is not implemented, it will revert.
     */
    function _checkIfPotentialWrongAssetTypes(
        address collection,
        uint256 assetType
    ) internal view returns (uint256 validationCode) {
        if (assetType == 0) {
            // 0x5b5e139f // 0x80ac58cd are potential ERC721 interfaceIds
            bool isERC721 = IERC165(collection).supportsInterface(0x5b5e139f) ||
                IERC165(collection).supportsInterface(0x80ac58cd);
            if (!isERC721) return POTENTIAL_WRONG_ASSET_TYPE_SHOULD_BE_ERC721;
        } else if (assetType == 1) {
            // 0xd9b67a26 is ERC1155 interfaceId
            if (!IERC165(collection).supportsInterface(0xd9b67a26)) return POTENTIAL_WRONG_ASSET_TYPE_SHOULD_BE_ERC1155;
        }
    }

    /**
     * @notice Check the validity of ERC20 approvals and balances that are required to process the maker bid order
     * @param currency Currency address
     * @param user User address
     * @param price Price (defined by the maker order)
     * @return validationCode Validation code
     */
    function _checkMakerBidValidityERC20Assets(
        address currency,
        address user,
        uint256 price
    ) internal view returns (uint256 validationCode) {
        if (IERC20(currency).balanceOf(user) < price) return ERC20_BALANCE_INFERIOR_TO_PRICE;
        if (IERC20(currency).allowance(user, address(looksRareProtocol)) < price)
            return ERC20_APPROVAL_INFERIOR_TO_PRICE;
    }

    /**
     * @notice Check the validity of NFT assets (approvals, balances, and others)
     * @param collection Collection address
     * @param assetType Asset type
     * @param user User address
     * @param itemIds Array of item ids
     * @param amounts Array of amounts
     * @return validationCode Validation code
     */
    function _checkMakerAskValidityNFTAssets(
        address collection,
        uint256 assetType,
        address user,
        uint256[] memory itemIds,
        uint256[] memory amounts
    ) internal view returns (uint256 validationCode) {
        validationCode = _checkIfItemIdsDiffer(itemIds);
        if (validationCode != ORDER_EXPECTED_TO_BE_VALID) return validationCode;

        if (assetType == 0) {
            validationCode = _checkValidityERC721AndEquivalents(collection, user, itemIds);
        } else if (assetType == 1) {
            validationCode = _checkValidityERC1155(collection, user, itemIds, amounts);
        } else {
            // @dev If new asset types are supported, this contract needs to be deprecated
            return ASSET_TYPE_NOT_SUPPORTED;
        }

        if (validationCode != ORDER_EXPECTED_TO_BE_VALID) return validationCode;
        validationCode = _verifyTransferManagerApprovalAreNotRevokedByUserNorOwner(user);
        if (validationCode != ORDER_EXPECTED_TO_BE_VALID) return validationCode;
    }

    /**
     * @notice Check the validity of ERC721 approvals and balances required to process the maker ask order
     * @param collection Collection address
     * @param user User address
     * @param itemIds Array of item ids
     * @return validationCode Validation code
     */
    function _checkValidityERC721AndEquivalents(
        address collection,
        address user,
        uint256[] memory itemIds
    ) internal view returns (uint256 validationCode) {
        // 1. Verify itemId is owned by user and catch revertion if ERC721 ownerOf fails
        uint256 length = itemIds.length;

        bool success;
        bytes memory data;

        for (uint256 i; i < length; ) {
            (success, data) = collection.staticcall(abi.encodeWithSelector(IERC721.ownerOf.selector, itemIds[i]));

            if (!success) return ERC721_ITEM_ID_DOES_NOT_EXIST;
            if (abi.decode(data, (address)) != user) return ERC721_ITEM_ID_NOT_IN_BALANCE;

            unchecked {
                ++i;
            }
        }

        // 2. Verify if collection is approved by transfer manager
        (success, data) = collection.staticcall(
            abi.encodeWithSelector(IERC721.isApprovedForAll.selector, user, transferManager)
        );

        bool isApprovedAll;
        if (success) {
            isApprovedAll = abi.decode(data, (bool));
        }

        if (!isApprovedAll) {
            for (uint256 i; i < length; ) {
                // 3. If collection is not approved by transfer manager, try to see if it is approved individually
                (success, data) = collection.staticcall(
                    abi.encodeWithSelector(IERC721.getApproved.selector, itemIds[i])
                );

                address approvedAddress;
                if (success) {
                    approvedAddress = abi.decode(data, (address));
                }

                if (approvedAddress != address(transferManager)) return ERC721_NO_APPROVAL_FOR_ALL_OR_ITEM_ID;

                unchecked {
                    ++i;
                }
            }
        }
    }

    /**
     * @notice Check the validity of ERC1155 approvals and balances required to process the maker ask order
     * @param collection Collection address
     * @param user User address
     * @param itemIds Array of item ids
     * @param amounts Array of amounts
     * @return validationCode Validation code
     */
    function _checkValidityERC1155(
        address collection,
        address user,
        uint256[] memory itemIds,
        uint256[] memory amounts
    ) internal view returns (uint256 validationCode) {
        // 1. Verify each itemId is owned by user and catch revertion if ERC1155 ownerOf fails
        address[] memory users = new address[](1);
        users[0] = user;

        uint256 length = itemIds.length;

        // 1.1 Use balanceOfBatch
        (bool success, bytes memory data) = collection.staticcall(
            abi.encodeWithSelector(IERC1155.balanceOfBatch.selector, users, itemIds)
        );

        if (success) {
            uint256[] memory balances = abi.decode(data, (uint256[]));
            for (uint256 i; i < length; ) {
                if (balances[i] < amounts[i]) return ERC1155_BALANCE_OF_ITEM_ID_INFERIOR_TO_AMOUNT;
            }
        } else {
            // 1.2 If the balanceOfBatch doesn't work, use loop with balanceOf function
            for (uint256 i; i < length; ) {
                (success, data) = collection.staticcall(
                    abi.encodeWithSelector(IERC1155.balanceOf.selector, user, itemIds[i])
                );
                if (!success) return ERC1155_BALANCE_OF_DOES_NOT_EXIST;
                if (abi.decode(data, (uint256)) < amounts[i]) return ERC1155_BALANCE_OF_ITEM_ID_INFERIOR_TO_AMOUNT;
            }
        }

        // 2. Verify if collection is approved by transfer manager
        (success, data) = collection.staticcall(
            abi.encodeWithSelector(IERC1155.isApprovedForAll.selector, user, address(transferManager))
        );

        if (!success) return ERC1155_IS_APPROVED_FOR_ALL_DOES_NOT_EXIST;
        if (!abi.decode(data, (bool))) return ERC1155_NO_APPROVAL_FOR_ALL;
    }

    /**
     * @notice Check if any of the item id in an array of item ids is repeated
     * @param itemIds Array of item ids
     * @dev This is to be used for bundles
     * @return validationCode Validation code
     */
    function _checkIfItemIdsDiffer(uint256[] memory itemIds) internal pure returns (uint256 validationCode) {
        uint256 length = itemIds.length;

        // Only check if length of array is greater than 1
        if (length > 1) {
            for (uint256 i = 0; i < length; ) {
                for (uint256 j = i; j < length; ) {
                    if (itemIds[i] == itemIds[j]) {
                        return SAME_ITEM_ID_IN_BUNDLE;
                    }
                    unchecked {
                        ++j;
                    }
                }
                unchecked {
                    ++i;
                }
            }
        }
    }

    /**
     * @notice Verify validity merkle proof and order hash
     * @param merkleTree Merkle tree struct
     * @param orderHash Order hash
     * @param signature Signature
     * @param signer Signer address
     * @return validationCode Validation code
     */
    function _checkValidityMerkleProofAndOrderHash(
        OrderStructs.MerkleTree calldata merkleTree,
        bytes32 orderHash,
        bytes calldata signature,
        address signer
    ) internal view returns (uint256 validationCode) {
        if (merkleTree.proof.length != 0) {
            if (!MerkleProofCalldata.verifyCalldata(merkleTree.proof, merkleTree.root, orderHash))
                return ORDER_HASH_PROOF_NOT_IN_MERKLE_TREE;
            return _computeDigestAndVerify(merkleTree.hash(), signature, signer);
        } else {
            return _computeDigestAndVerify(orderHash, signature, signer);
        }
    }

    /**
     * @notice Compute digest and verify
     * @param computedHash Hash of order (maker bid or maker ask) or merkle root
     * @param makerSignature Signature of the maker
     * @param signer Signer address
     * @return validationCode Validation code
     */
    function _computeDigestAndVerify(
        bytes32 computedHash,
        bytes calldata makerSignature,
        address signer
    ) internal view returns (uint256 validationCode) {
        return
            _validateSignature(
                keccak256(abi.encodePacked("\x19\x01", domainSeparator, computedHash)),
                makerSignature,
                signer
            );
    }

    /**
     * @notice Validate signature
     * @param hash Message hash
     * @param signature A 64 or 65 bytes signature
     * @param signer Signer address
     * @return validationCode Validation code
     */
    function _validateSignature(
        bytes32 hash,
        bytes calldata signature,
        address signer
    ) internal view returns (uint256 validationCode) {
        // 1. Logic if EOA
        if (signer.code.length == 0) {
            bytes32 r;
            bytes32 s;
            uint8 v;

            if (signature.length == 64) {
                bytes32 vs;
                assembly {
                    r := calldataload(signature.offset)
                    vs := calldataload(add(signature.offset, 0x20))
                    s := and(vs, 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)
                    v := add(shr(255, vs), 27)
                }
            } else if (signature.length == 65) {
                assembly {
                    r := calldataload(signature.offset)
                    s := calldataload(add(signature.offset, 0x20))
                    v := byte(0, calldataload(add(signature.offset, 0x40)))
                }
            } else {
                return WRONG_SIGNATURE_LENGTH;
            }

            if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0)
                return INVALID_S_PARAMETER_EOA;

            if (v != 27 && v != 28) return INVALID_V_PARAMETER_EOA;

            address recoveredSigner = ecrecover(hash, v, r, s);
            if (signer == address(0)) return NULL_SIGNER_EOA;

            if (signer != recoveredSigner) return WRONG_SIGNER_EOA;
        } else {
            // 2. Logic if ERC1271
            (bool success, bytes memory data) = signer.staticcall(
                abi.encodeWithSelector(IERC1271.isValidSignature.selector, signer)
            );

            if (!success) return MISSING_IS_VALID_SIGNATURE_FUNCTION_EIP1271;
            if (abi.decode(data, (bytes4)) != 0x1626ba7e) return SIGNATURE_INVALID_EIP1271;
        }
    }

    /**
     * @notice Validate maker order itemIds and amounts for standard sale
     * @param itemIds Array of itemIds
     * @param amounts Array of amounts
     * @return validationCode Validation code
     */
    function _validateMakerOrderItemIdsAndAmountsForStandardSale(
        uint256[] memory itemIds,
        uint256[] memory amounts
    ) internal pure returns (uint256 validationCode) {
        uint256 length = itemIds.length;
        if (length == 0 || (amounts.length != length)) return MAKER_ORDER_INVALID_STANDARD_SALE;

        for (uint256 i; i < length; ) {
            if (amounts[i] == 0) return MAKER_ORDER_INVALID_STANDARD_SALE;
        }
    }

    /**
     * @notice Verify transfer manager approvals are not revoked by user, nor owner
     * @param user Address of the user
     * @return validationCode Validation code
     */
    function _verifyTransferManagerApprovalAreNotRevokedByUserNorOwner(
        address user
    ) internal view returns (uint256 validationCode) {
        if (!transferManager.hasUserApprovedOperator(user, address(looksRareProtocol)))
            return NO_TRANSFER_MANAGER_APPROVAL_BY_USER_FOR_EXCHANGE;

        if (!transferManager.isOperatorWhitelisted(address(looksRareProtocol)))
            return TRANSFER_MANAGER_APPROVAL_REVOKED_BY_OWNER_FOR_EXCHANGE;
    }

    /**
     * @notice Adjust external parameters. Anyone can call this function.
     * @dev It is meant to be adjustable if domain separator or creator fee manager were to change.
     */
    function _adjustExternalParameters() internal {
        domainSeparator = looksRareProtocol.domainSeparator();
        creatorFeeManager = looksRareProtocol.creatorFeeManager();

        (address transferManagerAddress, ) = looksRareProtocol.managerSelectorOfAssetType(0);
        transferManager = TransferManager(transferManagerAddress);
    }
}
