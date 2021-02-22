// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

import "./RegularIntervalOracleInterface.sol";
import "../ChainLinkAggregator/ChainLinkAggregatorInterface.sol";
// AUDIT-FIX: RIO-01 Not-Fixed. cannot fix
import "../../node_modules/@openzeppelin/contracts/utils/SafeCast.sol";
import "../../node_modules/@openzeppelin/contracts/math/SafeMath.sol";

/**
 * @dev Record chainlink price once a day
 */
contract RegularIntervalOracle is RegularIntervalOracleInterface {
  using SafeCast for uint16;
  using SafeCast for uint32;
  using SafeCast for uint256;
  using SafeMath for uint256;

  struct PriceData {
    uint64 priceE8;
    uint64 ewmaVolatilityE8;
  }

  // Max ETH Price = $1 million per ETH
  int256 constant MAX_VALID_ETHPRICE = 10**14;

  /* ========== CONSTANT VARIABLES ========== */
  // AUDIT-FIX: RIO-02
  AggregatorInterface immutable internal _chainlinkOracle;
  // AUDIT-FIX: RIO-03
  uint256 immutable internal _interval;
  // AUDIT-FIX: RIO-04
  uint8 immutable internal _decimals;
  // AUDIT-FIX: RIO-05
  uint128 immutable internal _timeCorrectionFactor;
  // AUDIT-FIX: RIO-06
  uint128 immutable internal _oldestTimestamp;
  // AUDIT-FIX: RIO-07
  uint16 immutable internal _dataNum;

  /* ========== STATE VARIABLES ========== */
  // AUDIT-FIX: RIO-08
  address internal _quantsAddress;
  // AUDIT-FIX: RIO-09
  uint256 internal _latestTimestamp;
  mapping(uint256 => PriceData) internal _regularIntervalPriceData;
  // AUDIT-FIX: RIO-10
  uint16 internal lambdaE4;

  event LambdaChanged(uint16 newLambda);
  event QuantsChanged(address newQuantsAddress);

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
    initialRoundId = _getValidRoundIDWithAggregator(initialRoundId, startTimestamp, AggregatorInterface(chainlinkOracleAddress));
    int256 priceE8 = _getPriceFromChainlinkWithAggregator(initialRoundId, AggregatorInterface(chainlinkOracleAddress));
    _regularIntervalPriceData[startTimestamp] = PriceData(
      uint256(priceE8).toUint64(),
      uint64(initialVolE4)
    );
    _latestTimestamp = uint128(startTimestamp);
    _oldestTimestamp = uint128(startTimestamp);
    // AUDIT-FIX: RIO-11
    require(initialDataNum > 1, "Error: Decimals should be more than 0");
    // AUDIT-FIX: RIO-12
    require(quantsAddress != address(0), "Error: Invalid initial quant address");
    // AUDIT-FIX: RIO-13
    require(chainlinkOracleAddress != address(0), "Error: Invalid chainlink address");
    // AUDIT-FIX: RIO-14
    require(interval != 0, "Error: Interval should be more than 0");
  }

  /* ========== MUTABLE FUNCTIONS ========== */

  /**
   * @notice Set new price
   * @dev Prices must be updated by regular interval
   * @param roundId is chainlink roundId
   */
   // AUDIT-FIX: RIO-15: Add ristriction of time but not accessibility
  function setPrice(uint256 roundId) public override returns (bool) {
    // AUDIT-FIX: RIO-16: Not-Fixed: Unnecessary modification
    _latestTimestamp += _interval;
    require(_latestTimestamp <= block.timestamp, "Error: This function should be after interval");
    //If next oldestTimestamp == _latestTimestamp

    roundId = _getValidRoundID(roundId, _latestTimestamp);
    _setPrice(roundId, _latestTimestamp);
    return true;
  }

  /**
   * @notice Set sequential prices
   * @param roundIds Array of roundIds which contain the first timestamp after the regular interval timestamp
   */
   // AUDIT-FIX: RIO-17: Add ristriction of time in setPrice() but not accessibility
  function setSequentialPrices(uint256[] calldata roundIds)
    external
    override
    returns (bool)
  {
    // AUDIT-FIX: RIO-19
    uint256 roundIdsLength = roundIds.length;
    uint256 normalizedCurrentTimestamp =
      getNormalizedTimeStamp(block.timestamp);
      // AUDIT-FIX: RIO-18
    require(_latestTimestamp <= normalizedCurrentTimestamp, "Error: This function should be after interval");
    // If length of roundIds is too short or too long, return false
    if (
      (normalizedCurrentTimestamp - _latestTimestamp) / _interval <
      roundIdsLength ||
      roundIdsLength < 2
    ) {
      return false;
    }

    for (uint256 i = 0; i < roundIdsLength; i++) {
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
    // AUDIT-FIX: RIO-22 Not-Fixed: Unnecessary modification. _interval is non 0 value
    require(
      (_latestTimestamp - _oldestTimestamp) / _interval > _dataNum,
      "Error: Insufficient number of data registered"
    );
    lambdaE4 = newLambdaE4;
    // AUDIT-FIX: RIO-20: Not-Fixed: Unnecessary modification: value has been already checked above
    uint256 oldTimestamp = _latestTimestamp - _dataNum * _interval;
    // AUDIT-FIX: RIO-23: Not-Fixed: Unnecessary modification
    uint256 pNew = _getPrice(oldTimestamp + _interval);
    uint256 updatedVol = _getVolatility(oldTimestamp);
    for (uint256 i = 0; i < _dataNum; i++) {
      updatedVol = _getEwmaVolatility(oldTimestamp, pNew, updatedVol);
      // AUDIT-FIX: RIO-24: Not-Fixed: Unnecessary modification
      oldTimestamp += _interval;
      // AUDIT-FIX: RIO-25: Not-Fixed: Unnecessary modification
      pNew = _getPrice(oldTimestamp + _interval);
    }

    _regularIntervalPriceData[_latestTimestamp].ewmaVolatilityE8 = updatedVol
      .toUint64();
    // AUDIT-FIX: RIO-21
    emit LambdaChanged(newLambdaE4);
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
    // AUDIT-FIX: RIO-26
    require(quantsAddress != address(0), "Error: Invalid new quant address");
    // AUDIT-FIX: RIO-27
    emit QuantsChanged(quantsAddress);
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
    // AUDIT-FIX: RIO-28 Not-Fixed: Unnecessary modification
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
   // AUDIT-FIX: RIO-29
  function _sqrt(uint256 x) internal pure returns (uint256 y) { 
    if (x > 3) {
      uint z = x / 2 + 1; y = x;
      while (z < y) {
        y = z;
        z = (x / z + z) / 2; 
      }
    } else if (x != 0) { 
      y = 1;
    } 
  }

  function _getValidRoundID(uint256 hintID, uint256 targetTimeStamp)
    internal
    view
    returns (uint256 roundID)
  {
    return _getValidRoundIDWithAggregator(hintID, targetTimeStamp, _chainlinkOracle);
  }

  function _getValidRoundIDWithAggregator(uint256 hintID, uint256 targetTimeStamp, AggregatorInterface _chainlinkAggregator)
    internal
    view
    returns (uint256 roundID)
  {
    if (hintID == 0) {
      hintID = _chainlinkAggregator.latestRound();
    }
    uint256 timeStampOfHintID = _chainlinkAggregator.getTimestamp(hintID);
    require(
      timeStampOfHintID >= targetTimeStamp,
      "Hint round or Latest round should be registered after target time"
    );
    require(hintID != 0, "Invalid hint ID");
    // AUDIT-FIX: RIO-30 Not-Fixed: Unnecessary modification: hint ID at this point is more than 0
    for (uint256 index = hintID - 1; index > 0; index--) {
      uint256 timestamp = _chainlinkAggregator.getTimestamp(index);
      if (timestamp != 0 && timestamp <= targetTimeStamp) {
        // AUDIT-FIX: RIO-31 Not-Fixed: Unnecessary modification
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
        // AUDIT-FIX: RIO-32 Not-Fixed: Unnecessary modification
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
    returns (int256 priceE8) {
      return _getPriceFromChainlinkWithAggregator(roundId, _chainlinkOracle);
    }


  function _getPriceFromChainlinkWithAggregator(uint256 roundId, AggregatorInterface _chainlinkAggregator)
    internal
    view
    returns (int256 priceE8)
  {
    while (true) {
      priceE8 = _chainlinkAggregator.getAnswer(roundId);
      // AUDIT-FIX: RIO-28 etc
      if (priceE8 > 0 &&  priceE8 < MAX_VALID_ETHPRICE ) {
        break;
      }
      // AUDIT-FIX: RIO-33 Not-Fixed: Unnecessary modification
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
    // AUDIT-FIX: RIO-34
    // L79
    return
      ((timestamp.sub(_timeCorrectionFactor)) / _interval) *
      // AUDIT-FIX: RIO-35 Not-Fixed: Unnecessary modification
      _interval +
      _timeCorrectionFactor;
  }

// AUDIT-FIX: RIO-36
  function getInfo()
    external
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
   // AUDIT-FIX: RIO-37
  function getVolatility() external view override returns (uint256 volE8) {
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
    external
    view
    override
    returns (uint256 volE8)
  {
    uint256 normalizedUnixtime = getNormalizedTimeStamp(unixtime);
    return _regularIntervalPriceData[normalizedUnixtime].ewmaVolatilityE8;
  }
}
