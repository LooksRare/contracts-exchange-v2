// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";
import {ProtocolBase} from "./ProtocolBase.t.sol";

contract CollectionOrdersTest is ProtocolBase {
    /**
     * Any itemId for ERC721 (where royalties come from the registry) is sold through a collection taker ask using WETH.
     * We use fuzzing to generate the tokenId that is sold.
     */
    function testTakerAskCollectionOrderERC721WithRoyaltiesFromRegistry(uint256 tokenId) public {
        _setUpUsers();

        uint256 price = 1 ether; // Fixed price of sale
        uint16 minNetRatio = 10000 - (_standardRoyaltyFee + _standardProtocolFee); // 3% slippage protection

        _setUpRoyalties(address(mockERC721), _standardRoyaltyFee);

        {
            // Prepare the order hash
            makerBid = _createSingleItemMakerBidOrder(
                0, // askNonce
                0, // subsetNonce
                1, // strategyId (Collection offer)
                0, // assetType ERC721,
                0, // orderNonce
                minNetRatio,
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
            takerAsk = OrderStructs.TakerAsk(
                takerUser,
                makerBid.minNetRatio,
                makerBid.maxPrice,
                itemIds,
                makerBid.amounts,
                abi.encode()
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
                _emptyReferrer
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
        assertTrue(looksRareProtocol.viewUserOrderNonce(makerUser, makerBid.orderNonce));
    }
}
