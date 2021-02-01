// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

/**
 * @dev Interface of the regular interval price oracle.
 */
interface RegularIntervalOracleInterface {
  function setPrice(uint256 roundId) external returns (bool);

  function setOptimizedParameters(uint16 lambdaE4) external returns (bool);

  function updateQuantsAddress(address quantsAddress) external returns (bool);

  function getNormalizedTimeStamp(uint256 timestamp)
    external
    view
    returns (uint256);

  function getDecimals() external view returns (uint8);

  function getInterval() external view returns (uint256);

  function getLatestTimestamp() external view returns (uint256);

  function getOldestTimestamp() external view returns (uint256);

  function getVolatility() external view returns (uint256 volE8);

  function getInfo() external view returns (address chainlink, address quants);

  function getPrice() external view returns (uint256);

  function setSequentialPrices(uint256[] calldata roundIds)
    external
    returns (bool);

  function getPriceTimeOf(uint256 unixtime) external view returns (uint256);

  function getVolatilityTimeOf(uint256 unixtime)
    external
    view
    returns (uint256 volE8);

  function getCurrentParameters()
    external
    view
    returns (uint16 lambdaE4, uint16 dataNum);

  function getVolatility(uint64 untilMaturity)
    external
    view
    returns (uint64 volatilityE8);
}
