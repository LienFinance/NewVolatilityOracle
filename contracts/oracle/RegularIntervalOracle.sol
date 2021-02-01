// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

import "./RegularIntervalOracleInterface.sol";
import "../ChainLinkAggregator/ChainLinkAggregatorInterface.sol";
import "../../node_modules/@openzeppelin/contracts/utils/SafeCast.sol";

/**
 * @dev Record chainlink price once a day
 */
contract RegularIntervalOracle is RegularIntervalOracleInterface {
  using SafeCast for uint16;
  using SafeCast for uint32;
  using SafeCast for uint256;

  struct PriceData {
    uint64 priceE8;
    uint64 ewmaVolatilityE8;
  }

  /* ========== CONSTANT VARIABLES ========== */

  AggregatorInterface _chainlinkOracle;
  uint256 immutable _interval;
  uint8 immutable _decimals;
  uint128 immutable _timeCorrectionFactor;
  uint128 immutable _oldestTimestamp;
  uint16 immutable _dataNum;

  /* ========== STATE VARIABLES ========== */

  address _quantsAddress;
  uint256 _latestTimestamp;
  mapping(uint256 => PriceData) internal _regularIntervalPriceData;

  uint16 lambdaE4;

  /* ========== CONSTRUCTOR ========== */

  /**
   * @param quantsAddress can set optimized parameters
   * @param chainlinkOracleAddress Chainlink price oracle
   * @param startTimestamp Recording timestamp is startTimestamp +- n * interval
   * @param interval Daily record = 3600*24
   * @param decimals Decimals of price
   */
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
  ) {
    _dataNum = initialDataNum;
    lambdaE4 = initialLambdaE4;
    _quantsAddress = quantsAddress;
    _chainlinkOracle = AggregatorInterface(chainlinkOracleAddress);
    _interval = interval;
    _decimals = decimals;
    _timeCorrectionFactor = uint128(startTimestamp % interval);
    initialRoundId = _getValidRoundID(initialRoundId, startTimestamp);
    int256 priceE8 = _getPriceFromChainlink(initialRoundId);
    _regularIntervalPriceData[startTimestamp] = PriceData(
      uint256(priceE8).toUint64(),
      uint64(initialVolE4)
    );
    _latestTimestamp = uint128(startTimestamp);
    _oldestTimestamp = uint128(startTimestamp);
  }

  /* ========== MUTABLE FUNCTIONS ========== */

  /**
   * @notice Set new price
   * @dev Prices must be updated by regular interval
   * @param roundId is chainlink roundId
   */
  function setPrice(uint256 roundId) public override returns (bool) {
    _latestTimestamp += _interval;
    //If next oldestTimestamp == _latestTimestamp

    roundId = _getValidRoundID(roundId, _latestTimestamp);
    _setPrice(roundId, _latestTimestamp);
    return true;
  }

  /**
   * @notice Set sequential prices
   * @param roundIds Array of roundIds which contain the first timestamp after the regular interval timestamp
   */
  function setSequentialPrices(uint256[] calldata roundIds)
    external
    override
    returns (bool)
  {
    uint256 normalizedCurrentTimestamp =
      getNormalizedTimeStamp(block.timestamp);
    // If length of roundIds is too short or too long, return false
    if (
      (normalizedCurrentTimestamp - _latestTimestamp) / _interval <
      roundIds.length ||
      roundIds.length < 2
    ) {
      return false;
    }

    for (uint256 i = 0; i < roundIds.length; i++) {
      setPrice(roundIds[i]);
    }
    return true;
  }

  /**
   * @notice Set optimized parameters for EWMA only by quants address
   * Recalculate latest Volatility with new lambda
   * Recalculation starts from price at `latestTimestamp - _dataNum * _interval`
   */
  function setOptimizedParameters(uint16 newLambdaE4)
    external
    override
    onlyQuants
    returns (bool)
  {
    require(
      newLambdaE4 > 9000 && newLambdaE4 < 10000,
      "new lambda is out of valid range"
    );
    require(
      (_latestTimestamp - _oldestTimestamp) / _interval > _dataNum,
      "Error: Insufficient number of data registered"
    );
    lambdaE4 = newLambdaE4;
    uint256 oldTimestamp = _latestTimestamp - _dataNum * _interval;
    uint256 pNew = _getPrice(oldTimestamp + _interval);
    uint256 updatedVol = _getVolatility(oldTimestamp);
    for (uint256 i = 0; i < _dataNum; i++) {
      updatedVol = _getEwmaVolatility(oldTimestamp, pNew, updatedVol);
      oldTimestamp += _interval;
      pNew = _getPrice(oldTimestamp + _interval);
    }

    _regularIntervalPriceData[_latestTimestamp].ewmaVolatilityE8 = updatedVol
      .toUint64();
    return true;
  }

  /**
   * @notice Update quants address only by quants address
   */
  function updateQuantsAddress(address quantsAddress)
    external
    override
    onlyQuants
    returns (bool)
  {
    _quantsAddress = quantsAddress;
  }

  /* ========== MODIFIERS ========== */

  modifier onlyQuants() {
    require(msg.sender == _quantsAddress, "only quants address can call");
    _;
  }

  /* ========== INTERNAL FUNCTIONS ========== */

  /**
   * @return price at the `unixtime`
   */
  function _getPrice(uint256 unixtime) internal view returns (uint256) {
    return _regularIntervalPriceData[unixtime].priceE8;
  }

  /**
   * @return Volatility at the `unixtime`
   */
  function _getVolatility(uint256 unixtime) internal view returns (uint256) {
    return _regularIntervalPriceData[unixtime].ewmaVolatilityE8;
  }

  /**
   * @notice Get annualized ewma volatility.
   * @param oldTimestamp is the previous term to calculate volatility
   */
  function _getEwmaVolatility(
    uint256 oldTimestamp,
    uint256 pNew,
    uint256 oldVolE8
  ) internal view returns (uint256 volE8) {
    uint256 pOld = _getPrice(oldTimestamp);
    uint256 rrE8 =
      pNew >= pOld
        ? ((pNew * (10**4)) / pOld - (10**4))**2
        : ((10**4) - (pNew * (10**4)) / pOld)**2;
    uint256 vol_2E16 =
      (oldVolE8**2 * lambdaE4) / 10**4 + (10**4 - lambdaE4) * rrE8 * 10**4;
    volE8 = _sqrt(vol_2E16);
  }

  /**
   * @dev Calcurate an approximation of the square root of x by Babylonian method.
   */
  function _sqrt(uint256 x) internal pure returns (uint256 y) {
    require(x >= 0, "cannot calculate the square root of a negative number");
    uint256 z = (x + 1) / 2;
    y = x;
    while (z < y) {
      y = z;
      z = (x / z + z) / 2;
    }
  }

  function _getValidRoundID(uint256 hintID, uint256 targetTimeStamp)
    internal
    view
    returns (uint256 roundID)
  {
    if (hintID == 0) {
      hintID = _chainlinkOracle.latestRound();
    }
    uint256 timeStampOfHintID = _chainlinkOracle.getTimestamp(hintID);
    require(
      timeStampOfHintID >= targetTimeStamp,
      "Hint round or Latest round should be registered after target time"
    );
    for (uint256 index = hintID - 1; index > 0; index--) {
      uint256 timestamp = _chainlinkOracle.getTimestamp(index);
      if (timestamp != 0 && timestamp <= targetTimeStamp) {
        return index + 1;
      }
    }
    require(false, "No valid round ID found");
  }

  function _setPrice(uint256 roundId, uint256 timeStamp) internal {
    int256 priceE8 = _getPriceFromChainlink(roundId);
    require(priceE8 > 0, "Should return valid price");
    uint256 ewmaVolatilityE8 =
      _getEwmaVolatility(
        timeStamp - _interval,
        uint256(priceE8),
        _getVolatility(timeStamp - _interval)
      );
    _regularIntervalPriceData[timeStamp] = PriceData(
      uint256(priceE8).toUint64(),
      ewmaVolatilityE8.toUint64()
    );
  }

  function _getPriceFromChainlink(uint256 roundId)
    internal
    view
    returns (int256 priceE8)
  {
    while (true) {
      priceE8 = _chainlinkOracle.getAnswer(roundId);
      if (priceE8 > 0) {
        break;
      }
      roundId -= 1;
    }
  }

  /* ========== CALL FUNCTIONS ========== */

  /**
   * @notice Calculate normalized timestamp to get valid value
   */
  function getNormalizedTimeStamp(uint256 timestamp)
    public
    view
    override
    returns (uint256)
  {
    return
      ((timestamp - _timeCorrectionFactor) / _interval) *
      _interval +
      _timeCorrectionFactor;
  }

  function getInfo()
    public
    view
    override
    returns (address chainlink, address quants)
  {
    return (address(_chainlinkOracle), _quantsAddress);
  }

  /**
   * @return Decimals of price
   */
  function getDecimals() external view override returns (uint8) {
    return _decimals;
  }

  /**
   * @return Interval of historical data
   */
  function getInterval() external view override returns (uint256) {
    return _interval;
  }

  /**
   * @return Latest timestamp in this oracle
   */
  function getLatestTimestamp() external view override returns (uint256) {
    return _latestTimestamp;
  }

  /**
   * @return Oldest timestamp in this oracle
   */
  function getOldestTimestamp() external view override returns (uint256) {
    return _oldestTimestamp;
  }

  function getPrice() external view override returns (uint256) {
    return _getPrice(_latestTimestamp);
  }

  function getCurrentParameters()
    external
    view
    override
    returns (uint16 lambda, uint16 dataNum)
  {
    return (lambdaE4, _dataNum);
  }

  function getPriceTimeOf(uint256 unixtime)
    external
    view
    override
    returns (uint256)
  {
    uint256 normalizedUnixtime = getNormalizedTimeStamp(unixtime);
    return _getPrice(normalizedUnixtime);
  }

  function _getCurrentVolatility() internal view returns (uint256 volE8) {
    uint256 latestRound = _chainlinkOracle.latestRound();
    uint256 latestVolatility = _getVolatility(_latestTimestamp);
    uint256 currentVolatility =
      _getEwmaVolatility(
        _latestTimestamp,
        uint256(_getPriceFromChainlink(latestRound)),
        _getVolatility(_latestTimestamp)
      );
    volE8 = latestVolatility >= currentVolatility
      ? latestVolatility
      : currentVolatility;
  }

  /**
   * @notice Calculate lastest ewmaVolatility
   * @dev Calculate new volatility with chainlink price at latest round
   * @param volE8 Return the larger of `latestVolatility` and `currentVolatility`
   */
  function getVolatility() public view override returns (uint256 volE8) {
    volE8 = _getCurrentVolatility();
  }

  /**
   * @notice This function has the same interface with Lien Volatility Oracle
   */
  function getVolatility(uint64)
    external
    view
    override
    returns (uint64 volatilityE8)
  {
    uint256 volE8 = _getCurrentVolatility();
    return volE8.toUint64();
  }

  /**
   * @notice Get registered ewmaVolatility of given timestamp
   */
  function getVolatilityTimeOf(uint256 unixtime)
    public
    view
    override
    returns (uint256 volE8)
  {
    uint256 normalizedUnixtime = getNormalizedTimeStamp(unixtime);
    return _regularIntervalPriceData[normalizedUnixtime].ewmaVolatilityE8;
  }
}