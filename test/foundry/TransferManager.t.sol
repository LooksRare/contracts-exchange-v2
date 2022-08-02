// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {RoyaltyFeeRegistry} from "@looksrare/contracts-exchange-v1/contracts/royaltyFeeHelpers/royaltyFeeRegistry.sol";

import {LooksRareProtocol} from "../../contracts/LooksRareProtocol.sol";
import {TransferManager} from "../../contracts/TransferManager.sol";
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";

import {TestHelpers} from "./TestHelpers.sol";
import {MockERC721} from "./utils/MockERC721.sol";

abstract contract TestParameters is TestHelpers {
    address internal _owner = address(42);
}

contract TransferManagerTest is TestParameters {
    address[] public operators;

    MockERC721 public mockERC721;
    TransferManager public transferManager;

    function _setUpUser(address _user) internal {
        vm.deal(_user, 100 ether);
    }

    function setUp() public asPrankedUser(_owner) {
        transferManager = new TransferManager();
        mockERC721 = new MockERC721();
        assertEq(transferManager.owner(), _owner);
    }

    function testTransferSingleItemERC721() public {
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
}
