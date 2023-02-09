// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Test} from "../../lib/forge-std/src/Test.sol";

import {BatchOrderTypehashRegistry} from "../../contracts/BatchOrderTypehashRegistry.sol";

// Shared errors
import {MerkleProofTooLarge} from "../../contracts/errors/SharedErrors.sol";

contract BatchOrderTypehashRegistryTest is Test {
    function testHash() public {
        BatchOrderTypehashRegistry registry = new BatchOrderTypehashRegistry();
        bytes32 root = hex"6942000000000000000000000000000000000000000000000000000000000000";
        assertEq(registry.hash(root, 1), hex"33c657401cb4cc9871013e0f76f5281e0d120ebe79a7df082ef23f819c88a713");
        assertEq(registry.hash(root, 2), hex"f512f08b1484881bfeee2fff62ec8ab82802924cf7d60935f439c51ec4c36137");
        assertEq(registry.hash(root, 3), hex"8526a9764b20d57713475efc2cd5510a66ca8c42cffac8ac53a11b92902f4d2e");
        assertEq(registry.hash(root, 4), hex"10d2d11a4c31f70fe46acd8bb3da553a486eeb19ca16e142a2cfbf5ad44db13c");
        assertEq(registry.hash(root, 5), hex"a0e3c51d5b4c0161ef05090b23f65dc9a0a1eeeb41ca7d8273072bd219971736");
        assertEq(registry.hash(root, 6), hex"0ba773da36db5b6d707566fed81f0467735faa607baa1935879234461aa2a67d");
        assertEq(registry.hash(root, 7), hex"c6ac7b53bdac5ffacb36b16446b2c42b79b5ae7507cdbe8b7003cdcf5a7cd6b4");
        assertEq(registry.hash(root, 8), hex"a1b41ffa9ef16d44f213995f30fbc1b5c7b9f2295422690d1b50adcb5b8ef074");
        assertEq(registry.hash(root, 9), hex"572bca919a81f64902ca93574858cc79353e5cc73cc3b8b0b1c7c65e45df07d6");
        assertEq(registry.hash(root, 10), hex"e7dee9a17322f61bfe28d8937543ad6efa464090d9699b49e84b0ce9a9850fff");
    }

    function testGetTypehash() public {
        BatchOrderTypehashRegistry registry = new BatchOrderTypehashRegistry();
        bytes memory makerOrderString = bytes(
            "Maker("
            "uint8 quoteType,"
            "uint256 globalNonce,"
            "uint256 subsetNonce,"
            "uint256 orderNonce,"
            "uint256 strategyId,"
            "uint8 assetType,"
            "address collection,"
            "address currency,"
            "address signer,"
            "uint256 startTime,"
            "uint256 endTime,"
            "uint256 price,"
            "uint256[] itemIds,"
            "uint256[] amounts,"
            "bytes additionalParameters"
            ")"
        );

        assertEq(
            registry.getTypehash(1),
            keccak256(bytes.concat(bytes("BatchOrder(Maker[2] tree)"), makerOrderString))
        );

        assertEq(
            registry.getTypehash(2),
            keccak256(bytes.concat(bytes("BatchOrder(Maker[2][2] tree)"), makerOrderString))
        );

        assertEq(
            registry.getTypehash(3),
            keccak256(bytes.concat(bytes("BatchOrder(Maker[2][2][2] tree)"), makerOrderString))
        );

        assertEq(
            registry.getTypehash(4),
            keccak256(bytes.concat(bytes("BatchOrder(Maker[2][2][2][2] tree)"), makerOrderString))
        );

        assertEq(
            registry.getTypehash(5),
            keccak256(bytes.concat(bytes("BatchOrder(Maker[2][2][2][2][2] tree)"), makerOrderString))
        );

        assertEq(
            registry.getTypehash(6),
            keccak256(bytes.concat(bytes("BatchOrder(Maker[2][2][2][2][2][2] tree)"), makerOrderString))
        );

        assertEq(
            registry.getTypehash(7),
            keccak256(bytes.concat(bytes("BatchOrder(Maker[2][2][2][2][2][2][2] tree)"), makerOrderString))
        );

        assertEq(
            registry.getTypehash(8),
            keccak256(bytes.concat(bytes("BatchOrder(Maker[2][2][2][2][2][2][2][2] tree)"), makerOrderString))
        );

        assertEq(
            registry.getTypehash(9),
            keccak256(bytes.concat(bytes("BatchOrder(Maker[2][2][2][2][2][2][2][2][2] tree)"), makerOrderString))
        );

        assertEq(
            registry.getTypehash(10),
            keccak256(bytes.concat(bytes("BatchOrder(Maker[2][2][2][2][2][2][2][2][2][2] tree)"), makerOrderString))
        );
    }

    function testGetTypehashMerkleProofTooLarge(uint256 height) public {
        vm.assume(height > 10);

        BatchOrderTypehashRegistry registry = new BatchOrderTypehashRegistry();
        vm.expectRevert(abi.encodeWithSelector(MerkleProofTooLarge.selector, height));
        registry.getTypehash(height);
    }
}
