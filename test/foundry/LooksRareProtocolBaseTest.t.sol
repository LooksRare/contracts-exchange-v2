// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {RoyaltyFeeRegistry} from "@looksrare/contracts-exchange-v1/contracts/royaltyFeeHelpers/RoyaltyFeeRegistry.sol";
import {WETH} from "@rari-capital/solmate/src/tokens/WETH.sol";
import {LooksRareProtocol, ILooksRareProtocol} from "../../contracts/LooksRareProtocol.sol";
import {TransferManager} from "../../contracts/TransferManager.sol";

import {MockERC721} from "../mock/MockERC721.sol";
import {MockERC721WithRoyalties} from "../mock/MockERC721WithRoyalties.sol";
import {MockERC1155} from "../mock/MockERC1155.sol";
import {MockOrderGenerator} from "./utils/MockOrderGenerator.sol";
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";

contract LooksRareProtocolBaseTest is MockOrderGenerator, ILooksRareProtocol {
    address[] public operators;
    MockERC721WithRoyalties public mockERC721WithRoyalties;
    MockERC721 public mockERC721;
    MockERC1155 public mockERC1155;

    RoyaltyFeeRegistry public royaltyFeeRegistry;
    LooksRareProtocol public looksRareProtocol;
    TransferManager public transferManager;
    WETH public weth;

    function _setUpUser(address user) internal asPrankedUser(user) {
        vm.deal(user, 100 ether);
        mockERC721.setApprovalForAll(address(transferManager), true);
        mockERC1155.setApprovalForAll(address(transferManager), true);
        mockERC721WithRoyalties.setApprovalForAll(address(transferManager), true);
        transferManager.grantApprovals(operators);
        weth.approve(address(looksRareProtocol), type(uint256).max);
        weth.deposit{value: 10 ether}();
    }

    function _setUpRoyalties(address collection, uint16 royaltyFee) internal {
        vm.startPrank(royaltyFeeRegistry.owner());
        royaltyFeeRegistry.updateRoyaltyInfoForCollection(collection, _collectionOwner, _collectionOwner, royaltyFee);
        vm.stopPrank();
    }

    function _setUpUsers() internal {
        _setUpUser(makerUser);
        _setUpUser(takerUser);
    }

    function setUp() public {
        vm.startPrank(_owner);
        weth = new WETH();
        royaltyFeeRegistry = new RoyaltyFeeRegistry(9500);
        transferManager = new TransferManager();
        looksRareProtocol = new LooksRareProtocol(address(transferManager), address(royaltyFeeRegistry));
        mockERC721 = new MockERC721();
        mockERC1155 = new MockERC1155();
        mockERC721WithRoyalties = new MockERC721WithRoyalties(_collectionOwner, _standardRoyaltyFee);

        // Operations
        transferManager.whitelistOperator(address(looksRareProtocol));
        looksRareProtocol.addCurrency(address(0));
        looksRareProtocol.addCurrency(address(weth));
        looksRareProtocol.setProtocolFeeRecipient(_owner);

        // Fetch domain separator and store it as one of the operators
        (_domainSeparator, , , ) = looksRareProtocol.information();
        operators.push(address(looksRareProtocol));

        // Distribute ETH and WETH to protocol owner
        vm.deal(_owner, 100 ether);
        weth.deposit{value: 10 ether}();
        vm.stopPrank();

        // Distribute ETH and WETH to collection owner
        vm.deal(_collectionOwner, 100 ether);
        vm.startPrank(_collectionOwner);
        weth.deposit{value: 10 ether}();
        vm.stopPrank();
    }
}
