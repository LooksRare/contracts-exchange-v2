// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";
import {ProtocolBase} from "./ProtocolBase.t.sol";

contract BundleTransactionsTest is ProtocolBase {
    function testTakerAskERC721BundleNoRoyalties() public {
        _setUpUsers();
        // TODO
    }

    function testTakerAskERC721BundleWithRoyaltiesFromRegistry() public {
        _setUpUsers();
        // TODO
    }

    function testTakerAskERC721BundleWithEIP2981Royalties() public {
        _setUpUsers();
        // TODO
    }

    function testTakerBidERC721BundleNoRoyalties() public {
        _setUpUsers();
        uint256 numberItemsInBundle = 5;

        (
            OrderStructs.MakerAsk memory makerAsk,
            OrderStructs.TakerBid memory takerBid
        ) = _createMockMakerAskAndTakerBidWithBundle(address(mockERC721), numberItemsInBundle);

        uint256 price = makerAsk.minPrice;
        uint16 minNetRatio = 10000 - (_standardProtocolFee);

        // Adjust slippage parameters accordingly
        makerAsk.minNetRatio = minNetRatio;
        takerBid.minNetRatio = minNetRatio;

        // Mint the items
        mockERC721.batchMint(makerUser, makerAsk.itemIds);
        bytes memory signature = _signMakerAsk(makerAsk, makerUserPK);

        // Taker user actions
        vm.startPrank(takerUser);
        {
            uint256 gasLeft = gasleft();

            // Execute taker bid transaction
            looksRareProtocol.executeTakerBid{value: price}(
                takerBid,
                makerAsk,
                signature,
                _emptyMerkleRoot,
                _emptyMerkleProof,
                _emptyReferrer
            );
            emit log_named_uint(
                "TakerBid // ERC721 // Bundle (5 items) // Protocol Fee // No Royalties",
                gasLeft - gasleft()
            );
        }
        vm.stopPrank();

        for (uint256 i; i < makerAsk.itemIds.length; i++) {
            // Taker user has received all the assets in the bundle
            assertEq(mockERC721.ownerOf(makerAsk.itemIds[i]), takerUser);
        }
        // Taker bid user pays the whole price
        assertEq(address(takerUser).balance, _initialETHBalanceUser - price);
        // Royalty recipient receives no royalty
        assertEq(address(_royaltyRecipient).balance, _initialETHBalanceRoyaltyRecipient);
        // Owner receives protocol fee
        assertEq(address(_owner).balance, _initialETHBalanceOwner + (_standardProtocolFee * price) / 10000);
        // Maker ask user receives 98% of the whole price (no royalties are paid)
        assertEq(address(makerUser).balance, _initialETHBalanceUser + (price * minNetRatio) / 10000);
        // No leftover in the balance of the contract
        assertEq(address(looksRareProtocol).balance, 0);
        // Verify the nonce is marked as executed
        assertTrue(looksRareProtocol.viewUserOrderNonce(makerUser, makerAsk.orderNonce));
    }

    function testTakerBidERC721BundleWithRoyaltiesFromRegistry() public {
        _setUpUsers();
        uint256 numberItemsInBundle = 5;

        (
            OrderStructs.MakerAsk memory makerAsk,
            OrderStructs.TakerBid memory takerBid
        ) = _createMockMakerAskAndTakerBidWithBundle(address(mockERC721), numberItemsInBundle);

        _setUpRoyalties(address(mockERC721), _standardRoyaltyFee);

        uint256 price = makerAsk.minPrice;
        uint16 minNetRatio = 10000 - (_standardRoyaltyFee + _standardProtocolFee);

        // Adjust slippage parameters accordingly
        makerAsk.minNetRatio = minNetRatio;
        takerBid.minNetRatio = minNetRatio;

        // Mint the items
        mockERC721.batchMint(makerUser, makerAsk.itemIds);
        bytes memory signature = _signMakerAsk(makerAsk, makerUserPK);

        // Taker user actions
        vm.startPrank(takerUser);
        {
            uint256 gasLeft = gasleft();

            // Execute taker bid transaction
            looksRareProtocol.executeTakerBid{value: price}(
                takerBid,
                makerAsk,
                signature,
                _emptyMerkleRoot,
                _emptyMerkleProof,
                _emptyReferrer
            );
            emit log_named_uint(
                "TakerBid // ERC721 // Bundle (5 items) // Protocol Fee // Registry Royalties",
                gasLeft - gasleft()
            );
        }
        vm.stopPrank();

        for (uint256 i; i < makerAsk.itemIds.length; i++) {
            // Taker user has received all the assets in the bundle
            assertEq(mockERC721.ownerOf(makerAsk.itemIds[i]), takerUser);
        }
        // Taker bid user pays the whole price
        assertEq(address(takerUser).balance, _initialETHBalanceUser - price);
        // Royalty recipient receives the royalties
        assertEq(
            address(_royaltyRecipient).balance,
            _initialETHBalanceRoyaltyRecipient + (_standardRoyaltyFee * price) / 10000
        );
        // Owner receives protocol fee
        assertEq(address(_owner).balance, _initialETHBalanceOwner + (price * _standardProtocolFee) / 10000);
        // Maker ask user receives 97% of the whole price
        assertEq(address(makerUser).balance, _initialETHBalanceUser + (price * minNetRatio) / 10000);
        // No leftover in the balance of the contract
        assertEq(address(looksRareProtocol).balance, 0);
        // Verify the nonce is marked as executed
        assertTrue(looksRareProtocol.viewUserOrderNonce(makerUser, makerAsk.orderNonce));
    }

    function testTakerBidERC721BundleWithEIP2981Royalties() public {
        _setUpUsers();
        uint256 numberItemsInBundle = 5;

        (
            OrderStructs.MakerAsk memory makerAsk,
            OrderStructs.TakerBid memory takerBid
        ) = _createMockMakerAskAndTakerBidWithBundle(address(mockERC721WithRoyalties), numberItemsInBundle);

        uint256 price = makerAsk.minPrice;
        uint16 minNetRatio = 10000 - (_standardRoyaltyFee + _standardProtocolFee);

        // Adjust slippage parameters accordingly
        makerAsk.minNetRatio = minNetRatio;
        takerBid.minNetRatio = minNetRatio;

        // Mint the items
        mockERC721WithRoyalties.batchMint(makerUser, makerAsk.itemIds);
        bytes memory signature = _signMakerAsk(makerAsk, makerUserPK);

        // Taker user actions
        vm.startPrank(takerUser);
        {
            uint256 gasLeft = gasleft();

            // Execute taker bid transaction
            looksRareProtocol.executeTakerBid{value: price}(
                takerBid,
                makerAsk,
                signature,
                _emptyMerkleRoot,
                _emptyMerkleProof,
                _emptyReferrer
            );
            emit log_named_uint(
                "TakerBid // ERC721 // Bundle (5 items) // Protocol Fee // EIP2981 Royalties",
                gasLeft - gasleft()
            );
        }
        vm.stopPrank();

        for (uint256 i; i < makerAsk.itemIds.length; i++) {
            // Taker user has received all the assets in the bundle
            assertEq(mockERC721WithRoyalties.ownerOf(makerAsk.itemIds[i]), takerUser);
        }
        // Taker bid user pays the whole price
        assertEq(address(takerUser).balance, _initialETHBalanceUser - price);
        // Royalty recipient receives the royalties
        assertEq(
            address(_royaltyRecipient).balance,
            _initialETHBalanceRoyaltyRecipient + (_standardRoyaltyFee * price) / 10000
        );
        // Owner receives protocol fee
        assertEq(address(_owner).balance, _initialETHBalanceOwner + (price * _standardProtocolFee) / 10000);
        // Maker ask user receives 97% of the whole price
        assertEq(address(makerUser).balance, _initialETHBalanceUser + (price * minNetRatio) / 10000);
        // No leftover in the balance of the contract
        assertEq(address(looksRareProtocol).balance, 0);
        // Verify the nonce is marked as executed
        assertTrue(looksRareProtocol.viewUserOrderNonce(makerUser, makerAsk.orderNonce));
    }
}