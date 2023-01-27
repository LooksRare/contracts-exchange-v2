// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// LooksRare unopinionated libraries
import {IERC721} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC721.sol";
import {IERC1155} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC1155.sol";

// Libraries and interfaces
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";

// Base test
import {ProtocolBase} from "./ProtocolBase.t.sol";

// Constants
import {ASSET_TYPE_ERC721, ASSET_TYPE_ERC1155} from "../../contracts/constants/NumericConstants.sol";

contract SandboxTest is ProtocolBase {
    error ERC721TransferFromFail();

    // Fixed price of sale
    uint256 private constant price = 1 ether;

    // Sandbox on Ethereum mainnet
    address private constant SANDBOX = 0xa342f5D851E866E18ff98F351f2c6637f4478dB5;

    // Forked block number to run the tests
    uint256 private constant FORKED_BLOCK_NUMBER = 16268000;

    function _transferItemIdToUser(address user) private returns (uint256 itemId) {
        // @dev This user had 23 of the itemId at the forked block number
        address ownerOfItemId = 0x7A9fe22691c811ea339D9B73150e6911a5343DcA;
        itemId = 55464657044963196816950587289035428064568320970692304673817341489688428423171;
        vm.prank(ownerOfItemId);
        IERC1155(SANDBOX).safeTransferFrom(ownerOfItemId, user, itemId, 23, "");
    }

    function _setUpApprovalsForSandbox(address user) internal {
        vm.prank(user);
        IERC1155(SANDBOX).setApprovalForAll(address(transferManager), true);
    }

    function setUp() public override {
        vm.createSelectFork(vm.rpcUrl("mainnet"), FORKED_BLOCK_NUMBER);
        super.setUp();
        _setUpUsers();
    }

    /**
     * @notice Sandbox implements both ERC721 and ERC1155 interfaceIds.
     *         This test verifies that only assetType = 1 works.
     *         It is for taker ask (matching maker bid).
     */
    function testTakerAskCannotTransferSandboxWithERC721AssetTypeButERC1155AssetTypeWorks() public {
        // Taker user is the one selling the item
        _setUpApprovalsForSandbox(takerUser);
        uint256 itemId = _transferItemIdToUser(takerUser);

        // Prepare the order hash
        OrderStructs.MakerBid memory makerBid = _createSingleItemMakerBidOrder({
            bidNonce: 0,
            subsetNonce: 0,
            strategyId: STANDARD_SALE_FOR_FIXED_PRICE_STRATEGY,
            assetType: ASSET_TYPE_ERC721, // it should be ERC1155
            orderNonce: 0,
            collection: SANDBOX,
            currency: address(weth),
            signer: makerUser,
            maxPrice: price,
            itemId: itemId
        });

        // Sign order
        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        // Prepare the taker ask
        OrderStructs.TakerAsk memory takerAsk = OrderStructs.TakerAsk(takerUser, abi.encode());

        // It should fail with assetType = 0
        vm.expectRevert(abi.encodeWithSelector(ERC721TransferFromFail.selector));
        vm.prank(takerUser);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);

        // Adjust asset type and sign order again
        makerBid.assetType = ASSET_TYPE_ERC1155;
        signature = _signMakerBid(makerBid, makerUserPK);

        // It shouldn't fail with assetType = 0
        vm.prank(takerUser);
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _EMPTY_MERKLE_TREE, _EMPTY_AFFILIATE);

        // Maker user has received the Sandbox asset
        assertEq(IERC1155(SANDBOX).balanceOf(makerUser, itemId), makerBid.amounts[0]);
    }

    /**
     * @notice Sandbox implements both ERC721 and ERC1155 interfaceIds.
     *         This test verifies that only assetType = 1 works.
     *         It is for taker bid (matching maker ask).
     */
    function testTakerBidCannotTransferSandboxWithERC721AssetTypeButERC1155AssetTypeWorks() public {
        // Maker user is the one selling the item
        _setUpApprovalsForSandbox(makerUser);
        uint256 itemId = _transferItemIdToUser(makerUser);

        // Prepare the order hash
        OrderStructs.MakerAsk memory makerAsk = _createSingleItemMakerAskOrder({
            askNonce: 0,
            subsetNonce: 0,
            strategyId: STANDARD_SALE_FOR_FIXED_PRICE_STRATEGY,
            assetType: ASSET_TYPE_ERC721, // it should be ERC1155
            orderNonce: 0,
            collection: SANDBOX,
            currency: ETH,
            signer: makerUser,
            minPrice: price,
            itemId: itemId
        });

        // Sign order
        bytes memory signature = _signMakerAsk(makerAsk, makerUserPK);

        // Prepare the taker bid
        OrderStructs.TakerBid memory takerBid = OrderStructs.TakerBid(takerUser, makerAsk.minPrice, abi.encode());

        // It should fail with assetType = 0
        vm.expectRevert(abi.encodeWithSelector(ERC721TransferFromFail.selector));
        vm.prank(takerUser);
        looksRareProtocol.executeTakerBid{value: price}(
            takerBid,
            makerAsk,
            signature,
            _EMPTY_MERKLE_TREE,
            _EMPTY_AFFILIATE
        );

        // Adjust asset type and sign order again
        makerAsk.assetType = ASSET_TYPE_ERC1155;
        signature = _signMakerAsk(makerAsk, makerUserPK);

        // It shouldn't fail with assetType = 0
        vm.prank(takerUser);
        looksRareProtocol.executeTakerBid{value: price}(
            takerBid,
            makerAsk,
            signature,
            _EMPTY_MERKLE_TREE,
            _EMPTY_AFFILIATE
        );

        // Taker user has received the Sandbox asset
        assertEq(IERC1155(SANDBOX).balanceOf(takerUser, itemId), makerAsk.amounts[0]);
    }
}
