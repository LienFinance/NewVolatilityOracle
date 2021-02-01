const BigNumber = require("bignumber.js");
const testPrices = [
  new BigNumber(1340 * 10 ** 8),
  new BigNumber(1300 * 10 ** 8),
  new BigNumber(1400 * 10 ** 8),
  new BigNumber(1320 * 10 ** 8),
  new BigNumber(1300 * 10 ** 8),

  new BigNumber(1310 * 10 ** 8),
  new BigNumber(1340 * 10 ** 8),
  new BigNumber(1300 * 10 ** 8),
  new BigNumber(1400 * 10 ** 8),
  new BigNumber(1320 * 10 ** 8),

  new BigNumber(1300 * 10 ** 8),
  new BigNumber(1310 * 10 ** 8),
  new BigNumber(1300 * 10 ** 8),
  new BigNumber(1310 * 10 ** 8),
  new BigNumber(1300 * 10 ** 8),
];

const testVolatilites = [
  new BigNumber(90 * 10 ** 6),
  new BigNumber(90 * 10 ** 6),
  new BigNumber(90 * 10 ** 6),
  new BigNumber(90 * 10 ** 6),
  new BigNumber(90 * 10 ** 6),

  new BigNumber(90 * 10 ** 6),
  new BigNumber(90 * 10 ** 6),
  new BigNumber(90 * 10 ** 6),
  new BigNumber(90 * 10 ** 6),
  new BigNumber(90 * 10 ** 6),

  new BigNumber(90 * 10 ** 6),
  new BigNumber(90 * 10 ** 6),
  new BigNumber(90 * 10 ** 6),
  new BigNumber(90 * 10 ** 6),
  new BigNumber(90 * 10 ** 6),
];

module.exports = {
  prices: testPrices,
  volatility: testVolatilites,
};
