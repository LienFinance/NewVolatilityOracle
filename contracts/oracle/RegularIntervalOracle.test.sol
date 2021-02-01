// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

import "./RegularIntervalOracle.sol";

contract testRegularIntervalOracle is RegularIntervalOracle {
  constructor(
    uint8 decimals,
    uint16 initialLambdaE4,
    uint16 initialDataNum,
    uint32 initialVolE4,
    address quantsAddress,
    address chainlinkOracleAddress,
    uint256 startTimestamp,
    uint256 interval,
    uint256 initialRoundId
  )
    RegularIntervalOracle(
      decimals,
      initialLambdaE4,
      initialDataNum,
      initialVolE4,
      quantsAddress,
      chainlinkOracleAddress,
      startTimestamp,
      interval,
      initialRoundId
    )
  {}

  function getValidRoundID(uint256 hintID, uint256 targetTimeStamp)
    external
    view
    returns (uint256 roundID)
  {
    return _getValidRoundID(hintID, targetTimeStamp);
  }

  function setPriceInternal(uint256 roundId, uint256 timeStamp) external {
    _setPrice(roundId, timeStamp);
  }

  function insertPriceAndVolatility(
    uint256[] memory prices,
    uint256[] memory volatilities
  ) external {
    uint256 currentLatestTimestamp = _latestTimestamp;
    for (uint256 i = 0; i < prices.length; i++) {
      _regularIntervalPriceData[currentLatestTimestamp] = PriceData(
        uint64(prices[i]),
        uint64(volatilities[i])
      );
      currentLatestTimestamp += _interval;
    }
    _latestTimestamp = currentLatestTimestamp;
  }
}
