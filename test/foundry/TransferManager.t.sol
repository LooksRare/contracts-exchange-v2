// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {RoyaltyFeeRegistry} from "@looksrare/contracts-exchange-v1/contracts/royaltyFeeHelpers/RoyaltyFeeRegistry.sol";

import {LooksRareProtocol} from "../../contracts/LooksRareProtocol.sol";
import {TransferManager} from "../../contracts/TransferManager.sol";
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";

import {TestHelpers} from "./TestHelpers.sol";
import {MockERC721} from "./utils/MockERC721.sol";
import {MockERC1155} from "./utils/MockERC1155.sol";

abstract contract TestParameters is TestHelpers {
    address internal _owner = address(42);
}

contract TransferManagerTest is TestParameters {
    address[] public operators;
    MockERC721 public mockERC721;
    MockERC1155 public mockERC1155;
    TransferManager public transferManager;

    function _setUpUser(address _user) internal {
        vm.deal(_user, 100 ether);
    }

    function setUp() public asPrankedUser(_owner) {
        transferManager = new TransferManager();
        mockERC721 = new MockERC721();
        mockERC1155 = new MockERC1155();

        assertEq(transferManager.owner(), _owner);
    }

    function testTransferSingleItemERC721() public {
        // Initial set up
        address sender = address(88);
        address recipient = address(90);
        address transferrer = address(100);
        uint256 tokenId = 500;
        _setUpUser(transferrer);
        _setUpUser(sender);

        vm.startPrank(_owner);
        transferManager.whitelistOperator(transferrer);
        vm.stopPrank();

        vm.startPrank(sender);
        mockERC721.setApprovalForAll(address(transferManager), true);
        address[] memory approvedOperators = new address[](1);
        approvedOperators[0] = transferrer;
        transferManager.grantApprovals(approvedOperators);
        mockERC721.mint(sender, tokenId);
        vm.stopPrank();

        vm.startPrank(transferrer);
        transferManager.transferSingleItem(address(mockERC721), 0, sender, recipient, tokenId, 1);
        vm.stopPrank();

        assertEq(mockERC721.ownerOf(tokenId), recipient);
    }

    function testTransferSingleItemERC1155() public {
        // Initial set up
        address sender = address(88);
        address recipient = address(90);
        address transferrer = address(100);
        uint256 tokenId = 1;
        uint256 amount = 2;
        _setUpUser(transferrer);
        _setUpUser(sender);

        vm.startPrank(_owner);
        transferManager.whitelistOperator(transferrer);
        vm.stopPrank();

        vm.startPrank(sender);
        mockERC1155.setApprovalForAll(address(transferManager), true);
        address[] memory approvedOperators = new address[](1);
        approvedOperators[0] = transferrer;
        transferManager.grantApprovals(approvedOperators);
        mockERC1155.mint(sender, tokenId, amount);
        vm.stopPrank();

        vm.startPrank(transferrer);
        transferManager.transferSingleItem(address(mockERC1155), 1, sender, recipient, tokenId, amount);
        vm.stopPrank();

        assertEq(mockERC1155.balanceOf(recipient, tokenId), amount);
    }

    function testTransferBatchItemsSameERC721() public {
        // Initial set up
        address sender = address(88);
        address recipient = address(90);
        address transferrer = address(100);
        uint256 tokenId1 = 1;
        uint256 tokenId2 = 2;
        _setUpUser(transferrer);
        _setUpUser(sender);

        vm.startPrank(_owner);
        transferManager.whitelistOperator(transferrer);
        vm.stopPrank();

        vm.startPrank(sender);
        mockERC721.setApprovalForAll(address(transferManager), true);
        address[] memory approvedOperators = new address[](1);
        approvedOperators[0] = transferrer;
        transferManager.grantApprovals(approvedOperators);
        mockERC721.mint(sender, tokenId1);
        mockERC721.mint(sender, tokenId2);
        vm.stopPrank();

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = tokenId1;
        tokenIds[1] = tokenId2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 1;

        vm.startPrank(transferrer);
        transferManager.transferBatchItems(address(mockERC721), 0, sender, recipient, tokenIds, amounts);
        vm.stopPrank();

        assertEq(mockERC721.ownerOf(tokenId1), recipient);
        assertEq(mockERC721.ownerOf(tokenId2), recipient);
    }

    function testTransferBatchItemsSameERC1155() public {
        // Initial set up
        address sender = address(88);
        address recipient = address(90);
        address transferrer = address(100);
        uint256 tokenId1 = 1;
        uint256 amount1 = 2;
        uint256 tokenId2 = 2;
        uint256 amount2 = 5;
        _setUpUser(transferrer);
        _setUpUser(sender);

        vm.startPrank(_owner);
        transferManager.whitelistOperator(transferrer);
        vm.stopPrank();

        vm.startPrank(sender);
        mockERC1155.setApprovalForAll(address(transferManager), true);
        address[] memory approvedOperators = new address[](1);
        approvedOperators[0] = transferrer;
        transferManager.grantApprovals(approvedOperators);
        mockERC1155.mint(sender, tokenId1, amount1);
        mockERC1155.mint(sender, tokenId2, amount2);
        vm.stopPrank();

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = tokenId1;
        tokenIds[1] = tokenId2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount1;
        amounts[1] = amount2;

        vm.startPrank(transferrer);
        transferManager.transferBatchItems(address(mockERC1155), 1, sender, recipient, tokenIds, amounts);
        vm.stopPrank();

        assertEq(mockERC1155.balanceOf(recipient, tokenId1), amount1);
        assertEq(mockERC1155.balanceOf(recipient, tokenId2), amount2);
    }

    function testTransferBatchItemsAcrossCollectionERC721AndERC1155() public {
        // Initial set up
        address sender = address(88);
        address recipient = address(90);
        address transferrer = address(100);
        uint256 tokenIdERC721 = 55;
        uint256 tokenId1ERC1155 = 1;
        uint256 amount1ERC1155 = 2;
        uint256 tokenId2ERC1155 = 2;
        uint256 amount2ERC1155 = 5;
        _setUpUser(transferrer);
        _setUpUser(sender);

        vm.startPrank(_owner);
        transferManager.whitelistOperator(transferrer);
        vm.stopPrank();

        vm.startPrank(sender);
        mockERC721.setApprovalForAll(address(transferManager), true);
        mockERC1155.setApprovalForAll(address(transferManager), true);

        {
            address[] memory approvedOperators = new address[](1);
            approvedOperators[0] = transferrer;
            transferManager.grantApprovals(approvedOperators);
        }

        address[] memory collections = new address[](2);
        uint8[] memory assetTypes = new uint8[](2);
        uint256[][] memory amounts = new uint256[][](2);
        uint256[][] memory itemIds = new uint256[][](2);

        {
            mockERC721.mint(sender, tokenIdERC721);
            mockERC1155.mint(sender, tokenId1ERC1155, amount1ERC1155);
            mockERC1155.mint(sender, tokenId2ERC1155, amount2ERC1155);

            collections[0] = address(mockERC1155);
            collections[1] = address(mockERC721);

            assetTypes[0] = 1; // ERC1155
            assetTypes[1] = 0; // ERC721

            uint256[] memory tokenIdsERC1155 = new uint256[](2);
            tokenIdsERC1155[0] = tokenId1ERC1155;
            tokenIdsERC1155[1] = tokenId2ERC1155;

            uint256[] memory amountsERC1155 = new uint256[](2);
            amountsERC1155[0] = amount1ERC1155;
            amountsERC1155[1] = amount2ERC1155;

            uint256[] memory tokenIdsERC721 = new uint256[](1);
            tokenIdsERC721[0] = tokenIdERC721;

            uint256[] memory amountsERC721 = new uint256[](1);
            amountsERC721[0] = 1;

            amounts[0] = amountsERC1155;
            amounts[1] = amountsERC721;
            itemIds[0] = tokenIdsERC1155;
            itemIds[1] = tokenIdsERC721;
        }

        vm.stopPrank();

        vm.startPrank(transferrer);
        transferManager.transferBatchItemsAcrossCollections(
            collections,
            assetTypes,
            sender,
            recipient,
            itemIds,
            amounts
        );
        vm.stopPrank();

        assertEq(mockERC721.ownerOf(tokenIdERC721), recipient);
        assertEq(mockERC1155.balanceOf(recipient, tokenId1ERC1155), amount1ERC1155);
        assertEq(mockERC1155.balanceOf(recipient, tokenId2ERC1155), amount2ERC1155);
    }

    function testTransferBatchItemsSameERC721ByOwner() public {
        // Initial set up
        address sender = address(88);
        address recipient = address(90);
        uint256 tokenId1 = 1;
        uint256 tokenId2 = 2;
        _setUpUser(sender);

        vm.startPrank(sender);
        mockERC721.setApprovalForAll(address(transferManager), true);
        mockERC721.mint(sender, tokenId1);
        mockERC721.mint(sender, tokenId2);

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = tokenId1;
        tokenIds[1] = tokenId2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 1;

        transferManager.transferBatchItems(address(mockERC721), 0, sender, recipient, tokenIds, amounts);
        vm.stopPrank();

        assertEq(mockERC721.ownerOf(tokenId1), recipient);
        assertEq(mockERC721.ownerOf(tokenId2), recipient);
    }

    function testTransferBatchItemsAcrossCollectionERC721AndERC1155ByOwner() public {
        // Initial set up
        address sender = address(88);
        address recipient = address(90);
        uint256 tokenIdERC721 = 55;
        uint256 tokenId1ERC1155 = 1;
        uint256 amount1ERC1155 = 2;
        uint256 tokenId2ERC1155 = 2;
        uint256 amount2ERC1155 = 5;
        _setUpUser(sender);

        vm.startPrank(sender);
        mockERC721.setApprovalForAll(address(transferManager), true);
        mockERC1155.setApprovalForAll(address(transferManager), true);

        address[] memory collections = new address[](2);
        uint8[] memory assetTypes = new uint8[](2);
        uint256[][] memory amounts = new uint256[][](2);
        uint256[][] memory itemIds = new uint256[][](2);

        {
            mockERC721.mint(sender, tokenIdERC721);
            mockERC1155.mint(sender, tokenId1ERC1155, amount1ERC1155);
            mockERC1155.mint(sender, tokenId2ERC1155, amount2ERC1155);

            collections[0] = address(mockERC1155);
            collections[1] = address(mockERC721);

            assetTypes[0] = 1; // ERC1155
            assetTypes[1] = 0; // ERC721

            uint256[] memory tokenIdsERC1155 = new uint256[](2);
            tokenIdsERC1155[0] = tokenId1ERC1155;
            tokenIdsERC1155[1] = tokenId2ERC1155;

            uint256[] memory amountsERC1155 = new uint256[](2);
            amountsERC1155[0] = amount1ERC1155;
            amountsERC1155[1] = amount2ERC1155;

            uint256[] memory tokenIdsERC721 = new uint256[](1);
            tokenIdsERC721[0] = tokenIdERC721;

            uint256[] memory amountsERC721 = new uint256[](1);
            amountsERC721[0] = 1;

            amounts[0] = amountsERC1155;
            amounts[1] = amountsERC721;
            itemIds[0] = tokenIdsERC1155;
            itemIds[1] = tokenIdsERC721;
        }

        transferManager.transferBatchItemsAcrossCollections(
            collections,
            assetTypes,
            sender,
            recipient,
            itemIds,
            amounts
        );
        vm.stopPrank();

        assertEq(mockERC721.ownerOf(tokenIdERC721), recipient);
        assertEq(mockERC1155.balanceOf(recipient, tokenId1ERC1155), amount1ERC1155);
        assertEq(mockERC1155.balanceOf(recipient, tokenId2ERC1155), amount2ERC1155);
    }
}
