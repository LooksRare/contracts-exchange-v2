// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Merkle} from "../../lib/murky/src/Merkle.sol";

import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";
import {ProtocolBase} from "./ProtocolBase.t.sol";

contract CollectionOrdersTest is ProtocolBase {
    /**
     * Any itemId for ERC721 (where royalties come from the registry) is sold through a collection taker ask using WETH.
     * We use fuzzing to generate the tokenId that is sold.
     */
    function testTakerAskCollectionOrderERC721WithRoyaltiesFromRegistry(uint256 tokenId) public {
        _setUpUsers();

        price = 1 ether; // Fixed price of sale
        uint16 minNetRatio = 10000 - (_standardRoyaltyFee + _standardProtocolFee); // 3% slippage protection

        // TODO: Royalty/Rebate adjustment

        {
            // Prepare the order hash
            makerBid = _createSingleItemMakerBidOrder(
                0, // bidNonce
                0, // subsetNonce
                1, // strategyId (Collection offer)
                0, // assetType ERC721,
                0, // orderNonce
                address(mockERC721),
                address(weth),
                makerUser,
                price,
                0 // itemId (not used)
            );

            // Sign order
            signature = _signMakerBid(makerBid, makerUserPK);
        }

        // Taker user actions
        vm.startPrank(takerUser);

        {
            // Mint asset
            mockERC721.mint(takerUser, tokenId);

            uint256[] memory itemIds = new uint256[](1);
            itemIds[0] = tokenId;

            // Prepare the taker ask
            takerAsk = OrderStructs.TakerAsk(takerUser, makerBid.maxPrice, itemIds, makerBid.amounts, abi.encode());
        }

        {
            uint256 gasLeft = gasleft();

            // Execute taker ask transaction
            looksRareProtocol.executeTakerAsk(
                takerAsk,
                makerBid,
                signature,
                _emptyMerkleRoot,
                _emptyMerkleProof,
                _emptyAffiliate
            );
            emit log_named_uint(
                "TakerAsk // ERC721 // Protocol Fee // CollectionOrder // Registry Royalties",
                gasLeft - gasleft()
            );
        }

        vm.stopPrank();

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(tokenId), makerUser);
        // Maker bid user pays the whole price
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser - price);
        // Taker ask user receives 97% of the whole price (2% protocol + 1% royalties)
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser + (price * 9700) / 10000);
        // Verify the nonce is marked as executed
        assertTrue(looksRareProtocol.userOrderNonce(makerUser, makerBid.orderNonce));
    }

    /**
     * A collection offer with merkle tree criteria
     */
    function testTakerAskCollectionOrderWithMerkleTreeERC721WithRoyaltiesFromRegistry() public {
        _setUpUsers();

        // Initialize Merkle Tree
        Merkle m = new Merkle();

        bytes32[] memory merkleTreeIds = new bytes32[](5);
        for (uint256 i; i < merkleTreeIds.length; i++) {
            mockERC721.mint(takerUser, i);
            merkleTreeIds[i] = keccak256(abi.encodePacked(i));
        }

        // Compute merkle root
        bytes32 merkleRoot = m.getRoot(merkleTreeIds);

        price = 1 ether; // Fixed price of sale
        uint16 minNetRatio = 10000 - (_standardRoyaltyFee + _standardProtocolFee); // 3% slippage protection

        // TODO: Royalty/Rebate adjustment

        {
            // Prepare the order hash
            makerBid = _createSingleItemMakerBidOrder(
                0, // bidNonce
                0, // subsetNonce
                1, // strategyId (Collection offer)
                0, // assetType ERC721,
                0, // orderNonce
                address(mockERC721),
                address(weth),
                makerUser,
                price,
                0 // itemId (not used)
            );

            makerBid.additionalParameters = abi.encode(merkleRoot);

            // Sign order
            signature = _signMakerBid(makerBid, makerUserPK);
        }

        // Taker user actions
        vm.startPrank(takerUser);

        uint256 itemIdSold = 2;
        bytes32[] memory proof = m.getProof(merkleTreeIds, 2);

        assertTrue(m.verifyProof(merkleRoot, proof, merkleTreeIds[2]));

        {
            uint256[] memory itemIds = new uint256[](1);
            itemIds[0] = itemIdSold;

            // Prepare the taker ask
            takerAsk = OrderStructs.TakerAsk(
                takerUser,
                makerBid.maxPrice,
                itemIds,
                makerBid.amounts,
                abi.encode(proof)
            );
        }

        {
            uint256 gasLeft = gasleft();

            // Execute taker ask transaction
            looksRareProtocol.executeTakerAsk(
                takerAsk,
                makerBid,
                signature,
                _emptyMerkleRoot,
                _emptyMerkleProof,
                _emptyAffiliate
            );

            emit log_named_uint(
                "TakerAsk // ERC721 // Protocol Fee // Collection Order with Merkle Tree // Registry Royalties",
                gasLeft - gasleft()
            );
        }

        vm.stopPrank();

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(itemIdSold), makerUser);
        // Maker bid user pays the whole price
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser - price);
        // Taker ask user receives 97% of the whole price (2% protocol + 1% royalties)
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser + (price * 9700) / 10000);
        // Verify the nonce is marked as executed
        assertTrue(looksRareProtocol.userOrderNonce(makerUser, makerBid.orderNonce));
    }
}
