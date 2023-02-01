// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// LooksRare unopinionated libraries
import {IOwnableTwoSteps} from "@looksrare/contracts-libs/contracts/interfaces/IOwnableTwoSteps.sol";

// Libraries
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";

// Core contracts
import {LooksRareProtocol} from "../../contracts/LooksRareProtocol.sol";
import {ITransferManager, TransferManager} from "../../contracts/TransferManager.sol";
import {AmountInvalid, AssetTypeInvalid, LengthsInvalid} from "../../contracts/errors/SharedErrors.sol";

// Mocks and other utils
import {MockERC721} from "../mock/MockERC721.sol";
import {MockERC1155} from "../mock/MockERC1155.sol";
import {TestHelpers} from "./utils/TestHelpers.sol";
import {TestParameters} from "./utils/TestParameters.sol";

// Constants
import {ASSET_TYPE_ERC721, ASSET_TYPE_ERC1155} from "../../contracts/constants/NumericConstants.sol";

contract TransferManagerTest is ITransferManager, TestHelpers, TestParameters {
    address[] public operators;
    MockERC721 public mockERC721;
    MockERC1155 public mockERC1155;
    TransferManager public transferManager;

    /**
     * 0. Internal helper functions
     */

    function _grantApprovals(address user) private asPrankedUser(user) {
        mockERC721.setApprovalForAll(address(transferManager), true);
        mockERC1155.setApprovalForAll(address(transferManager), true);
        address[] memory approvedOperators = new address[](1);
        approvedOperators[0] = _transferrer;

        vm.expectEmit({checkTopic1: true, checkTopic2: false, checkTopic3: false, checkData: true});
        emit ApprovalsGranted(user, approvedOperators);
        transferManager.grantApprovals(approvedOperators);
    }

    function _whitelistOperator(address transferrer) private {
        vm.prank(_owner);
        vm.expectEmit({checkTopic1: true, checkTopic2: false, checkTopic3: false, checkData: true});
        emit OperatorWhitelisted(transferrer);
        transferManager.whitelistOperator(transferrer);
    }

    function setUp() public asPrankedUser(_owner) {
        transferManager = new TransferManager(_owner);
        mockERC721 = new MockERC721();
        mockERC1155 = new MockERC1155();
        operators.push(_transferrer);

        vm.deal(_transferrer, 100 ether);
        vm.deal(_sender, 100 ether);
    }

    /**
     * 1. Happy cases
     */

    function testTransferSingleItemERC721() public {
        _whitelistOperator(_transferrer);
        _grantApprovals(_sender);

        uint256 itemId = 500;

        vm.prank(_sender);
        mockERC721.mint(_sender, itemId);

        uint256[] memory itemIds = new uint256[](1);
        itemIds[0] = itemId;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        vm.prank(_transferrer);
        transferManager.transferItemsERC721(address(mockERC721), _sender, _recipient, itemIds, amounts);

        assertEq(mockERC721.ownerOf(itemId), _recipient);
    }

    function testTransferSingleItemERC1155() public {
        _whitelistOperator(_transferrer);
        _grantApprovals(_sender);

        uint256 itemId = 1;
        uint256 amount = 2;

        mockERC1155.mint(_sender, itemId, amount);

        uint256[] memory itemIds = new uint256[](1);
        itemIds[0] = itemId;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        vm.prank(_transferrer);
        transferManager.transferItemsERC1155(address(mockERC1155), _sender, _recipient, itemIds, amounts);

        assertEq(mockERC1155.balanceOf(_recipient, itemId), amount);
    }

    function testTransferBatchItemsSameERC721() public {
        _whitelistOperator(_transferrer);
        _grantApprovals(_sender);

        uint256 tokenId1 = 1;
        uint256 tokenId2 = 2;

        uint256[] memory itemIds = new uint256[](2);
        itemIds[0] = tokenId1;
        itemIds[1] = tokenId2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 1;

        mockERC721.batchMint(_sender, itemIds);

        vm.prank(_transferrer);
        transferManager.transferItemsERC721(address(mockERC721), _sender, _recipient, itemIds, amounts);

        assertEq(mockERC721.ownerOf(tokenId1), _recipient);
        assertEq(mockERC721.ownerOf(tokenId2), _recipient);
    }

    function testTransferBatchItemsSameERC1155() public {
        _whitelistOperator(_transferrer);
        _grantApprovals(_sender);

        uint256 tokenId1 = 1;
        uint256 amount1 = 2;
        uint256 tokenId2 = 2;
        uint256 amount2 = 5;

        mockERC1155.mint(_sender, tokenId1, amount1);
        mockERC1155.mint(_sender, tokenId2, amount2);

        uint256[] memory itemIds = new uint256[](2);
        itemIds[0] = tokenId1;
        itemIds[1] = tokenId2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount1;
        amounts[1] = amount2;

        vm.prank(_transferrer);
        transferManager.transferItemsERC1155(address(mockERC1155), _sender, _recipient, itemIds, amounts);

        assertEq(mockERC1155.balanceOf(_recipient, tokenId1), amount1);
        assertEq(mockERC1155.balanceOf(_recipient, tokenId2), amount2);
    }

    function testTransferBatchItemsAcrossCollectionERC721AndERC1155() public {
        _whitelistOperator(_transferrer);
        _grantApprovals(_sender);

        uint256 tokenIdERC721 = 55;
        uint256 tokenId1ERC1155 = 1;
        uint256 amount1ERC1155 = 2;
        uint256 tokenId2ERC1155 = 2;
        uint256 amount2ERC1155 = 5;

        ITransferManager.BatchTransferItem[] memory items = new ITransferManager.BatchTransferItem[](2);

        {
            mockERC721.mint(_sender, tokenIdERC721);
            mockERC1155.mint(_sender, tokenId1ERC1155, amount1ERC1155);
            mockERC1155.mint(_sender, tokenId2ERC1155, amount2ERC1155);

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

            items[0] = ITransferManager.BatchTransferItem({
                collection: address(mockERC1155),
                assetType: ASSET_TYPE_ERC1155,
                itemIds: tokenIdsERC1155,
                amounts: amountsERC1155
            });
            items[1] = ITransferManager.BatchTransferItem({
                collection: address(mockERC721),
                assetType: ASSET_TYPE_ERC721,
                itemIds: tokenIdsERC721,
                amounts: amountsERC721
            });
        }

        vm.prank(_transferrer);
        transferManager.transferBatchItemsAcrossCollections(items, _sender, _recipient);

        assertEq(mockERC721.ownerOf(tokenIdERC721), _recipient);
        assertEq(mockERC1155.balanceOf(_recipient, tokenId1ERC1155), amount1ERC1155);
        assertEq(mockERC1155.balanceOf(_recipient, tokenId2ERC1155), amount2ERC1155);
    }

    function testTransferBatchItemsAcrossCollectionERC721AndERC1155ByOwner() public asPrankedUser(_sender) {
        mockERC721.setApprovalForAll(address(transferManager), true);
        mockERC1155.setApprovalForAll(address(transferManager), true);

        uint256 tokenIdERC721 = 55;
        uint256 tokenId1ERC1155 = 1;
        uint256 amount1ERC1155 = 2;
        uint256 tokenId2ERC1155 = 2;
        uint256 amount2ERC1155 = 5;

        ITransferManager.BatchTransferItem[] memory items = new ITransferManager.BatchTransferItem[](2);

        {
            mockERC721.mint(_sender, tokenIdERC721);
            mockERC1155.mint(_sender, tokenId1ERC1155, amount1ERC1155);
            mockERC1155.mint(_sender, tokenId2ERC1155, amount2ERC1155);

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

            items[0] = ITransferManager.BatchTransferItem({
                collection: address(mockERC1155),
                assetType: ASSET_TYPE_ERC1155,
                itemIds: tokenIdsERC1155,
                amounts: amountsERC1155
            });
            items[1] = ITransferManager.BatchTransferItem({
                collection: address(mockERC721),
                assetType: ASSET_TYPE_ERC721,
                itemIds: tokenIdsERC721,
                amounts: amountsERC721
            });
        }

        transferManager.transferBatchItemsAcrossCollections(items, _sender, _recipient);

        assertEq(mockERC721.ownerOf(tokenIdERC721), _recipient);
        assertEq(mockERC1155.balanceOf(_recipient, tokenId1ERC1155), amount1ERC1155);
        assertEq(mockERC1155.balanceOf(_recipient, tokenId2ERC1155), amount2ERC1155);
    }

    /**
     * 2. Revertion patterns
     */
    function testTransferItemsERC721AmountIsNotOne(uint256 amount) public {
        vm.assume(amount != 1);

        _whitelistOperator(_transferrer);
        _grantApprovals(_sender);

        uint256 itemId = 500;

        mockERC721.mint(_sender, itemId);

        uint256[] memory itemIds = new uint256[](1);
        itemIds[0] = itemId;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        vm.expectRevert(AmountInvalid.selector);
        vm.prank(_transferrer);
        transferManager.transferItemsERC721(address(mockERC721), _sender, _recipient, itemIds, amounts);
    }

    function testTransferSingleItemERC1155AmountIsZero() public {
        _whitelistOperator(_transferrer);
        _grantApprovals(_sender);

        uint256 itemId = 500;

        mockERC1155.mint(_sender, itemId, 1);

        uint256[] memory itemIds = new uint256[](1);
        itemIds[0] = itemId;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0;

        vm.expectRevert(AmountInvalid.selector);
        vm.prank(_transferrer);
        transferManager.transferItemsERC1155(address(mockERC1155), _sender, _recipient, itemIds, amounts);
    }

    function testTransferMultipleItemsERC1155AmountIsZero() public {
        _whitelistOperator(_transferrer);
        _grantApprovals(_sender);

        uint256 itemIdOne = 500;
        uint256 itemIdTwo = 501;

        mockERC1155.mint(_sender, itemIdOne, 1);
        mockERC1155.mint(_sender, itemIdTwo, 1);

        uint256[] memory itemIds = new uint256[](2);
        itemIds[0] = itemIdOne;
        itemIds[1] = itemIdTwo;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 0;
        amounts[1] = 0;

        vm.expectRevert(AmountInvalid.selector);
        vm.prank(_transferrer);
        transferManager.transferItemsERC1155(address(mockERC1155), _sender, _recipient, itemIds, amounts);
    }

    function testTransferBatchItemsAcrossCollectionZeroLength() public {
        _whitelistOperator(_transferrer);
        _grantApprovals(_sender);

        ITransferManager.BatchTransferItem[] memory items = new ITransferManager.BatchTransferItem[](0);

        vm.expectRevert(LengthsInvalid.selector);
        vm.prank(_transferrer);
        transferManager.transferBatchItemsAcrossCollections(items, _sender, _recipient);
    }

    function testCannotBatchTransferIfERC721AmountIsNotOne(uint256 amount) public {
        vm.assume(amount != 1);

        _whitelistOperator(_transferrer);
        _grantApprovals(_sender);

        ITransferManager.BatchTransferItem[] memory items = new ITransferManager.BatchTransferItem[](1);

        uint256[] memory itemIds = new uint256[](1);
        itemIds[0] = 0;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        items[0] = ITransferManager.BatchTransferItem({
            assetType: ASSET_TYPE_ERC721,
            collection: address(mockERC721),
            itemIds: itemIds,
            amounts: amounts
        });

        vm.expectRevert(AmountInvalid.selector);
        vm.prank(_sender);
        transferManager.transferBatchItemsAcrossCollections(items, _sender, _recipient);
    }

    function testCannotBatchTransferIfERC1155AmountIsZero() public {
        _whitelistOperator(_transferrer);
        _grantApprovals(_sender);

        mockERC1155.mint(_transferrer, 0, 1);

        ITransferManager.BatchTransferItem[] memory items = new ITransferManager.BatchTransferItem[](1);

        uint256[] memory itemIds = new uint256[](1);
        itemIds[0] = 0;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0;

        items[0] = ITransferManager.BatchTransferItem({
            assetType: ASSET_TYPE_ERC1155,
            collection: address(mockERC1155),
            itemIds: itemIds,
            amounts: amounts
        });

        vm.expectRevert(AmountInvalid.selector);
        vm.prank(_sender);
        transferManager.transferBatchItemsAcrossCollections(items, _sender, _recipient);
    }

    function testCannotBatchTransferIfAssetTypeIsNotZeroOrOne() public {
        _whitelistOperator(_transferrer);
        _grantApprovals(_sender);

        ITransferManager.BatchTransferItem[] memory items = new ITransferManager.BatchTransferItem[](1);

        uint256[] memory itemIds = new uint256[](1);
        itemIds[0] = 0;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        items[0] = ITransferManager.BatchTransferItem({
            assetType: 2,
            collection: address(mockERC1155),
            itemIds: itemIds,
            amounts: amounts
        });

        vm.prank(_sender);
        vm.expectRevert(abi.encodeWithSelector(AssetTypeInvalid.selector, 2));

        transferManager.transferBatchItemsAcrossCollections(items, _sender, _recipient);
    }

    function testTransferBatchItemsAcrossCollectionPerCollectionItemIdsLengthZero() public {
        _whitelistOperator(_transferrer);
        _grantApprovals(_sender);

        uint256 tokenIdERC721 = 55;
        uint256 tokenId1ERC1155 = 1;
        uint256 amount1ERC1155 = 2;
        uint256 tokenId2ERC1155 = 2;
        uint256 amount2ERC1155 = 5;

        ITransferManager.BatchTransferItem[] memory items = new ITransferManager.BatchTransferItem[](2);

        {
            mockERC721.mint(_sender, tokenIdERC721);
            mockERC1155.mint(_sender, tokenId1ERC1155, amount1ERC1155);
            mockERC1155.mint(_sender, tokenId2ERC1155, amount2ERC1155);

            uint256[] memory tokenIdsERC1155 = new uint256[](0);

            uint256[] memory amountsERC1155 = new uint256[](0);

            uint256[] memory tokenIdsERC721 = new uint256[](1);
            tokenIdsERC721[0] = tokenIdERC721;

            uint256[] memory amountsERC721 = new uint256[](1);
            amountsERC721[0] = 1;

            items[0] = ITransferManager.BatchTransferItem({
                collection: address(mockERC1155),
                assetType: ASSET_TYPE_ERC1155,
                itemIds: tokenIdsERC1155,
                amounts: amountsERC1155
            });
            items[1] = ITransferManager.BatchTransferItem({
                collection: address(mockERC721),
                assetType: ASSET_TYPE_ERC721,
                itemIds: tokenIdsERC721,
                amounts: amountsERC721
            });
        }

        vm.prank(_transferrer);
        vm.expectRevert(LengthsInvalid.selector);
        transferManager.transferBatchItemsAcrossCollections(items, _sender, _recipient);
    }

    function testCannotTransferERC721IfOperatorApprovalsRevokedByUserOrOperatorRemovedByOwner() public {
        _whitelistOperator(_transferrer);
        _grantApprovals(_sender);

        // 1. User revokes the operator
        vm.prank(_sender);
        vm.expectEmit({checkTopic1: false, checkTopic2: false, checkTopic3: false, checkData: true});
        emit ApprovalsRemoved(_sender, operators);
        transferManager.revokeApprovals(operators);

        uint256 itemId = 500;
        uint256[] memory itemIds = new uint256[](1);
        itemIds[0] = itemId;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        vm.prank(_transferrer);
        vm.expectRevert(ITransferManager.TransferCallerInvalid.selector);
        transferManager.transferItemsERC721(address(mockERC721), _sender, _recipient, itemIds, amounts);

        // 2. Sender grants again approvals but owner removes the operators
        _grantApprovals(_sender);
        vm.prank(_owner);
        vm.expectEmit({checkTopic1: false, checkTopic2: false, checkTopic3: false, checkData: true});
        emit OperatorRemoved(_transferrer);
        transferManager.removeOperator(_transferrer);

        vm.prank(_transferrer);
        vm.expectRevert(ITransferManager.TransferCallerInvalid.selector);
        transferManager.transferItemsERC721(address(mockERC721), _sender, _recipient, itemIds, amounts);
    }

    function testCannotTransferERC1155IfOperatorApprovalsRevokedByUserOrOperatorRemovedByOwner() public {
        _whitelistOperator(_transferrer);
        _grantApprovals(_sender);

        // 1. User revokes the operator
        vm.prank(_sender);
        vm.expectEmit({checkTopic1: false, checkTopic2: false, checkTopic3: false, checkData: true});
        emit ApprovalsRemoved(_sender, operators);
        transferManager.revokeApprovals(operators);

        uint256 itemId = 500;
        uint256[] memory itemIds = new uint256[](1);
        itemIds[0] = itemId;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 5;

        vm.prank(_transferrer);
        vm.expectRevert(ITransferManager.TransferCallerInvalid.selector);
        transferManager.transferItemsERC1155(address(mockERC1155), _sender, _recipient, itemIds, amounts);

        // 2. Sender grants again approvals but owner removes the operators
        _grantApprovals(_sender);
        vm.prank(_owner);
        vm.expectEmit({checkTopic1: false, checkTopic2: false, checkTopic3: false, checkData: true});
        emit OperatorRemoved(_transferrer);
        transferManager.removeOperator(_transferrer);

        vm.prank(_transferrer);
        vm.expectRevert(ITransferManager.TransferCallerInvalid.selector);
        transferManager.transferItemsERC1155(address(mockERC1155), _sender, _recipient, itemIds, amounts);
    }

    function testCannotBatchTransferIfOperatorApprovalsRevoked() public {
        _whitelistOperator(_transferrer);
        _grantApprovals(_sender);

        // 1. User revokes the operator
        vm.prank(_sender);
        vm.expectEmit({checkTopic1: false, checkTopic2: false, checkTopic3: false, checkData: true});
        emit ApprovalsRemoved(_sender, operators);
        transferManager.revokeApprovals(operators);

        ITransferManager.BatchTransferItem[] memory items = new ITransferManager.BatchTransferItem[](2);

        uint256 itemId0 = 500;
        uint256 itemId1 = 500;

        uint256[] memory tokenIdsERC721 = new uint256[](1);
        tokenIdsERC721[0] = itemId0;
        uint256[] memory tokenIdsERC1155 = new uint256[](1);
        tokenIdsERC1155[0] = itemId1;

        uint256[] memory amountsERC721 = new uint256[](1);
        amountsERC721[0] = 1;
        uint256[] memory amountsERC1155 = new uint256[](1);
        amountsERC1155[0] = 2;

        items[0] = ITransferManager.BatchTransferItem({
            collection: address(mockERC721),
            assetType: ASSET_TYPE_ERC721,
            itemIds: tokenIdsERC721,
            amounts: amountsERC721
        });
        items[1] = ITransferManager.BatchTransferItem({
            collection: address(mockERC1155),
            assetType: ASSET_TYPE_ERC1155,
            itemIds: tokenIdsERC1155,
            amounts: amountsERC1155
        });

        vm.prank(_transferrer);
        vm.expectRevert(ITransferManager.TransferCallerInvalid.selector);
        transferManager.transferBatchItemsAcrossCollections(items, _sender, _recipient);

        // 2. Sender grants again approvals but owner removes the operators
        _grantApprovals(_sender);
        vm.prank(_owner);
        vm.expectEmit({checkTopic1: false, checkTopic2: false, checkTopic3: false, checkData: true});
        emit OperatorRemoved(_transferrer);
        transferManager.removeOperator(_transferrer);

        vm.prank(_transferrer);
        vm.expectRevert(ITransferManager.TransferCallerInvalid.selector);
        transferManager.transferBatchItemsAcrossCollections(items, _sender, _recipient);
    }

    function testCannotTransferERC721OrERC1155IfArrayLengthIs0() public {
        uint256[] memory emptyArrayUint256 = new uint256[](0);

        // 1. ERC721
        vm.expectRevert(LengthsInvalid.selector);
        transferManager.transferItemsERC721(
            address(mockERC721),
            _sender,
            _recipient,
            emptyArrayUint256,
            emptyArrayUint256
        );

        // 2. ERC1155 length is 0
        vm.expectRevert(LengthsInvalid.selector);
        transferManager.transferItemsERC1155(
            address(mockERC1155),
            _sender,
            _recipient,
            emptyArrayUint256,
            emptyArrayUint256
        );
    }

    function testCannotTransferERC1155IfArrayLengthDiffers() public {
        uint256[] memory itemIds = new uint256[](2);
        uint256[] memory amounts = new uint256[](3);

        vm.expectRevert(LengthsInvalid.selector);
        transferManager.transferItemsERC1155(address(mockERC1155), _sender, _recipient, itemIds, amounts);
    }

    function testUserCannotGrantOrRevokeApprovalsIfArrayLengthIs0() public {
        address[] memory emptyArrayAddresses = new address[](0);

        // 1. Grant approvals
        vm.expectRevert(LengthsInvalid.selector);
        transferManager.grantApprovals(emptyArrayAddresses);

        // 2. Revoke approvals
        vm.expectRevert(LengthsInvalid.selector);
        transferManager.revokeApprovals(emptyArrayAddresses);
    }

    function testUserCannotGrantApprovalIfOperatorNotWhitelisted() public asPrankedUser(_owner) {
        address randomOperator = address(420);
        transferManager.whitelistOperator(randomOperator);
        vm.expectRevert(ITransferManager.AlreadyWhitelisted.selector);
        transferManager.whitelistOperator(randomOperator);
    }

    function testWhitelistOperatorNotOwner() public {
        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        transferManager.whitelistOperator(address(0));
    }

    function testOwnerCannotWhitelistOperatorIfAlreadyWhitelisted() public asPrankedUser(_owner) {
        address randomOperator = address(420);
        transferManager.whitelistOperator(randomOperator);
        vm.expectRevert(ITransferManager.AlreadyWhitelisted.selector);
        transferManager.whitelistOperator(randomOperator);
    }

    function testOwnerCannotRemoveOperatorIfNotWhitelisted() public asPrankedUser(_owner) {
        address notOperator = address(420);
        vm.expectRevert(ITransferManager.NotWhitelisted.selector);
        transferManager.removeOperator(notOperator);
    }

    function testUserCannotGrantApprovalsIfNotWhitelisted() public {
        address[] memory approvedOperators = new address[](1);
        approvedOperators[0] = _transferrer;

        vm.expectRevert(ITransferManager.NotWhitelisted.selector);
        vm.prank(_sender);
        transferManager.grantApprovals(approvedOperators);
    }

    function testUserCannotGrantApprovalsIfAlreadyApproved() public {
        _whitelistOperator(_transferrer);
        _grantApprovals(_sender);

        address[] memory approvedOperators = new address[](1);
        approvedOperators[0] = _transferrer;

        vm.expectRevert(ITransferManager.AlreadyApproved.selector);
        vm.prank(_sender);
        transferManager.grantApprovals(approvedOperators);
    }

    function testUserCannotRevokeApprovalsIfNotApproved() public {
        address[] memory approvedOperators = new address[](1);
        approvedOperators[0] = _transferrer;

        vm.expectRevert(ITransferManager.NotApproved.selector);
        vm.prank(_sender);
        transferManager.revokeApprovals(approvedOperators);
    }

    function testRemoveOperatorNotOwner() public {
        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        transferManager.removeOperator(address(0));
    }
}
