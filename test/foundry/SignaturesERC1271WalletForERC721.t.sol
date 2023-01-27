// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Libraries and interfaces
import {IReentrancyGuard} from "@looksrare/contracts-libs/contracts/interfaces/IReentrancyGuard.sol";
import {ITransferSelectorNFT} from "../../contracts/interfaces/ITransferSelectorNFT.sol";
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";

// Base test
import {ProtocolBase} from "./ProtocolBase.t.sol";

// Mocks and other utils
import {ERC1271Wallet} from "./utils/ERC1271Wallet.sol";
import {MaliciousERC1271Wallet} from "./utils/MaliciousERC1271Wallet.sol";
import {MaliciousIsValidSignatureERC1271Wallet} from "./utils/MaliciousIsValidSignatureERC1271Wallet.sol";

// Errors
import {InvalidSignatureERC1271} from "@looksrare/contracts-libs/contracts/errors/SignatureCheckerErrors.sol";
import {SIGNATURE_INVALID_EIP1271} from "../../contracts/constants/ValidationCodeConstants.sol";

// Constants
import {ASSET_TYPE_ERC721} from "../../contracts/constants/NumericConstants.sol";

/**
 * @dev ERC1271Wallet recovers a signature's signer using ECDSA. If it matches the mock wallet's
 *      owner, it returns the magic value. Otherwise it returns an empty bytes4 value.
 */
contract SignaturesERC1271WalletForERC721Test is ProtocolBase {
    uint256 private constant price = 1 ether; // Fixed price of sale
    uint256 private constant itemId = 0;
    bytes private constant _EMPTY_SIGNATURE = new bytes(0);

    function setUp() public override {
        super.setUp();
        _setUpUser(takerUser);
        _setupRegistryRoyalties(address(mockERC721), _standardRoyaltyFee);
    }

    function testTakerBid() public {
        ERC1271Wallet wallet = new ERC1271Wallet(address(makerUser));
        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _takerBidSetup(
            address(wallet)
        );

        bytes memory signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.startPrank(address(wallet));
        mockERC721.setApprovalForAll(address(transferManager), true);
        transferManager.grantApprovals(operators);
        vm.stopPrank();

        _isMakerAskOrderValid(makerAsk, signature);

        vm.prank(takerUser);
        looksRareProtocol.executeTakerBid{value: price}(
            takerBid,
            makerAsk,
            signature,
            _EMPTY_MERKLE_TREE,
            _EMPTY_AFFILIATE
        );

        assertEq(mockERC721.ownerOf(itemId), takerUser);
    }

    function testTakerBidInvalidSignature() public {
        ERC1271Wallet wallet = new ERC1271Wallet(address(makerUser));
        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _takerBidSetup(
            address(wallet)
        );

        // Signed by a different private key
        bytes memory signature = _signMakerAsk(makerAsk, takerUserPK);

        vm.startPrank(address(wallet));
        mockERC721.setApprovalForAll(address(transferManager), true);
        transferManager.grantApprovals(operators);
        vm.stopPrank();

        _doesMakerAskOrderReturnValidationCode(makerAsk, signature, SIGNATURE_INVALID_EIP1271);

        vm.expectRevert(InvalidSignatureERC1271.selector);
        vm.prank(takerUser);
        looksRareProtocol.executeTakerBid{value: price}(
            takerBid,
            makerAsk,
            signature,
            _EMPTY_MERKLE_TREE,
            _EMPTY_AFFILIATE
        );
    }

    function testTakerBidReentrancy() public {
        MaliciousIsValidSignatureERC1271Wallet maliciousERC1271Wallet = new MaliciousIsValidSignatureERC1271Wallet(
            address(looksRareProtocol)
        );
        _setUpUser(address(maliciousERC1271Wallet));
        maliciousERC1271Wallet.setFunctionToReenter(MaliciousERC1271Wallet.FunctionToReenter.ExecuteTakerBid);

        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _takerBidSetup(
            address(maliciousERC1271Wallet)
        );

        vm.expectRevert(IReentrancyGuard.ReentrancyFail.selector);
        vm.prank(takerUser);
        looksRareProtocol.executeTakerBid{value: price}(
            takerBid,
            makerAsk,
            _EMPTY_SIGNATURE,
            _EMPTY_MERKLE_TREE,
            _EMPTY_AFFILIATE
        );
    }

    function testTakerAsk() public {
        ERC1271Wallet wallet = new ERC1271Wallet(address(makerUser));
        (OrderStructs.TakerAsk memory takerAsk, OrderStructs.MakerBid memory makerBid) = _takerAskSetup(
            address(wallet)
        );

        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        // Wallet needs to hold WETH and have given WETH approval
        deal(address(weth), address(wallet), price);
        vm.prank(address(wallet));
        weth.approve(address(looksRareProtocol), price);

        _isMakerBidOrderValid(makerBid, signature);

        vm.prank(takerUser);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);

        assertEq(mockERC721.ownerOf(itemId), address(wallet));
    }

    function testTakerAskInvalidSignature() public {
        ERC1271Wallet wallet = new ERC1271Wallet(address(makerUser));
        (OrderStructs.TakerAsk memory takerAsk, OrderStructs.MakerBid memory makerBid) = _takerAskSetup(
            address(wallet)
        );

        // Signed by a different private key
        bytes memory signature = _signMakerBid(makerBid, takerUserPK);

        // Wallet needs to hold WETH and have given WETH approval
        deal(address(weth), address(wallet), price);
        vm.prank(address(wallet));
        weth.approve(address(looksRareProtocol), price);

        _doesMakerBidOrderReturnValidationCode(makerBid, signature, SIGNATURE_INVALID_EIP1271);

        vm.expectRevert(InvalidSignatureERC1271.selector);
        vm.prank(takerUser);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function testTakerAskReentrancy() public {
        MaliciousIsValidSignatureERC1271Wallet maliciousERC1271Wallet = new MaliciousIsValidSignatureERC1271Wallet(
            address(looksRareProtocol)
        );
        _setUpUser(address(maliciousERC1271Wallet));
        maliciousERC1271Wallet.setFunctionToReenter(MaliciousERC1271Wallet.FunctionToReenter.ExecuteTakerAsk);

        (OrderStructs.TakerAsk memory takerAsk, OrderStructs.MakerBid memory makerBid) = _takerAskSetup(
            address(maliciousERC1271Wallet)
        );

        vm.expectRevert(IReentrancyGuard.ReentrancyFail.selector);
        vm.prank(takerUser);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, _EMPTY_SIGNATURE, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    uint256 private constant numberPurchases = 3;

    function testExecuteMultipleTakerBids() public {
        ERC1271Wallet wallet = new ERC1271Wallet(address(makerUser));

        (
            OrderStructs.MakerAsk[] memory makerAsks,
            OrderStructs.TakerBid[] memory takerBids,
            OrderStructs.MerkleTree[] memory merkleTrees,
            bytes[] memory signatures
        ) = _multipleTakerBidsSetup(address(wallet));

        vm.startPrank(address(wallet));
        mockERC721.setApprovalForAll(address(transferManager), true);
        transferManager.grantApprovals(operators);
        vm.stopPrank();

        vm.prank(takerUser);
        looksRareProtocol.executeMultipleTakerBids{value: price * numberPurchases}(
            takerBids,
            makerAsks,
            signatures,
            merkleTrees,
            _EMPTY_AFFILIATE,
            false
        );

        for (uint256 i; i < numberPurchases; i++) {
            assertEq(mockERC721.ownerOf(i), takerUser);
        }
    }

    function testExecuteMultipleTakerBidsInvalidSignatures() public {
        ERC1271Wallet wallet = new ERC1271Wallet(address(makerUser));

        (
            OrderStructs.MakerAsk[] memory makerAsks,
            OrderStructs.TakerBid[] memory takerBids,
            OrderStructs.MerkleTree[] memory merkleTrees,
            bytes[] memory signatures
        ) = _multipleTakerBidsSetup(address(wallet));

        // Signed by a different private key
        for (uint256 i; i < signatures.length; i++) {
            signatures[i] = _signMakerAsk(makerAsks[i], takerUserPK);
        }

        vm.startPrank(address(wallet));
        mockERC721.setApprovalForAll(address(transferManager), true);
        transferManager.grantApprovals(operators);
        vm.stopPrank();

        vm.expectRevert(InvalidSignatureERC1271.selector);
        vm.prank(takerUser);
        looksRareProtocol.executeMultipleTakerBids{value: price * numberPurchases}(
            takerBids,
            makerAsks,
            signatures,
            merkleTrees,
            _EMPTY_AFFILIATE,
            false
        );
    }

    function testExecuteMultipleTakerBidsReentrancy() public {
        MaliciousIsValidSignatureERC1271Wallet maliciousERC1271Wallet = new MaliciousIsValidSignatureERC1271Wallet(
            address(looksRareProtocol)
        );
        _setUpUser(address(maliciousERC1271Wallet));
        maliciousERC1271Wallet.setFunctionToReenter(MaliciousERC1271Wallet.FunctionToReenter.ExecuteMultipleTakerBids);

        (
            OrderStructs.MakerAsk[] memory makerAsks,
            OrderStructs.TakerBid[] memory takerBids,
            OrderStructs.MerkleTree[] memory merkleTrees,
            bytes[] memory signatures
        ) = _multipleTakerBidsSetup(address(maliciousERC1271Wallet));

        vm.expectRevert(IReentrancyGuard.ReentrancyFail.selector);
        vm.prank(takerUser);
        looksRareProtocol.executeMultipleTakerBids{value: price * numberPurchases}(
            takerBids,
            makerAsks,
            signatures,
            merkleTrees,
            _EMPTY_AFFILIATE,
            false
        );
    }

    function _takerBidSetup(
        address signer
    ) private returns (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) {
        // Mint asset
        mockERC721.mint(signer, itemId);

        // Prepare the order hash
        makerAsk = _createSingleItemMakerAskOrder({
            askNonce: 0,
            subsetNonce: 0,
            strategyId: STANDARD_SALE_FOR_FIXED_PRICE_STRATEGY,
            assetType: ASSET_TYPE_ERC721,
            orderNonce: 0,
            collection: address(mockERC721),
            currency: ETH,
            signer: signer,
            minPrice: price,
            itemId: itemId
        });

        // Prepare the taker bid
        takerBid = OrderStructs.TakerBid(takerUser, makerAsk.minPrice, abi.encode());
    }

    function _takerAskSetup(
        address signer
    ) private returns (OrderStructs.TakerAsk memory takerAsk, OrderStructs.MakerBid memory makerBid) {
        // Prepare the order hash
        makerBid = _createSingleItemMakerBidOrder({
            bidNonce: 0,
            subsetNonce: 0,
            strategyId: STANDARD_SALE_FOR_FIXED_PRICE_STRATEGY,
            assetType: ASSET_TYPE_ERC721,
            orderNonce: 0,
            collection: address(mockERC721),
            currency: address(weth),
            signer: signer,
            maxPrice: price,
            itemId: itemId
        });

        // Mint asset
        mockERC721.mint(takerUser, itemId);

        // Prepare the taker ask
        takerAsk = OrderStructs.TakerAsk(takerUser, abi.encode());
    }

    function _multipleTakerBidsSetup(
        address signer
    )
        private
        returns (
            OrderStructs.MakerAsk[] memory makerAsks,
            OrderStructs.TakerBid[] memory takerBids,
            OrderStructs.MerkleTree[] memory merkleTrees,
            bytes[] memory signatures
        )
    {
        makerAsks = new OrderStructs.MakerAsk[](numberPurchases);
        takerBids = new OrderStructs.TakerBid[](numberPurchases);
        signatures = new bytes[](numberPurchases);

        for (uint256 i; i < numberPurchases; i++) {
            // Mint asset
            mockERC721.mint(signer, i);

            // Prepare the order hash
            makerAsks[i] = _createSingleItemMakerAskOrder({
                askNonce: 0,
                subsetNonce: 0,
                strategyId: STANDARD_SALE_FOR_FIXED_PRICE_STRATEGY,
                assetType: ASSET_TYPE_ERC721,
                orderNonce: i,
                collection: address(mockERC721),
                currency: ETH,
                signer: signer,
                minPrice: price,
                itemId: i // 0, 1, etc.
            });

            signatures[i] = _signMakerAsk(makerAsks[i], makerUserPK);

            takerBids[i] = OrderStructs.TakerBid(takerUser, makerAsks[i].minPrice, abi.encode());
        }

        // Other execution parameters
        merkleTrees = new OrderStructs.MerkleTree[](numberPurchases);
    }
}
