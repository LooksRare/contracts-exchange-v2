// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Murky (third-party) library is used to compute Merkle trees in Solidity
import {Merkle} from "../../lib/murky/src/Merkle.sol";

// Libraries
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";

// Strategies
import {StrategyCollectionOffer} from "../../contracts/executionStrategies/StrategyCollectionOffer.sol";

// Base test
import {ProtocolBase} from "./ProtocolBase.t.sol";

contract CollectionOrdersTest is ProtocolBase {
    error OrderInvalid();

    StrategyCollectionOffer public strategyCollectionOffer;
    bytes4 public selectorNoProof = strategyCollectionOffer.executeCollectionStrategyWithTakerAsk.selector;
    bytes4 public selectorWithProof = strategyCollectionOffer.executeCollectionStrategyWithTakerAskWithProof.selector;

    function setUp() public override {
        super.setUp();
        _setUpNewStrategies();
    }

    function _setUpNewStrategies() private asPrankedUser(_owner) {
        strategyCollectionOffer = new StrategyCollectionOffer(address(looksRareProtocol));

        looksRareProtocol.addStrategy(
            _standardProtocolFee,
            _minTotalFee,
            _maxProtocolFee,
            selectorNoProof,
            true,
            address(strategyCollectionOffer)
        );

        looksRareProtocol.addStrategy(
            _standardProtocolFee,
            _minTotalFee,
            _maxProtocolFee,
            selectorWithProof,
            true,
            address(strategyCollectionOffer)
        );
    }

    function testNewStrategies() public {
        (
            bool strategyIsActive,
            uint16 strategyStandardProtocolFee,
            uint16 strategyMinTotalFee,
            uint16 strategyMaxProtocolFee,
            bytes4 strategySelector,
            bool strategyIsMakerBid,
            address strategyImplementation
        ) = looksRareProtocol.strategyInfo(1);

        assertTrue(strategyIsActive);
        assertEq(strategyStandardProtocolFee, _standardProtocolFee);
        assertEq(strategyMinTotalFee, _minTotalFee);
        assertEq(strategyMaxProtocolFee, _maxProtocolFee);
        assertEq(strategySelector, selectorNoProof);
        assertTrue(strategyIsMakerBid);
        assertEq(strategyImplementation, address(strategyCollectionOffer));

        (
            strategyIsActive,
            strategyStandardProtocolFee,
            strategyMinTotalFee,
            strategyMaxProtocolFee,
            strategySelector,
            strategyIsMakerBid,
            strategyImplementation
        ) = looksRareProtocol.strategyInfo(2);

        assertTrue(strategyIsActive);
        assertEq(strategyStandardProtocolFee, _standardProtocolFee);
        assertEq(strategyMinTotalFee, _minTotalFee);
        assertEq(strategyMaxProtocolFee, _maxProtocolFee);
        assertEq(strategySelector, selectorWithProof);
        assertTrue(strategyIsMakerBid);
        assertEq(strategyImplementation, address(strategyCollectionOffer));
    }

    function testItemIdsLengthNotOne() public {
        (makerBid, takerAsk) = _createMockMakerBidAndTakerAsk(address(mockERC721), address(weth));

        // Adjust strategy for collection order and sign order
        // Change array to make it bigger than expected
        uint256[] memory itemIds = new uint256[](2);
        itemIds[0] = 1;
        makerBid.strategyId = 1;
        takerAsk.itemIds = itemIds;
        signature = _signMakerBid(makerBid, makerUserPK);

        // Maker bid is still valid
        _assertOrderIsValid(makerBid);

        vm.expectRevert(OrderInvalid.selector);
        _executeTakerAsk();

        // With proof
        makerBid.strategyId = 2;
        signature = _signMakerBid(makerBid, makerUserPK);

        _assertOrderIsValid(makerBid);

        vm.expectRevert(OrderInvalid.selector);
        _executeTakerAsk();
    }

    function testAmountsMismatch() public {
        (makerBid, takerAsk) = _createMockMakerBidAndTakerAsk(address(mockERC721), address(weth));

        uint256[] memory makerBidAmounts = new uint256[](1);
        makerBidAmounts[0] = 1;
        uint256[] memory takerAskAmounts = new uint256[](1);
        takerAskAmounts[0] = 2;
        makerBid.amounts = makerBidAmounts;
        takerAsk.amounts = takerAskAmounts;

        // Adjust strategy for collection order and sign order
        makerBid.strategyId = 1;
        signature = _signMakerBid(makerBid, makerUserPK);

        _assertOrderIsValid(makerBid);

        vm.expectRevert(OrderInvalid.selector);
        _executeTakerAsk();

        // With proof
        makerBid.strategyId = 2;
        signature = _signMakerBid(makerBid, makerUserPK);

        _assertOrderIsValid(makerBid);

        vm.expectRevert(OrderInvalid.selector);
        _executeTakerAsk();
    }

    function testAmountsLengthNotOne() public {
        (makerBid, takerAsk) = _createMockMakerBidAndTakerAsk(address(mockERC721), address(weth));

        // Adjust strategy for collection order and sign order
        // Change array to make it bigger than expected
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        makerBid.strategyId = 1;
        makerBid.amounts = amounts;
        takerAsk.amounts = amounts;
        signature = _signMakerBid(makerBid, makerUserPK);

        _assertOrderIsInvalid(makerBid);

        vm.expectRevert(OrderInvalid.selector);
        _executeTakerAsk();

        // With proof
        makerBid.strategyId = 2;
        signature = _signMakerBid(makerBid, makerUserPK);

        _assertOrderIsInvalid(makerBid);

        vm.expectRevert(OrderInvalid.selector);
        _executeTakerAsk();
    }

    function testZeroAmount() public {
        (makerBid, takerAsk) = _createMockMakerBidAndTakerAsk(address(mockERC721), address(weth));

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0;
        makerBid.amounts = amounts;
        signature = _signMakerBid(makerBid, makerUserPK);

        _assertOrderIsInvalid(makerBid);

        vm.expectRevert(OrderInvalid.selector);
        _executeTakerAsk();
    }

    function testBidAskAmountMismatch() public {
        (makerBid, takerAsk) = _createMockMakerBidAndTakerAsk(address(mockERC721), address(weth));

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 2;
        takerAsk.amounts = amounts;
        signature = _signMakerBid(makerBid, makerUserPK);

        // Maker bid still valid
        _assertOrderIsValid(makerBid);

        vm.expectRevert(OrderInvalid.selector);
        _executeTakerAsk();
    }

    function testPriceMismatch() public {
        (makerBid, takerAsk) = _createMockMakerBidAndTakerAsk(address(mockERC721), address(weth));

        takerAsk.minPrice = makerBid.maxPrice + 1;
        signature = _signMakerBid(makerBid, makerUserPK);

        // Maker bid still valid
        _assertOrderIsValid(makerBid);

        vm.expectRevert(OrderInvalid.selector);
        _executeTakerAsk();
    }

    /**
     * Any itemId for ERC721 (where royalties come from the registry) is sold through a collection taker ask using WETH.
     * We use fuzzing to generate the tokenId that is sold.
     */
    function testTakerAskCollectionOrderERC721(uint256 tokenId) public {
        _setUpUsers();

        price = 1 ether; // Fixed price of sale

        {
            // Prepare the order hash
            makerBid = _createSingleItemMakerBidOrder({
                bidNonce: 0,
                subsetNonce: 0,
                strategyId: 1,
                assetType: 0, // ERC721,
                orderNonce: 0,
                collection: address(mockERC721),
                currency: address(weth),
                signer: makerUser,
                maxPrice: price,
                itemId: 0 // Not used
            });

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

        _assertOrderIsValid(makerBid);

        uint256 gasLeft = gasleft();

        _executeTakerAsk();

        emit log_named_uint(
            "TakerAsk // ERC721 // Protocol Fee // CollectionOrder // Registry Royalties",
            gasLeft - gasleft()
        );

        vm.stopPrank();

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(tokenId), makerUser);
        // Maker bid user pays the whole price
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser - price);
        // Taker ask user receives 98% of the whole price (2% protocol)
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser + (price * 9_800) / 10_000);
        // Verify the nonce is marked as executed
        assertEq(looksRareProtocol.userOrderNonce(makerUser, makerBid.orderNonce), MAGIC_VALUE_NONCE_EXECUTED);
    }

    /**
     * A collection offer with merkle tree criteria
     */
    function testTakerAskCollectionOrderWithMerkleTreeERC721() public {
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

        {
            // Prepare the order hash
            makerBid = _createSingleItemMakerBidOrder({
                bidNonce: 0,
                subsetNonce: 0,
                strategyId: 2,
                assetType: 0, // ERC721,
                orderNonce: 0,
                collection: address(mockERC721),
                currency: address(weth),
                signer: makerUser,
                maxPrice: price,
                itemId: 0 // Not used
            });

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

        _assertOrderIsValid(makerBid);

        uint256 gasLeft = gasleft();

        _executeTakerAsk();

        emit log_named_uint(
            "TakerAsk // ERC721 // Protocol Fee // Collection Order with Merkle Tree // Registry Royalties",
            gasLeft - gasleft()
        );

        vm.stopPrank();

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(itemIdSold), makerUser);
        // Maker bid user pays the whole price
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser - price);
        // Taker ask user receives 98% of the whole price (2% protocol)
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser + (price * 9_800) / 10_000);
        // Verify the nonce is marked as executed
        assertEq(looksRareProtocol.userOrderNonce(makerUser, makerBid.orderNonce), MAGIC_VALUE_NONCE_EXECUTED);
    }

    function _assertOrderIsValid(OrderStructs.MakerBid memory makerBid) private {
        (bool isValid, bytes4 errorSelector) = strategyCollectionOffer.isValid(makerBid);
        assertTrue(isValid);
        assertEq(errorSelector, bytes4(0));
    }

    function _assertOrderIsInvalid(OrderStructs.MakerBid memory makerBid) private {
        (bool isValid, bytes4 errorSelector) = strategyCollectionOffer.isValid(makerBid);
        assertFalse(isValid);
        assertEq(errorSelector, OrderInvalid.selector);
    }

    function _executeTakerAsk() private {
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _emptyMerkleTree, _emptyAffiliate);
    }
}
