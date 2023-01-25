// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Libraries, interfaces, errors
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";
import {ITransferSelectorNFT} from "../../contracts/interfaces/ITransferSelectorNFT.sol";
import {INonceManager} from "../../contracts/interfaces/INonceManager.sol";
import {LengthsInvalid} from "../../contracts/errors/SharedErrors.sol";
import {INVALID_USER_GLOBAL_BID_NONCE, INVALID_USER_GLOBAL_ASK_NONCE, USER_SUBSET_NONCE_CANCELLED, USER_ORDER_NONCE_IN_EXECUTION_WITH_OTHER_HASH, USER_ORDER_NONCE_EXECUTED_OR_CANCELLED} from "../../contracts/constants/ValidationCodeConstants.sol";

// Other utils and tests
import {StrategyTestMultiFillCollectionOrder} from "./utils/StrategyTestMultiFillCollectionOrder.sol";
import {ProtocolBase} from "./ProtocolBase.t.sol";

// Constants
import {ASSET_TYPE_ERC721} from "../../contracts/constants/NumericConstants.sol";

contract NonceInvalidationTest is INonceManager, ProtocolBase {
    uint256 private constant price = 1 ether; // Fixed price of sale

    /**
     * Cannot execute an order if subset nonce is used
     */
    function testCannotExecuteOrderIfSubsetNonceIsUsed(uint256 subsetNonce) public {
        uint256 itemId = 420;

        // Mint asset
        mockERC721.mint(makerUser, itemId);

        // Prepare the order hash
        OrderStructs.MakerAsk memory makerAsk = _createSingleItemMakerAskOrder({
            askNonce: 0,
            subsetNonce: subsetNonce,
            strategyId: STANDARD_SALE_FOR_FIXED_PRICE_STRATEGY,
            assetType: ASSET_TYPE_ERC721,
            orderNonce: 0,
            collection: address(mockERC721),
            currency: ETH,
            signer: makerUser,
            minPrice: price,
            itemId: itemId
        });

        // Sign order
        bytes memory signature = _signMakerAsk(makerAsk, makerUserPK);

        uint256[] memory subsetNonces = new uint256[](1);
        subsetNonces[0] = subsetNonce;

        vm.prank(makerUser);
        vm.expectEmit({checkTopic1: false, checkTopic2: false, checkTopic3: false, checkData: true});
        emit SubsetNoncesCancelled(makerUser, subsetNonces);
        looksRareProtocol.cancelSubsetNonces(subsetNonces);

        _doesMakerAskOrderReturnValidationCode(makerAsk, signature, USER_SUBSET_NONCE_CANCELLED);

        // Prepare the taker bid
        OrderStructs.TakerBid memory takerBid = OrderStructs.TakerBid(
            takerUser,
            makerAsk.minPrice,
            new uint256[](0),
            new uint256[](0),
            abi.encode(new uint256[](0), new uint256[](0))
        );

        vm.deal(takerUser, price);

        // Execute taker bid transaction
        // Taker user actions
        vm.prank(takerUser);
        vm.expectRevert(NoncesInvalid.selector);
        looksRareProtocol.executeTakerBid{value: price}(
            takerBid,
            makerAsk,
            signature,
            _EMPTY_MERKLE_TREE,
            _EMPTY_AFFILIATE
        );
    }

    /**
     * Cannot execute an order if maker is at a different global ask nonce than signed
     */
    function testCannotExecuteOrderIfInvalidUserGlobalAskNonce(uint256 userGlobalAskNonce) public {
        // Change block number
        vm.roll(1);

        uint256 quasiRandomNumber = 54570651553685478358117286254199992264;
        assertEq(quasiRandomNumber, uint256(blockhash(block.number - 1) >> 128));
        uint256 newAskNonce = 0 + quasiRandomNumber;

        vm.prank(makerUser);
        vm.expectEmit({checkTopic1: false, checkTopic2: false, checkTopic3: false, checkData: true});
        emit NewBidAskNonces(makerUser, 0, newAskNonce);
        looksRareProtocol.incrementBidAskNonces(false, true);

        uint256 itemId = 420;

        // Mint asset
        mockERC721.mint(makerUser, itemId);

        // Prepare the order hash
        OrderStructs.MakerAsk memory makerAsk = _createSingleItemMakerAskOrder({
            askNonce: userGlobalAskNonce,
            subsetNonce: 0,
            strategyId: STANDARD_SALE_FOR_FIXED_PRICE_STRATEGY,
            assetType: ASSET_TYPE_ERC721,
            orderNonce: 0,
            collection: address(mockERC721),
            currency: ETH,
            signer: makerUser,
            minPrice: price,
            itemId: itemId
        });

        // Sign order
        bytes memory signature = _signMakerAsk(makerAsk, makerUserPK);

        _doesMakerAskOrderReturnValidationCode(makerAsk, signature, INVALID_USER_GLOBAL_ASK_NONCE);

        // Prepare the taker bid
        OrderStructs.TakerBid memory takerBid = OrderStructs.TakerBid(
            takerUser,
            makerAsk.minPrice,
            new uint256[](0),
            new uint256[](0),
            abi.encode()
        );

        vm.deal(takerUser, price);

        // Execute taker bid transaction
        // Taker user actions
        vm.prank(takerUser);
        vm.expectRevert(NoncesInvalid.selector);
        looksRareProtocol.executeTakerBid{value: price}(
            takerBid,
            makerAsk,
            signature,
            _EMPTY_MERKLE_TREE,
            _EMPTY_AFFILIATE
        );
    }

    /**
     * Cannot execute an order if maker is at a different global bid nonce than signed
     */
    function testCannotExecuteOrderIfInvalidUserGlobalBidNonce(uint256 userGlobalBidNonce) public {
        // Change block number
        vm.roll(1);

        uint256 quasiRandomNumber = 54570651553685478358117286254199992264;
        assertEq(quasiRandomNumber, uint256(blockhash(block.number - 1) >> 128));
        uint256 newBidNonce = 0 + quasiRandomNumber;

        vm.prank(makerUser);
        vm.expectEmit({checkTopic1: false, checkTopic2: false, checkTopic3: false, checkData: true});
        emit NewBidAskNonces(makerUser, newBidNonce, 0);
        looksRareProtocol.incrementBidAskNonces(true, false);

        uint256 itemId = 420;

        // Prepare the order hash
        OrderStructs.MakerBid memory makerBid = _createSingleItemMakerBidOrder({
            bidNonce: userGlobalBidNonce,
            subsetNonce: 0,
            strategyId: STANDARD_SALE_FOR_FIXED_PRICE_STRATEGY,
            assetType: ASSET_TYPE_ERC721,
            orderNonce: 0,
            collection: address(mockERC721),
            currency: address(weth),
            signer: makerUser,
            maxPrice: price,
            itemId: itemId
        });

        // Sign order
        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        _doesMakerBidOrderReturnValidationCode(makerBid, signature, INVALID_USER_GLOBAL_BID_NONCE);

        // Mint asset
        mockERC721.mint(takerUser, itemId);

        // Prepare the taker ask
        OrderStructs.TakerAsk memory takerAsk = OrderStructs.TakerAsk(
            takerUser,
            makerBid.maxPrice,
            new uint256[](0),
            new uint256[](0),
            abi.encode()
        );

        // Execute taker ask transaction
        // Taker user actions
        vm.prank(takerUser);
        vm.expectRevert(NoncesInvalid.selector);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    /**
     * Cannot execute an order twice
     */
    function testCannotExecuteAnOrderTwice() public {
        _setUpUsers();
        _setupRegistryRoyalties(address(mockERC721), _standardRoyaltyFee);

        uint256 itemId = 0;

        // Prepare the order hash
        OrderStructs.MakerBid memory makerBid = _createSingleItemMakerBidOrder({
            bidNonce: 0,
            subsetNonce: 0,
            strategyId: STANDARD_SALE_FOR_FIXED_PRICE_STRATEGY,
            assetType: ASSET_TYPE_ERC721,
            orderNonce: 0,
            collection: address(mockERC721),
            currency: address(weth),
            signer: makerUser,
            maxPrice: price,
            itemId: itemId
        });

        // Sign order
        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        // Mint asset
        mockERC721.mint(takerUser, itemId);

        // Taker user actions
        vm.startPrank(takerUser);

        // Prepare the taker ask
        OrderStructs.TakerAsk memory takerAsk = OrderStructs.TakerAsk(
            takerUser,
            makerBid.maxPrice,
            new uint256[](0),
            new uint256[](0),
            abi.encode()
        );

        {
            looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);

            _doesMakerBidOrderReturnValidationCode(makerBid, signature, USER_ORDER_NONCE_EXECUTED_OR_CANCELLED);

            // Second one fails
            vm.expectRevert(NoncesInvalid.selector);
            looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
        }

        vm.stopPrank();
    }

    /**
     * Cannot execute an order sharing the same order nonce as another that is being partially filled
     */
    function testCannotExecuteAnotherOrderAtNonceIfExecutionIsInProgress(uint256 orderNonce) public {
        _setUpUsers();

        // 0. Add the new strategy
        bytes4 selector = StrategyTestMultiFillCollectionOrder.executeStrategyWithTakerAsk.selector;

        StrategyTestMultiFillCollectionOrder strategyMultiFillCollectionOrder = new StrategyTestMultiFillCollectionOrder(
                address(looksRareProtocol)
            );

        vm.prank(_owner);
        looksRareProtocol.addStrategy(
            _standardProtocolFeeBp,
            _minTotalFeeBp,
            _maxProtocolFeeBp,
            selector,
            true,
            address(strategyMultiFillCollectionOrder)
        );

        // 1. Maker signs a message and execute a partial fill on it
        uint256 amountsToFill = 4;

        uint256[] memory itemIds = new uint256[](0);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amountsToFill;

        // Prepare the first order
        OrderStructs.MakerBid memory makerBid = _createMultiItemMakerBidOrder({
            bidNonce: 0,
            subsetNonce: 0,
            strategyId: 1, // Multi-fill bid offer
            assetType: ASSET_TYPE_ERC721,
            orderNonce: orderNonce,
            collection: address(mockERC721),
            currency: address(weth),
            signer: makerUser,
            maxPrice: price,
            itemIds: itemIds,
            amounts: amounts
        });

        // Sign order
        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        // First taker user actions
        {
            itemIds = new uint256[](1);
            amounts = new uint256[](1);
            itemIds[0] = 0;
            amounts[0] = 1;

            mockERC721.mint(takerUser, itemIds[0]);

            // Prepare the taker ask
            OrderStructs.TakerAsk memory takerAsk = OrderStructs.TakerAsk(
                takerUser,
                makerBid.maxPrice,
                new uint256[](0),
                new uint256[](0),
                abi.encode(itemIds, amounts)
            );

            vm.prank(takerUser);

            // Execute taker ask transaction
            looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
        }

        // 2. Second maker order is signed sharing the same order nonce as the first one
        {
            uint256 itemId = 420;

            itemIds = new uint256[](1);
            amounts = new uint256[](1);
            itemIds[0] = itemId;
            amounts[0] = 1;

            // Prepare the second order
            makerBid = _createMultiItemMakerBidOrder({
                bidNonce: 0,
                subsetNonce: 0,
                strategyId: STANDARD_SALE_FOR_FIXED_PRICE_STRATEGY,
                assetType: ASSET_TYPE_ERC721,
                orderNonce: orderNonce,
                collection: address(mockERC721),
                currency: address(weth),
                signer: makerUser,
                maxPrice: price,
                itemIds: itemIds,
                amounts: amounts
            });

            // Sign order
            signature = _signMakerBid(makerBid, makerUserPK);

            _doesMakerBidOrderReturnValidationCode(makerBid, signature, USER_ORDER_NONCE_IN_EXECUTION_WITH_OTHER_HASH);

            // Prepare the taker ask
            OrderStructs.TakerAsk memory takerAsk = OrderStructs.TakerAsk(
                takerUser,
                makerBid.maxPrice,
                new uint256[](0),
                new uint256[](0),
                abi.encode(new uint256[](0), new uint256[](0))
            );

            vm.prank(takerUser);

            // Second one fails when a taker user tries to execute
            vm.expectRevert(NoncesInvalid.selector);
            looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
        }
    }

    function testCancelOrderNonces(uint256 nonceOne, uint256 nonceTwo) public asPrankedUser(makerUser) {
        assertEq(looksRareProtocol.userOrderNonce(makerUser, nonceOne), bytes32(0));
        assertEq(looksRareProtocol.userOrderNonce(makerUser, nonceTwo), bytes32(0));

        uint256[] memory orderNonces = new uint256[](2);
        orderNonces[0] = nonceOne;
        orderNonces[1] = nonceTwo;
        vm.expectEmit({checkTopic1: true, checkTopic2: false, checkTopic3: false, checkData: true});
        emit OrderNoncesCancelled(makerUser, orderNonces);
        looksRareProtocol.cancelOrderNonces(orderNonces);

        assertEq(looksRareProtocol.userOrderNonce(makerUser, nonceOne), MAGIC_VALUE_ORDER_NONCE_EXECUTED);
        assertEq(looksRareProtocol.userOrderNonce(makerUser, nonceTwo), MAGIC_VALUE_ORDER_NONCE_EXECUTED);
    }

    /**
     * Cannot execute an order if its nonce has been cancelled
     */
    function testCannotExecuteAnOrderWhoseNonceIsCancelled(uint256 orderNonce) public {
        _setUpUsers();
        _setupRegistryRoyalties(address(mockERC721), _standardRoyaltyFee);

        uint256 itemId = 0;

        uint256[] memory orderNonces = new uint256[](1);
        orderNonces[0] = orderNonce;
        vm.prank(makerUser);
        looksRareProtocol.cancelOrderNonces(orderNonces);

        // Prepare the order hash
        OrderStructs.MakerBid memory makerBid = _createSingleItemMakerBidOrder({
            bidNonce: 0,
            subsetNonce: 0,
            strategyId: STANDARD_SALE_FOR_FIXED_PRICE_STRATEGY,
            assetType: ASSET_TYPE_ERC721,
            orderNonce: orderNonce,
            collection: address(mockERC721),
            currency: address(weth),
            signer: makerUser,
            maxPrice: price,
            itemId: itemId
        });

        // Sign order
        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        _doesMakerBidOrderReturnValidationCode(makerBid, signature, USER_ORDER_NONCE_EXECUTED_OR_CANCELLED);

        // Mint asset
        mockERC721.mint(takerUser, itemId);

        // Prepare the taker ask
        OrderStructs.TakerAsk memory takerAsk = OrderStructs.TakerAsk(
            takerUser,
            makerBid.maxPrice,
            new uint256[](0),
            new uint256[](0),
            abi.encode(new uint256[](0), new uint256[](0))
        );

        vm.prank(takerUser);
        vm.expectRevert(NoncesInvalid.selector);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);
    }

    function testCancelNoncesRevertIfEmptyArrays() public {
        uint256[] memory nonces = new uint256[](0);

        vm.expectRevert(LengthsInvalid.selector);
        looksRareProtocol.cancelSubsetNonces(nonces);

        vm.expectRevert(LengthsInvalid.selector);
        looksRareProtocol.cancelOrderNonces(nonces);
    }
}
