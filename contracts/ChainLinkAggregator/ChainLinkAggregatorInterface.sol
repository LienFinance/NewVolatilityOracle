// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

// https://github.com/smartcontractkit/chainlink/blob/feature/whitelisted-interface/evm-contracts/src/v0.6/interfaces/AggregatorV3Interface.sol
// https://github.com/smartcontractkit/chainlink/blob/feature/whitelisted-interface/evm-contracts/src/v0.6/interfaces/AggregatorInterface.sol
interface AggregatorInterface {
  function latestAnswer() external view returns (int256);

  function latestTimestamp() external view returns (uint256);

  function latestRound() external view returns (uint256);

  function getAnswer(uint256 roundId) external view returns (int256);

  function getTimestamp(uint256 roundId) external view returns (uint256);

  function decimals() external view returns (uint8);

  function latestRoundData()
    external
    view
    returns (
      uint256 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint256 answeredInRound
    );
}
