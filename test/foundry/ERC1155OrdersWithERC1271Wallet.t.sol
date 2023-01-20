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
import {MaliciousOnERC1155ReceivedERC1271Wallet} from "./utils/MaliciousOnERC1155ReceivedERC1271Wallet.sol";
import {MaliciousOnERC1155ReceivedTheThirdTimeERC1271Wallet} from "./utils/MaliciousOnERC1155ReceivedTheThirdTimeERC1271Wallet.sol";
import {MaliciousIsValidSignatureERC1271Wallet} from "./utils/MaliciousIsValidSignatureERC1271Wallet.sol";

// Errors
import {InvalidSignatureERC1271} from "@looksrare/contracts-libs/contracts/errors/SignatureCheckerErrors.sol";
import {LowLevelERC1155Transfer} from "@looksrare/contracts-libs/contracts/lowLevelCallers/LowLevelERC1155Transfer.sol";

/**
 * @dev ERC1271Wallet recovers a signature's signer using ECDSA. If it matches the mock wallet's
 *      owner, it returns the magic value. Otherwise it returns an empty bytes4 value.
 */
contract ERC1155OrdersWithERC1271WalletTest is ProtocolBase {
    uint256 private constant price = 1 ether; // Fixed price of sale
    uint256 private constant itemId = 0;
    bytes private constant _EMPTY_SIGNATURE = new bytes(0);

    function setUp() public override {
        super.setUp();
        _setUpUser(takerUser);
        _setupRegistryRoyalties(address(mockERC1155), _standardRoyaltyFee);
    }

    function testTakerBid() public {
        ERC1271Wallet wallet = new ERC1271Wallet(address(makerUser));
        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _takerBidSetup(
            address(wallet)
        );

        bytes memory signature = _signMakerAsk(makerAsk, makerUserPK);

        vm.startPrank(address(wallet));
        mockERC1155.setApprovalForAll(address(transferManager), true);
        transferManager.grantApprovals(operators);
        vm.stopPrank();

        vm.prank(takerUser);
        looksRareProtocol.executeTakerBid{value: price}(
            takerBid,
            makerAsk,
            signature,
            _EMPTY_MERKLE_TREE,
            _EMPTY_AFFILIATE
        );

        assertEq(mockERC1155.balanceOf(takerUser, itemId), 1);
    }

    function testTakerBidInvalidSignature() public {
        ERC1271Wallet wallet = new ERC1271Wallet(address(makerUser));
        (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) = _takerBidSetup(
            address(wallet)
        );

        // Signed by a different private key
        bytes memory signature = _signMakerAsk(makerAsk, takerUserPK);

        vm.startPrank(address(wallet));
        mockERC1155.setApprovalForAll(address(transferManager), true);
        transferManager.grantApprovals(operators);
        vm.stopPrank();

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

    function testTakerBidIsInvalidSignatureReentrancy() public {
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

        vm.prank(takerUser);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);

        assertEq(mockERC1155.balanceOf(address(wallet), itemId), 1);
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

        vm.expectRevert(InvalidSignatureERC1271.selector);
        vm.prank(takerUser);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function testTakerAskIsValidSignatureReentrancy() public {
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

    function testTakerAskOnERC1155ReceivedReentrancy() public {
        MaliciousOnERC1155ReceivedERC1271Wallet maliciousERC1271Wallet = new MaliciousOnERC1155ReceivedERC1271Wallet(
            address(looksRareProtocol)
        );
        _setUpUser(address(maliciousERC1271Wallet));

        (OrderStructs.TakerAsk memory takerAsk, OrderStructs.MakerBid memory makerBid) = _takerAskSetup(
            address(maliciousERC1271Wallet)
        );

        maliciousERC1271Wallet.setFunctionToReenter(MaliciousERC1271Wallet.FunctionToReenter.ExecuteTakerAsk);

        vm.expectRevert(LowLevelERC1155Transfer.ERC1155SafeTransferFromFail.selector);
        vm.prank(takerUser);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, _EMPTY_SIGNATURE, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function testBatchTakerAsk() public {
        ERC1271Wallet wallet = new ERC1271Wallet(makerUser);
        (OrderStructs.TakerAsk memory takerAsk, OrderStructs.MakerBid memory makerBid) = _batchTakerAskSetup(
            address(wallet)
        );

        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        // Wallet needs to hold WETH and have given WETH approval
        deal(address(weth), address(wallet), price);
        vm.prank(address(wallet));
        weth.approve(address(looksRareProtocol), price);

        vm.prank(takerUser);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);

        for (uint256 i; i < 10; i++) {
            assertEq(mockERC1155.balanceOf(address(wallet), i), 1);
        }
    }

    function testBatchTakerAskOnERC1155BatchReceivedReentrancy() public {
        MaliciousOnERC1155ReceivedERC1271Wallet maliciousERC1271Wallet = new MaliciousOnERC1155ReceivedERC1271Wallet(
            address(looksRareProtocol)
        );
        _setUpUser(address(maliciousERC1271Wallet));

        (OrderStructs.TakerAsk memory takerAsk, OrderStructs.MakerBid memory makerBid) = _batchTakerAskSetup(
            address(maliciousERC1271Wallet)
        );

        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        // Wallet needs to hold WETH and have given WETH approval
        deal(address(weth), address(maliciousERC1271Wallet), price);
        vm.prank(address(maliciousERC1271Wallet));
        weth.approve(address(looksRareProtocol), price);

        maliciousERC1271Wallet.setFunctionToReenter(MaliciousERC1271Wallet.FunctionToReenter.ExecuteTakerAsk);

        vm.expectRevert(LowLevelERC1155Transfer.ERC1155SafeBatchTransferFrom.selector);
        vm.prank(takerUser);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    uint256 private constant numberOfPurchases = 3;

    function testExecuteMultipleTakerBids() public {
        ERC1271Wallet wallet = new ERC1271Wallet(address(makerUser));

        (
            OrderStructs.MakerAsk[] memory makerAsks,
            OrderStructs.TakerBid[] memory takerBids,
            OrderStructs.MerkleTree[] memory merkleTrees,
            bytes[] memory signatures
        ) = _multipleTakerBidsSetup(address(wallet));

        vm.startPrank(address(wallet));
        mockERC1155.setApprovalForAll(address(transferManager), true);
        transferManager.grantApprovals(operators);
        vm.stopPrank();

        vm.prank(takerUser);
        looksRareProtocol.executeMultipleTakerBids{value: price * numberOfPurchases}(
            takerBids,
            makerAsks,
            signatures,
            merkleTrees,
            _EMPTY_AFFILIATE,
            false
        );

        for (uint256 i; i < numberOfPurchases; i++) {
            assertEq(mockERC1155.balanceOf(takerUser, i), 1);
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
        mockERC1155.setApprovalForAll(address(transferManager), true);
        transferManager.grantApprovals(operators);
        vm.stopPrank();

        vm.expectRevert(InvalidSignatureERC1271.selector);
        vm.prank(takerUser);
        looksRareProtocol.executeMultipleTakerBids{value: price * numberOfPurchases}(
            takerBids,
            makerAsks,
            signatures,
            merkleTrees,
            _EMPTY_AFFILIATE,
            false
        );
    }

    function testExecuteMultipleTakerBidsIsValidSignatureReentrancy() public {
        MaliciousIsValidSignatureERC1271Wallet maliciousERC1271Wallet = new MaliciousIsValidSignatureERC1271Wallet(
            address(makerUser)
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
        looksRareProtocol.executeMultipleTakerBids{value: price * numberOfPurchases}(
            takerBids,
            makerAsks,
            signatures,
            merkleTrees,
            _EMPTY_AFFILIATE,
            false
        );
    }

    function testExecuteMultipleTakerBidsOnERC1155ReceivedReentrancyOnlyInTheLastCall() public {
        MaliciousOnERC1155ReceivedTheThirdTimeERC1271Wallet maliciousERC1271Wallet = new MaliciousOnERC1155ReceivedTheThirdTimeERC1271Wallet(
                takerUser
            );
        _setUpUser(makerUser);
        maliciousERC1271Wallet.setFunctionToReenter(MaliciousERC1271Wallet.FunctionToReenter.ExecuteMultipleTakerBids);

        (
            OrderStructs.MakerAsk[] memory makerAsks,
            OrderStructs.TakerBid[] memory takerBids,
            OrderStructs.MerkleTree[] memory merkleTrees,
            bytes[] memory signatures
        ) = _multipleTakerBidsSetup(makerUser);

        // Set the NFT recipient as the ERC1271 wallet to trigger onERC1155Received
        for (uint256 i; i < numberOfPurchases; i++) {
            takerBids[i].recipient = address(maliciousERC1271Wallet);
        }

        vm.prank(takerUser);
        looksRareProtocol.executeMultipleTakerBids{value: price * numberOfPurchases}(
            takerBids,
            makerAsks,
            signatures,
            merkleTrees,
            _EMPTY_AFFILIATE,
            false
        );

        // First 2 purchases should go through, but the last one fails silently
        for (uint256 i; i < numberOfPurchases - 1; i++) {
            assertEq(mockERC1155.balanceOf(address(maliciousERC1271Wallet), i), 1);
        }
        assertEq(mockERC1155.balanceOf(address(maliciousERC1271Wallet), numberOfPurchases - 1), 0);
    }

    function _takerBidSetup(
        address signer
    ) private returns (OrderStructs.MakerAsk memory makerAsk, OrderStructs.TakerBid memory takerBid) {
        // Mint asset
        mockERC1155.mint(signer, itemId, 1);

        // Prepare the order hash
        makerAsk = _createSingleItemMakerAskOrder({
            askNonce: 0,
            subsetNonce: 0,
            strategyId: STANDARD_SALE_FOR_FIXED_PRICE_STRATEGY,
            assetType: ASSET_TYPE_ERC1155,
            orderNonce: 0,
            collection: address(mockERC1155),
            currency: ETH,
            signer: signer,
            minPrice: price,
            itemId: itemId
        });

        // Prepare the taker bid
        takerBid = OrderStructs.TakerBid(
            takerUser,
            makerAsk.minPrice,
            makerAsk.itemIds,
            makerAsk.amounts,
            abi.encode()
        );
    }

    function _takerAskSetup(
        address signer
    ) private returns (OrderStructs.TakerAsk memory takerAsk, OrderStructs.MakerBid memory makerBid) {
        // Prepare the order hash
        makerBid = _createSingleItemMakerBidOrder({
            bidNonce: 0,
            subsetNonce: 0,
            strategyId: STANDARD_SALE_FOR_FIXED_PRICE_STRATEGY,
            assetType: ASSET_TYPE_ERC1155,
            orderNonce: 0,
            collection: address(mockERC1155),
            currency: address(weth),
            signer: signer,
            maxPrice: price,
            itemId: itemId
        });

        // Mint asset
        mockERC1155.mint(takerUser, itemId, 1);

        // Prepare the taker ask
        takerAsk = OrderStructs.TakerAsk(
            takerUser,
            makerBid.maxPrice,
            makerBid.itemIds,
            makerBid.amounts,
            abi.encode()
        );
    }

    function _batchTakerAskSetup(
        address signer
    ) private returns (OrderStructs.TakerAsk memory takerAsk, OrderStructs.MakerBid memory makerBid) {
        uint256[] memory itemIds = new uint256[](10);
        uint256[] memory amounts = new uint256[](10);

        for (uint256 i; i < 10; i++) {
            itemIds[i] = i;
            amounts[i] = 1;

            // Mint asset
            mockERC1155.mint(takerUser, i, 1);
        }

        // Prepare the first order
        makerBid = _createMultiItemMakerBidOrder({
            bidNonce: 0,
            subsetNonce: 0,
            strategyId: STANDARD_SALE_FOR_FIXED_PRICE_STRATEGY,
            assetType: ASSET_TYPE_ERC1155,
            orderNonce: 0,
            collection: address(mockERC1155),
            currency: address(weth),
            signer: signer,
            maxPrice: price,
            itemIds: itemIds,
            amounts: amounts
        });

        // Prepare the taker ask
        takerAsk = OrderStructs.TakerAsk(
            takerUser,
            makerBid.maxPrice,
            makerBid.itemIds,
            makerBid.amounts,
            abi.encode()
        );
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
        makerAsks = new OrderStructs.MakerAsk[](numberOfPurchases);
        takerBids = new OrderStructs.TakerBid[](numberOfPurchases);
        signatures = new bytes[](numberOfPurchases);

        for (uint256 i; i < numberOfPurchases; i++) {
            // Mint asset
            mockERC1155.mint(signer, i, 1);

            // Prepare the order hash
            makerAsks[i] = _createSingleItemMakerAskOrder({
                askNonce: 0,
                subsetNonce: 0,
                strategyId: STANDARD_SALE_FOR_FIXED_PRICE_STRATEGY,
                assetType: ASSET_TYPE_ERC1155,
                orderNonce: i,
                collection: address(mockERC1155),
                currency: ETH,
                signer: signer,
                minPrice: price,
                itemId: i // 0, 1, etc.
            });

            signatures[i] = _signMakerAsk(makerAsks[i], makerUserPK);

            takerBids[i] = OrderStructs.TakerBid(
                takerUser,
                makerAsks[i].minPrice,
                makerAsks[i].itemIds,
                makerAsks[i].amounts,
                abi.encode()
            );
        }

        // Other execution parameters
        merkleTrees = new OrderStructs.MerkleTree[](numberOfPurchases);
    }
}
