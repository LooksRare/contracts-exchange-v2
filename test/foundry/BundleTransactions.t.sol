// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";
import {ProtocolBase} from "./ProtocolBase.t.sol";

contract BundleTransactionsTest is ProtocolBase {
    function testTakerAskERC721BundleNoRoyalties() public {
        _setUpUsers();
        uint256 numberItemsInBundle = 5;

        (makerBid, takerAsk) = _createMockMakerBidAndTakerAskWithBundle(
            address(mockERC721),
            address(weth),
            numberItemsInBundle
        );

        price = makerBid.maxPrice;
        uint16 minNetRatio = 10000 - _standardProtocolFee;

        // Sign the order
        signature = _signMakerBid(makerBid, makerUserPK);

        // Taker user actions
        vm.startPrank(takerUser);
        {
            // Mint the items
            mockERC721.batchMint(takerUser, makerBid.itemIds);

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
                "TakerAsk // ERC721 // Bundle (5 items) // Protocol Fee // No Royalties",
                gasLeft - gasleft()
            );
        }
        vm.stopPrank();

        for (uint256 i; i < makerBid.itemIds.length; i++) {
            // Maker user has received all the assets in the bundle
            assertEq(mockERC721.ownerOf(makerBid.itemIds[i]), makerUser);
        }
        // Maker bid user pays the whole price
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser - price);
        // Royalty recipient receives no royalty
        assertEq(weth.balanceOf(_royaltyRecipient), _initialWETHBalanceRoyaltyRecipient);
        // Owner receives protocol fee
        assertEq(weth.balanceOf(_owner), _initialWETHBalanceOwner + (price * _standardProtocolFee) / 10000);
        // Taker ask user receives 98% of the whole price (no royalties are paid)
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser + (price * minNetRatio) / 10000);
        // Verify the nonce is marked as executed
        assertTrue(looksRareProtocol.userOrderNonce(makerUser, makerBid.orderNonce));
    }

    function testTakerAskERC721BundleWithRoyaltiesFromRegistry() public {
        _setUpUsers();
        // TODO: Royalty/Rebate adjustment
        uint256 numberItemsInBundle = 5;

        (makerBid, takerAsk) = _createMockMakerBidAndTakerAskWithBundle(
            address(mockERC721),
            address(weth),
            numberItemsInBundle
        );

        price = makerBid.maxPrice;
        uint16 minNetRatio = 10000 - (_standardProtocolFee + _standardRoyaltyFee);

        // Sign the order
        signature = _signMakerBid(makerBid, makerUserPK);

        // Taker user actions
        vm.startPrank(takerUser);
        {
            // Mint the items
            mockERC721.batchMint(takerUser, makerBid.itemIds);

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
                "TakerAsk // ERC721 // Bundle (5 items) // Protocol Fee // Registry Royalties",
                gasLeft - gasleft()
            );
        }
        vm.stopPrank();

        for (uint256 i; i < makerBid.itemIds.length; i++) {
            // Maker user has received all the assets in the bundle
            assertEq(mockERC721.ownerOf(makerBid.itemIds[i]), makerUser);
        }
        // Maker bid user pays the whole price
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser - price);
        // Royalty recipient receives royalties
        assertEq(
            weth.balanceOf(_royaltyRecipient),
            _initialWETHBalanceRoyaltyRecipient + (price * _standardRoyaltyFee) / 10000
        );
        // Owner receives protocol fee
        assertEq(weth.balanceOf(_owner), _initialWETHBalanceOwner + (price * _standardProtocolFee) / 10000);
        // Taker ask user receives 97% of the whole price (royalties are paid)
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser + (price * minNetRatio) / 10000);
        // Verify the nonce is marked as executed
        assertTrue(looksRareProtocol.userOrderNonce(makerUser, makerBid.orderNonce));
    }

    function testTakerAskERC721BundleWithEIP2981Royalties() public {
        _setUpUsers();
        uint256 numberItemsInBundle = 5;

        (makerBid, takerAsk) = _createMockMakerBidAndTakerAskWithBundle(
            address(mockERC721WithRoyalties),
            address(weth),
            numberItemsInBundle
        );

        price = makerBid.maxPrice;
        uint16 minNetRatio = 10000 - (_standardProtocolFee + _standardRoyaltyFee);

        // Sign the order
        signature = _signMakerBid(makerBid, makerUserPK);

        // Taker user actions
        vm.startPrank(takerUser);
        {
            // Mint the items
            mockERC721WithRoyalties.batchMint(takerUser, makerBid.itemIds);

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
                "TakerAsk // ERC721 // Bundle (5 items) // Protocol Fee // Registry Royalties",
                gasLeft - gasleft()
            );
        }
        vm.stopPrank();

        for (uint256 i; i < makerBid.itemIds.length; i++) {
            // Maker user has received all the assets in the bundle
            assertEq(mockERC721WithRoyalties.ownerOf(makerBid.itemIds[i]), makerUser);
        }
        // Maker bid user pays the whole price
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser - price);
        // Royalty recipient receives royalties
        assertEq(
            weth.balanceOf(_royaltyRecipient),
            _initialWETHBalanceRoyaltyRecipient + (price * _standardRoyaltyFee) / 10000
        );
        // Owner receives protocol fee
        assertEq(weth.balanceOf(_owner), _initialWETHBalanceOwner + (price * _standardProtocolFee) / 10000);
        // Taker ask user receives 97% of the whole price (royalties are paid)
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser + (price * minNetRatio) / 10000);
        // Verify the nonce is marked as executed
        assertTrue(looksRareProtocol.userOrderNonce(makerUser, makerBid.orderNonce));
    }

    function testTakerBidERC721BundleNoRoyalties() public {
        _setUpUsers();
        uint256 numberItemsInBundle = 5;

        (makerAsk, takerBid) = _createMockMakerAskAndTakerBidWithBundle(address(mockERC721), numberItemsInBundle);

        price = makerAsk.minPrice;
        uint16 minNetRatio = 10000 - _standardProtocolFee;

        // Mint the items and sign the order
        mockERC721.batchMint(makerUser, makerAsk.itemIds);
        signature = _signMakerAsk(makerAsk, makerUserPK);

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
                _emptyAffiliate
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
        assertEq(address(_owner).balance, _initialETHBalanceOwner + (price * _standardProtocolFee) / 10000);
        // Maker ask user receives 98% of the whole price (no royalties are paid)
        assertEq(address(makerUser).balance, _initialETHBalanceUser + (price * minNetRatio) / 10000);
        // No leftover in the balance of the contract
        assertEq(address(looksRareProtocol).balance, 0);
        // Verify the nonce is marked as executed
        assertTrue(looksRareProtocol.userOrderNonce(makerUser, makerAsk.orderNonce));
    }

    function testTakerBidERC721BundleWithRoyaltiesFromRegistry() public {
        _setUpUsers();
        // TODO: Royalty/Rebate adjustment
        uint256 numberItemsInBundle = 5;

        (makerAsk, takerBid) = _createMockMakerAskAndTakerBidWithBundle(address(mockERC721), numberItemsInBundle);

        price = makerAsk.minPrice;
        uint16 minNetRatio = 10000 - (_standardRoyaltyFee + _standardProtocolFee);

        // Mint the items and sign the order
        mockERC721.batchMint(makerUser, makerAsk.itemIds);
        signature = _signMakerAsk(makerAsk, makerUserPK);

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
                _emptyAffiliate
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
            _initialETHBalanceRoyaltyRecipient + (price * _standardRoyaltyFee) / 10000
        );
        // Owner receives protocol fee
        assertEq(address(_owner).balance, _initialETHBalanceOwner + (price * _standardProtocolFee) / 10000);
        // Maker ask user receives 97% of the whole price
        assertEq(address(makerUser).balance, _initialETHBalanceUser + (price * minNetRatio) / 10000);
        // No leftover in the balance of the contract
        assertEq(address(looksRareProtocol).balance, 0);
        // Verify the nonce is marked as executed
        assertTrue(looksRareProtocol.userOrderNonce(makerUser, makerAsk.orderNonce));
    }

    function testTakerBidERC721BundleWithEIP2981Royalties() public {
        _setUpUsers();
        uint256 numberItemsInBundle = 5;

        (makerAsk, takerBid) = _createMockMakerAskAndTakerBidWithBundle(
            address(mockERC721WithRoyalties),
            numberItemsInBundle
        );

        price = makerAsk.minPrice;
        uint16 minNetRatio = 10000 - (_standardRoyaltyFee + _standardProtocolFee);

        // Mint the items and sign the order
        mockERC721WithRoyalties.batchMint(makerUser, makerAsk.itemIds);
        signature = _signMakerAsk(makerAsk, makerUserPK);

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
                _emptyAffiliate
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
            _initialETHBalanceRoyaltyRecipient + (price * _standardRoyaltyFee) / 10000
        );
        // Owner receives protocol fee
        assertEq(address(_owner).balance, _initialETHBalanceOwner + (price * _standardProtocolFee) / 10000);
        // Maker ask user receives 97% of the whole price
        assertEq(address(makerUser).balance, _initialETHBalanceUser + (price * minNetRatio) / 10000);
        // No leftover in the balance of the contract
        assertEq(address(looksRareProtocol).balance, 0);
        // Verify the nonce is marked as executed
        assertTrue(looksRareProtocol.userOrderNonce(makerUser, makerAsk.orderNonce));
    }
}
