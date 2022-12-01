// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Merkle} from "../../lib/murky/src/Merkle.sol";

import {StrategyCollectionOffer} from "../../contracts/executionStrategies/StrategyCollectionOffer.sol";
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";
import {ProtocolBase} from "./ProtocolBase.t.sol";

contract CollectionOrdersTest is ProtocolBase {
    error OrderInvalid();

    StrategyCollectionOffer public strategyCollectionOffer;
    bytes4 public selectorTakerAskNoProof = strategyCollectionOffer.executeCollectionStrategyWithTakerAsk.selector;
    bytes4 public selectorTakerAskWithProof =
        strategyCollectionOffer.executeCollectionStrategyWithTakerAskWithProof.selector;

    bytes4 public selectorTakerBid = _emptyBytes4;

    function _setUpNewStrategies() private asPrankedUser(_owner) {
        strategyCollectionOffer = new StrategyCollectionOffer(address(looksRareProtocol));

        looksRareProtocol.addStrategy(
            _standardProtocolFee,
            _minTotalFee,
            _maxProtocolFee,
            selectorTakerAskNoProof,
            selectorTakerBid,
            address(strategyCollectionOffer)
        );

        looksRareProtocol.addStrategy(
            _standardProtocolFee,
            _minTotalFee,
            _maxProtocolFee,
            selectorTakerAskWithProof,
            selectorTakerBid,
            address(strategyCollectionOffer)
        );
    }

    function testNewStrategies() public {
        _setUpNewStrategies();

        (
            bool strategyIsActive,
            uint16 strategyStandardProtocolFee,
            uint16 strategyMinTotalFee,
            uint16 strategyMaxProtocolFee,
            bytes4 strategySelectorTakerAsk,
            bytes4 strategySelectorTakerBid,
            address strategyImplementation
        ) = looksRareProtocol.strategyInfo(1);

        assertTrue(strategyIsActive);
        assertEq(strategyStandardProtocolFee, _standardProtocolFee);
        assertEq(strategyMinTotalFee, _minTotalFee);
        assertEq(strategyMaxProtocolFee, _maxProtocolFee);
        assertEq(strategySelectorTakerAsk, selectorTakerAskNoProof);
        assertEq(strategySelectorTakerBid, selectorTakerBid);
        assertEq(strategyImplementation, address(strategyCollectionOffer));

        (
            strategyIsActive,
            strategyStandardProtocolFee,
            strategyMinTotalFee,
            strategyMaxProtocolFee,
            strategySelectorTakerAsk,
            strategySelectorTakerBid,
            strategyImplementation
        ) = looksRareProtocol.strategyInfo(2);

        assertTrue(strategyIsActive);
        assertEq(strategyStandardProtocolFee, _standardProtocolFee);
        assertEq(strategyMinTotalFee, _minTotalFee);
        assertEq(strategyMaxProtocolFee, _maxProtocolFee);
        assertEq(strategySelectorTakerAsk, selectorTakerAskWithProof);
        assertEq(strategySelectorTakerBid, selectorTakerBid);
        assertEq(strategyImplementation, address(strategyCollectionOffer));
    }

    function testWrongOrderFormat() public {
        _setUpNewStrategies();
        (makerBid, takerAsk) = _createMockMakerBidAndTakerAsk(address(mockERC721), address(weth));

        // Adjust strategy for collection order and sign order
        // Change array to make it bigger than expected
        uint256[] memory itemIds = new uint256[](2);
        itemIds[0] = 0;
        makerBid.strategyId = 1;
        makerBid.itemIds = itemIds;
        takerAsk.itemIds = itemIds;
        signature = _signMakerBid(makerBid, makerUserPK);

        vm.expectRevert(OrderInvalid.selector);
        looksRareProtocol.executeTakerAsk(
            takerAsk,
            makerBid,
            signature,
            _emptyMerkleRoot,
            _emptyMerkleProof,
            _emptyAffiliate
        );
    }

    /**
     * Any itemId for ERC721 (where royalties come from the registry) is sold through a collection taker ask using WETH.
     * We use fuzzing to generate the tokenId that is sold.
     */
    function testTakerAskCollectionOrderERC721(uint256 tokenId) public {
        _setUpUsers();
        _setUpNewStrategies();

        price = 1 ether; // Fixed price of sale

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

        (bool isValid, bytes4 errorSelector) = strategyCollectionOffer.isValid(makerBid);
        assertTrue(isValid);
        assertEq(errorSelector, bytes4(0));

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
        // Taker ask user receives 98% of the whole price (2% protocol)
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser + (price * 9800) / 10000);
        // Verify the nonce is marked as executed
        assertEq(looksRareProtocol.userOrderNonce(makerUser, makerBid.orderNonce), MAGIC_VALUE_NONCE_EXECUTED);
    }

    /**
     * A collection offer with merkle tree criteria
     */
    function testTakerAskCollectionOrderWithMerkleTreeERC721() public {
        _setUpUsers();
        _setUpNewStrategies();

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

        {
            // Prepare the order hash
            makerBid = _createSingleItemMakerBidOrder(
                0, // bidNonce
                0, // subsetNonce
                2, // strategyId (Collection offer with proofs)
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

        (bool isValid, bytes4 errorSelector) = strategyCollectionOffer.isValid(makerBid);
        assertTrue(isValid);
        assertEq(errorSelector, bytes4(0));

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
        // Taker ask user receives 98% of the whole price (2% protocol)
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser + (price * 9800) / 10000);
        // Verify the nonce is marked as executed
        assertEq(looksRareProtocol.userOrderNonce(makerUser, makerBid.orderNonce), MAGIC_VALUE_NONCE_EXECUTED);
    }
}
