// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

import "../ChainLinkAggregator/ChainLinkAggregatorInterface.sol";

contract mockChainLinkAggregator is AggregatorInterface {
  uint8 public constant override decimals = 8;
  uint256[] priceData;
  uint256[] timestampData;

  constructor(uint256[] memory initialPriceData) {
    uint256 timestamp =
      (block.timestamp / 86400) *
        86400 +
        3600 -
        43200 *
        initialPriceData.length;
    for (uint8 i = 0; i < initialPriceData.length; i++) {
      timestamp += 43200;
      timestampData.push(timestamp);
      priceData.push(initialPriceData[i]);
    }
  }

  function insertNewData(uint256 price, uint256 timestamp) public {
    timestampData.push(timestamp);
    priceData.push(price);
  }

  function latestAnswer() external view override returns (int256) {
    return (int256(priceData[priceData.length - 1]));
  }

  function latestTimestamp() external view override returns (uint256) {
    return timestampData[timestampData.length - 1];
  }

  function latestRound() external view override returns (uint256) {
    return priceData.length;
  }

  function getAnswer(uint256 roundId) external view override returns (int256) {
    return int256(priceData[roundId - 1]);
  }

  function getTimestamp(uint256 roundId)
    external
    view
    override
    returns (uint256)
  {
    return timestampData[roundId - 1];
  }

  function latestRoundData()
    external
    view
    override
    returns (
      uint256 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint256 answeredInRound
    )
  {
    (
      priceData.length,
      int256(priceData[priceData.length - 1]),
      timestampData[timestampData.length - 1],
      timestampData[timestampData.length - 1],
      timestampData[timestampData.length - 1]
    );
  }
}
