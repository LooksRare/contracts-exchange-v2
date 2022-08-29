// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {RoyaltyFeeRegistry} from "@looksrare/contracts-exchange-v1/contracts/royaltyFeeHelpers/RoyaltyFeeRegistry.sol";
import {WETH} from "@rari-capital/solmate/src/tokens/WETH.sol";
import {Merkle} from "../../lib/murky/src/Merkle.sol";

import {LooksRareProtocol} from "../../contracts/LooksRareProtocol.sol";
import {TransferManager} from "../../contracts/TransferManager.sol";
import {IExecutionManager} from "../../contracts/interfaces/IExecutionManager.sol";

import {OrderStructs, ProtocolHelpers} from "./utils/ProtocolHelpers.sol";
import {MockERC721} from "./utils/MockERC721.sol";
import {MockERC1155} from "./utils/MockERC1155.sol";

contract LooksRareProtocolTest is ProtocolHelpers {
    address[] public operators;
    MockERC721 public mockERC721;
    MockERC1155 public mockERC1155;

    RoyaltyFeeRegistry public royaltyFeeRegistry;
    LooksRareProtocol public looksRareProtocol;
    TransferManager public transferManager;
    WETH public weth;

    function _setUpUser(address user) internal asPrankedUser(user) {
        vm.deal(user, 100 ether);
        mockERC721.setApprovalForAll(address(transferManager), true);
        mockERC1155.setApprovalForAll(address(transferManager), true);
        transferManager.grantApprovals(operators);
        weth.approve(address(looksRareProtocol), type(uint256).max);
        weth.deposit{value: 10 ether}();
    }

    function _setUpRoyalties(address collection, uint16 royaltyFee) internal {
        vm.startPrank(royaltyFeeRegistry.owner());
        royaltyFeeRegistry.updateRoyaltyInfoForCollection(collection, _collectionOwner, _collectionOwner, royaltyFee);
        vm.stopPrank();
    }

    function _setUpUsers() internal {
        _setUpUser(makerUser);
        _setUpUser(takerUser);
    }

    function setUp() public asPrankedUser(_owner) {
        royaltyFeeRegistry = new RoyaltyFeeRegistry(9500);
        transferManager = new TransferManager();
        looksRareProtocol = new LooksRareProtocol(address(transferManager), address(royaltyFeeRegistry));
        mockERC721 = new MockERC721();
        mockERC1155 = new MockERC1155();

        weth = new WETH();

        vm.deal(_owner, 100 ether);
        vm.deal(_collectionOwner, 100 ether);

        // Operations
        transferManager.whitelistOperator(address(looksRareProtocol));
        looksRareProtocol.addCurrency(address(0));
        looksRareProtocol.addCurrency(address(weth));
        looksRareProtocol.setProtocolFeeRecipient(_owner);

        // Fetch domain separator
        (_domainSeparator, , , ) = looksRareProtocol.information();
        operators.push(address(looksRareProtocol));
    }

    /**
     * Verify initial post-deployment states are as expected
     */
    function testInitialStates() public {
        (
            bytes32 initialDomainSeparator,
            uint256 initialChainId,
            bytes32 currentDomainSeparator,
            uint256 currentChainId
        ) = looksRareProtocol.information();

        bytes32 expectedDomainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("LooksRareProtocol"),
                keccak256(bytes("2")),
                block.chainid,
                address(looksRareProtocol)
            )
        );

        assertEq(initialDomainSeparator, expectedDomainSeparator);
        assertEq(initialChainId, block.chainid);
        assertEq(initialDomainSeparator, currentDomainSeparator);
        assertEq(initialChainId, currentChainId);

        for (uint16 i = 0; i < 2; i++) {
            Strategy memory strategy = looksRareProtocol.viewStrategy(i);
            assertTrue(strategy.isActive);
            assertTrue(strategy.hasRoyalties);
            assertEq(strategy.protocolFee, uint16(200));
            assertEq(strategy.maxProtocolFee, uint16(300));
            assertEq(strategy.implementation, address(0));
        }
    }

    /**
     * One ERC721 (where royalties come from the registry) is sold through a taker bid
     */
    function testTakerBidERC721WithRoyaltiesFromRegistry() public {
        _setUpUsers();

        OrderStructs.MakerAsk memory makerAsk;
        OrderStructs.TakerBid memory takerBid;
        bytes memory signature;

        uint256 price = 1 ether; // Fixed price of sale
        uint16 royaltyFee = 100;
        uint256 itemId = 0; // TokenId
        uint16 minNetRatio = royaltyFee + 200; // 3% slippage protection

        _setUpRoyalties(address(mockERC721), royaltyFee);

        // Maker user actions
        vm.startPrank(makerUser);
        {
            // Mint asset
            mockERC721.mint(makerUser, itemId);

            // Prepare the order hash
            makerAsk = _createSingleItemMakerAskOrder(
                0, // askNonce
                0, // subsetNonce
                0, // strategyId (Standard sale for fixed price)
                0, // assetType ERC721,
                0, // orderNonce
                minNetRatio,
                address(mockERC721),
                address(0), // ETH,
                makerUser,
                price,
                itemId
            );

            // Sign order
            signature = _signMakerAsk(makerAsk, makerUserPK);
        }

        vm.stopPrank();

        // Taker user actions
        vm.startPrank(takerUser);

        {
            // Prepare the taker bid
            takerBid = OrderStructs.TakerBid(
                takerUser,
                makerAsk.minNetRatio,
                makerAsk.minPrice,
                makerAsk.itemIds,
                makerAsk.amounts,
                abi.encode()
            );
        }

        // Store the balances in ETH
        uint256 initialBalanceMakerUser = makerUser.balance;
        uint256 initialBalanceTakerUser = takerUser.balance;

        // Other execution parameters
        bytes32 merkleRoot = bytes32(0);
        address referrer = address(0); // No referrer
        bytes32[] memory merkleProof = new bytes32[](0);

        // Execute taker bid transaction
        looksRareProtocol.executeTakerBid{value: price}(
            takerBid,
            makerAsk,
            signature,
            merkleRoot,
            merkleProof,
            referrer
        );

        vm.stopPrank();

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(0), takerUser);
        // Taker bid user pays the whole price
        assertEq(address(takerUser).balance, initialBalanceTakerUser - price);
        // Maker ask user receives 97% of the whole price (2% protocol + 1% royalties)
        assertEq(address(makerUser).balance, initialBalanceMakerUser + (price * 9700) / 10000);
        // No leftover in the balance of the contract
        assertEq(address(looksRareProtocol).balance, 0);
        // Verify the nonce is marked as executed
        assertTrue(looksRareProtocol.viewUserOrderNonce(makerUser, makerAsk.orderNonce));
    }

    /**
     * One ERC721 (where royalties come from the registry) is sold through a taker ask using WETH
     */
    function testTakerAskERC721WithRoyaltiesFromRegistry() public {
        _setUpUsers();

        OrderStructs.MakerBid memory makerBid;
        OrderStructs.TakerAsk memory takerAsk;
        bytes memory signature;

        uint256 price = 1 ether; // Fixed price of sale
        uint16 royaltyFee = 100;
        uint256 itemId = 0; // TokenId
        uint16 minNetRatio = royaltyFee + 200; // 3% slippage protection

        _setUpRoyalties(address(mockERC721), royaltyFee);

        vm.startPrank(makerUser);
        // Maker user actions
        {
            // Prepare the order hash
            makerBid = _createSingleItemMakerBidOrder(
                0, // askNonce
                0, // subsetNonce
                0, // strategyId (Standard sale for fixed price)
                0, // assetType ERC721,
                0, // orderNonce
                minNetRatio,
                address(mockERC721),
                address(weth), // WETH,
                makerUser,
                price,
                itemId
            );

            // Sign order
            signature = _signMakerBid(makerBid, makerUserPK);
        }
        vm.stopPrank();

        // Taker user actions
        vm.startPrank(takerUser);

        {
            // Mint asset
            mockERC721.mint(takerUser, itemId);

            // Prepare the taker ask
            takerAsk = OrderStructs.TakerAsk(
                takerUser,
                makerBid.minNetRatio,
                makerBid.maxPrice,
                makerBid.itemIds,
                makerBid.amounts,
                abi.encode()
            );
        }

        // Store the balances in WETH
        uint256 initialBalanceMakerUser = weth.balanceOf(makerUser);
        uint256 initialBalanceTakerUser = weth.balanceOf(takerUser);

        // Other execution parameters
        bytes32 merkleRoot = bytes32(0);
        address referrer = address(0); // No referrer
        bytes32[] memory merkleProof = new bytes32[](0);

        // Execute taker bid transaction
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, merkleRoot, merkleProof, referrer);
        vm.stopPrank();

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(0), makerUser);
        // Maker bid user pays the whole price
        assertEq(weth.balanceOf(makerUser), initialBalanceMakerUser - price);
        // Taker ask user receives 97% of the whole price (2% protocol + 1% royalties)
        assertEq(weth.balanceOf(takerUser), initialBalanceTakerUser + (price * 9700) / 10000);
        // Verify the nonce is marked as executed
        assertTrue(looksRareProtocol.viewUserOrderNonce(makerUser, makerBid.orderNonce));
    }

    function testTakerBidMultipleOrdersSignedERC721() public {
        _setUpUsers();

        // Initialize Merkle Tree
        Merkle m = new Merkle();

        uint256 numberOrders = 3; // The test will buy itemId = 2
        bytes32[] memory orderHashes = new bytes32[](numberOrders);

        OrderStructs.MakerAsk memory makerAsk;
        OrderStructs.TakerBid memory takerBid;
        bytes memory signature;

        uint256 price = 1 ether; // Fixed price of sale
        uint16 minNetRatio = 9800; // 2% slippage protection for strategy

        // Maker user actions
        vm.startPrank(makerUser);

        for (uint112 i; i < numberOrders; i++) {
            // Mint asset
            mockERC721.mint(makerUser, i);

            // Prepare the order hash
            makerAsk = _createSingleItemMakerAskOrder(
                0, // askNonce
                0, // subsetNonce
                0, // strategyId (Standard sale for fixed price)
                0, // assetType ERC721,
                i, // orderNonce (incremental)
                minNetRatio,
                address(mockERC721),
                address(0), // ETH,
                makerUser,
                price,
                i // itemId
            );

            orderHashes[i] = _computeOrderHashMakerAsk(makerAsk);
        }

        bytes32 merkleRoot = m.getRoot(orderHashes);

        // Verify the merkle proof
        for (uint256 i; i < numberOrders; i++) {
            {
                bytes32[] memory tempMerkleProof = m.getProof(orderHashes, i);
                assertTrue(m.verifyProof(merkleRoot, tempMerkleProof, orderHashes[i]));
            }
        }

        // Maker signs the root
        signature = _signMerkleProof(merkleRoot, makerUserPK);

        vm.stopPrank();

        // Taker user actions
        vm.startPrank(takerUser);

        {
            // Prepare the taker bid
            takerBid = OrderStructs.TakerBid(
                takerUser,
                makerAsk.minNetRatio,
                makerAsk.minPrice,
                makerAsk.itemIds,
                makerAsk.amounts,
                abi.encode()
            );
        }

        bytes32[] memory merkleProof = m.getProof(orderHashes, numberOrders - 1);
        delete m;

        // Store the balances in ETH
        uint256 initialBalanceMakerUser = makerUser.balance;
        uint256 initialBalanceTakerUser = takerUser.balance;

        {
            // Execute taker bid transaction
            looksRareProtocol.executeTakerBid{value: price}(
                takerBid,
                makerAsk,
                signature,
                merkleRoot,
                merkleProof,
                address(0) // No referrer
            );
        }

        vm.stopPrank();

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(numberOrders - 1), takerUser);
        // Taker bid user pays the whole price
        assertEq(address(takerUser).balance, initialBalanceTakerUser - price);
        // Maker ask user receives 98% of the whole price (2% protocol)
        assertEq(address(makerUser).balance, initialBalanceMakerUser + (price * 9800) / 10000);
        // No leftover in the balance of the contract
        assertEq(address(looksRareProtocol).balance, 0);
        // Verify the nonce is marked as executed
        assertTrue(looksRareProtocol.viewUserOrderNonce(makerUser, makerAsk.orderNonce));
    }

    function testTakerAskMultipleOrdersSignedERC721() public {
        _setUpUsers();

        // Initialize Merkle Tree
        Merkle m = new Merkle();

        uint256 numberOrders = 3; // The test will sell itemId = 2
        bytes32[] memory orderHashes = new bytes32[](numberOrders);

        OrderStructs.MakerBid memory makerBid;
        OrderStructs.TakerAsk memory takerAsk;
        bytes memory signature;

        uint256 price = 1 ether; // Fixed price of sale
        uint16 minNetRatio = 9800; // 2% slippage protection for strategy

        // Maker user actions
        vm.startPrank(makerUser);

        for (uint112 i; i < numberOrders; i++) {
            // Prepare the order hash
            makerBid = _createSingleItemMakerBidOrder(
                0, // askNonce
                0, // subsetNonce
                0, // strategyId (Standard sale for fixed price)
                0, // assetType ERC721,
                i, // orderNonce (incremental)
                minNetRatio,
                address(mockERC721),
                address(weth), // ETH,
                makerUser,
                price,
                i // itemId
            );

            orderHashes[i] = _computeOrderHashMakerBid(makerBid);
        }

        bytes32 merkleRoot = m.getRoot(orderHashes);

        // Verify the merkle proof
        for (uint256 i; i < numberOrders; i++) {
            {
                bytes32[] memory tempMerkleProof = m.getProof(orderHashes, i);
                assertTrue(m.verifyProof(merkleRoot, tempMerkleProof, orderHashes[i]));
            }
        }

        // Maker signs the root
        signature = _signMerkleProof(merkleRoot, makerUserPK);
        vm.stopPrank();

        // Taker user actions
        vm.startPrank(takerUser);

        {
            // Mint asset
            mockERC721.mint(takerUser, numberOrders - 1);

            // Prepare the taker ask
            takerAsk = OrderStructs.TakerAsk(
                takerUser,
                makerBid.minNetRatio,
                makerBid.maxPrice,
                makerBid.itemIds,
                makerBid.amounts,
                abi.encode()
            );
        }

        bytes32[] memory merkleProof = m.getProof(orderHashes, numberOrders - 1);
        delete m;

        // Store the balances in WETH
        uint256 initialBalanceMakerUser = weth.balanceOf(makerUser);
        uint256 initialBalanceTakerUser = weth.balanceOf(takerUser);

        {
            // Execute taker ask transaction
            looksRareProtocol.executeTakerAsk(
                takerAsk,
                makerBid,
                signature,
                merkleRoot,
                merkleProof,
                address(0) // No referrer
            );
        }

        vm.stopPrank();

        // Maker user has received the asset
        assertEq(mockERC721.ownerOf(numberOrders - 1), makerUser);
        // Maker bid user pays the whole price
        assertEq(weth.balanceOf(makerUser), initialBalanceMakerUser - price);
        // Taker ask user receives 97% of the whole price (2% protocol)
        assertEq(weth.balanceOf(takerUser), initialBalanceTakerUser + (price * 9800) / 10000);
        // Verify the nonce is marked as executed
        assertTrue(looksRareProtocol.viewUserOrderNonce(makerUser, makerBid.orderNonce));
    }
}
