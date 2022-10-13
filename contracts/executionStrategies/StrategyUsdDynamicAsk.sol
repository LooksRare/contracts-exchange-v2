// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {OwnableTwoSteps} from "@looksrare/contracts-libs/contracts/OwnableTwoSteps.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {IExecutionStrategy} from "../interfaces/IExecutionStrategy.sol";
import {OrderStructs} from "../libraries/OrderStructs.sol";

/**
 * @title StrategyUsdDynamicAsk
 * @author LooksRare protocol team (👀,💎)
 */
contract StrategyUsdDynamicAsk is IExecutionStrategy, OwnableTwoSteps {
    // Address of the protocol
    address public immutable LOOKSRARE_PROTOCOL;
    mapping(address => address) public oracles;

    /**
     * @notice Emitted when a Chainlink floor price oracle is added.
     * @param collection NFT collection address
     * @param oracle Floor price oracle address
     */
    event OracleUpdated(address collection, address oracle);

    /**
     * @notice Constructor
     * @param _looksRareProtocol Address of the LooksRare protocol
     */
    constructor(address _looksRareProtocol) {
        LOOKSRARE_PROTOCOL = _looksRareProtocol;
    }

    /**
     * @inheritdoc IExecutionStrategy
     */
    function executeStrategyWithTakerBid(OrderStructs.TakerBid calldata, OrderStructs.MakerAsk calldata)
        external
        pure
        override
        returns (
            uint256 price,
            uint256[] memory itemIds,
            uint256[] memory amounts,
            bool isNonceInvalidated
        )
    {}

    /**
     * @inheritdoc IExecutionStrategy
     */
    function executeStrategyWithTakerAsk(
        OrderStructs.TakerAsk calldata takerAsk,
        OrderStructs.MakerBid calldata makerBid
    )
        external
        view
        override
        returns (
            uint256 price,
            uint256[] memory itemIds,
            uint256[] memory amounts,
            bool isNonceInvalidated
        )
    {
        // if (msg.sender != LOOKSRARE_PROTOCOL) revert WrongCaller();
    }

    /**
     * @notice Set or unset an NFT collection's oracle address
     * @dev Function only callable by contract owner
     * @param _collection NFT collection address
     * @param _oracle Floor price oracle address
     */
    function setOracle(address _collection, address _oracle) external onlyOwner {
        oracles[_collection] = _oracle;
        emit OracleUpdated(_collection, _oracle);
    }

    /**
     * @notice View an NFT collection's oracle address
     * @param collection NFT collection address
     */
    function oracle(address collection) external view returns (address) {
        return oracles[collection];
    }
}
