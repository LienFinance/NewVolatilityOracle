const ChainLinkAggregator = artifacts.require("mockChainLinkAggregator");
const RegularIntervalOracle = artifacts.require("testRegularIntervalOracle");
const BigNumber = require("bignumber.js");
const { time, expectRevert } = require("@openzeppelin/test-helpers");
const constants = require("./testData/constants.js");
const initialPriceData = [
  new BigNumber(1340 * 10 ** 8),
  new BigNumber(1300 * 10 ** 8),
  new BigNumber(1420 * 10 ** 8),
  new BigNumber(1370 * 10 ** 8),
  new BigNumber(1390 * 10 ** 8),
  new BigNumber(1330 * 10 ** 8),
];
const decimals = 8;
const initialLambda = 9500;
const initialDataNum = 14;
const initialVol = new BigNumber(90 * 10 ** 6);
const interval = 86400;
const initialRoundId = 2;

async function getTimeStamp(termLength) {
  const block = await web3.eth.getBlock("latest");
  const timestamp = block.timestamp;
  const days = Math.floor(timestamp / interval);
  return (days - termLength) * interval;
}

contract("RegularIntervalOracle", function (accounts) {
  let oracleInstance;
  let aggregatorInstance;
  let startTime;
  let latest;
  beforeEach(async () => {
    startTime = await getTimeStamp(2);
    latest = await getTimeStamp(0);
    aggregatorInstance = await ChainLinkAggregator.new(initialPriceData);
    oracleInstance = await RegularIntervalOracle.new(
      decimals,
      initialLambda,
      initialDataNum,
      initialVol,
      accounts[0],
      aggregatorInstance.address,
      startTime,
      interval,
      initialRoundId
    );
  });
  describe("Check Initial Value", function () {
    it("check decimals", async () => {
      const decimal = await oracleInstance.getDecimals();
      assert.equal(
        decimal.toString(),
        String(decimals),
        "Invalid decimals returned"
      );
    });

    it("check parameters", async () => {
      const parameters = await oracleInstance.getCurrentParameters();
      assert.equal(
        parameters[0].toString(),
        String(initialLambda),
        "Invalid lambda returned"
      );
      assert.equal(
        parameters[1].toString(),
        String(initialDataNum),
        "Invalid dataNum returned"
      );
    });

    it("check quants address", async () => {
      const addresses = await oracleInstance.getInfo();
      assert.equal(
        addresses[1],
        accounts[0],
        "Invalid quants address returned"
      );
    });

    it("check chain link address", async () => {
      const addresses = await oracleInstance.getInfo();
      assert.equal(
        addresses[0],
        aggregatorInstance.address,
        "Invalid quants address returned"
      );
    });

    it("check latestTime", async function () {
      const timestamp = await oracleInstance.getLatestTimestamp();
      assert.equal(
        timestamp.toString(),
        String(startTime),
        "Invalid timestamp returned"
      );
    });

    it("check oldestTime", async function () {
      const timestamp = await oracleInstance.getOldestTimestamp();
      assert.equal(
        timestamp.toString(),
        String(startTime),
        "Invalid timestamp returned"
      );
    });

    it("check interval", async function () {
      const _interval = await oracleInstance.getInterval();
      assert.equal(
        _interval.toString(),
        String(interval),
        "Invalid interval returned"
      );
    });

    it("check price", async () => {
      const price = await oracleInstance.getPrice();
      assert.equal(
        price.toString(),
        initialPriceData[1].toString(),
        "Invalid price returned"
      );
    });

    it("check volatility", async () => {
      const volatility = await oracleInstance.getVolatilityTimeOf(
        startTime + 100
      );
      assert.equal(
        volatility.toString(),
        initialVol.toString(),
        "Invalid volatility returned:"
      );
    });
  });

  describe("getValidRoundID", function () {
    it("round ID for start time", async () => {
      /*
      console.log(
        "latest round ID: " + (await aggregatorInstance.latestRound())
      );
      console.log(
        "latest timestamp: " + (await aggregatorInstance.latestTimestamp())
      );
      console.log(
        "latest timestamp: " + (await aggregatorInstance.getTimestamp(6))
      );
      console.log("start time: " + startTime);
      */
      const roundID = await oracleInstance.getValidRoundID(0, startTime);
      assert.equal(roundID.toString(), "2", "Invalid round ID returned");
    });
    it("round ID for -1 day", async () => {
      const block = await web3.eth.getBlock("latest");
      const timestamp = block.timestamp;
      const roundedTimeStamp = Math.floor(timestamp / interval) * interval;
      const roundID = await oracleInstance.getValidRoundID(
        0,
        roundedTimeStamp - 86400
      );
      assert.equal(roundID.toString(), "4", "Invalid round ID returned");
    });
    it("round ID for today", async () => {
      const block = await web3.eth.getBlock("latest");
      const timestamp = block.timestamp;
      const roundedTimeStamp = Math.floor(timestamp / interval) * interval;
      const roundID = await oracleInstance.getValidRoundID(0, roundedTimeStamp);
      assert.equal(roundID.toString(), "6", "Invalid round ID returned");
    });
  });

  describe("getNormalizedTimeStamp", function () {
    it("normalize correctly", async () => {
      const block = await web3.eth.getBlock("latest");
      const timestamp = block.timestamp;
      const normalizedTimeStamp = await oracleInstance.getNormalizedTimeStamp(
        timestamp
      );
      assert.equal(
        normalizedTimeStamp.toString(),
        String(Math.floor(timestamp / interval) * 86400),
        "invalid timestamp returned"
      );
    });

    it("return valid price from getPriceTimeOf()", async () => {
      const price = await oracleInstance.getPriceTimeOf(startTime + 43200);
      assert.equal(
        price.toString(),
        initialPriceData[1].toString(),
        "Invalid price returned"
      );
    });
  });

  describe("setPrice", function () {
    describe("set latest first", function () {
      beforeEach(async () => {
        await oracleInstance.setPrice(0);
      });
      it("check price", async function () {
        const price = await oracleInstance.getPrice();
        assert.equal(
          price.toString(),
          initialPriceData[3].toString(),
          "Invalid price returned"
        );
      });
      it("check _latest timestamp", async function () {
        const timestamp = await oracleInstance.getLatestTimestamp();
        assert.equal(timestamp.toString(), String(startTime + interval));
      });
      it("check volatility", async function () {
        const vol = await oracleInstance.getVolatilityTimeOf(
          startTime + interval
        );
        assert.equal(
          vol.toString(),
          "90682056",
          "Invalid volatility returned: " + vol.toString()
        );
      });
      describe("call twice", function () {
        beforeEach(async () => {
          await oracleInstance.setPrice(0);
        });
        it("check price", async function () {
          const price = await oracleInstance.getPrice();
          assert.equal(
            price.toString(),
            initialPriceData[5].toString(),
            "Invalid price returned"
          );
        });
        it("check _latest timestamp", async function () {
          const timestamp = await oracleInstance.getLatestTimestamp();
          assert.equal(timestamp.toString(), String(startTime + interval * 2));
        });
        it("check volatility", async function () {
          const vol = await oracleInstance.getVolatilityTimeOf(
            startTime + interval * 2
          );
          assert.equal(
            vol.toString(),
            "89261863",
            "Invalid volatility returned: " + vol.toString()
          );
        });
      });
    });
  });

  describe("setSequential prices", function () {
    beforeEach(async function () {
      await time.increase(interval * 2);
      await oracleInstance.setSequentialPrices([0, 0]);
    });
    it("check price", async function () {
      const price = await oracleInstance.getPrice();
      assert.equal(
        price.toString(),
        initialPriceData[5].toString(),
        "Invalid price returned"
      );
    });
    it("check _latest timestamp", async function () {
      const timestamp = await oracleInstance.getLatestTimestamp();
      assert.equal(timestamp.toString(), String(startTime + interval * 2));
    });
  });

  describe("only quants functions", function () {
    it("updateQuantsAddress", async function () {
      await oracleInstance.updateQuantsAddress(accounts[1]);
      const info = await oracleInstance.getInfo();
      assert.equal(info[1], accounts[1], "invalid quants address returned");
    });
    it("should revert if executed by invalid address", async function () {
      await expectRevert.unspecified(
        oracleInstance.updateQuantsAddress(accounts[1], { from: accounts[2] })
      );
    });
    describe("setOptimizedParameters", function () {
      beforeEach(async function () {
        await time.increase(interval * 15);
        await oracleInstance.insertPriceAndVolatility(
          constants.prices,
          constants.volatility
        );
      });
      it("check lambda", async function () {
        const newLambda = "9100";
        await oracleInstance.setOptimizedParameters(newLambda);
        const parameters = await oracleInstance.getCurrentParameters();
        assert.equal(
          parameters[0].toString(),
          String(newLambda),
          "Invalid lambda returned"
        );
      });
      it("check volatility", async function () {
        await oracleInstance.setOptimizedParameters(9100);
        const vol = await oracleInstance.getVolatilityTimeOf(
          startTime + interval * 15
        );

        const vol2 = await oracleInstance.getVolatilityTimeOf(
          startTime + interval * 14
        );
        console.log(vol2.toString());
        console.log(vol.toString());
        assert.equal(
          vol.toString(),
          "74483675",
          "Invalid volatility returned: " + vol.toString()
        );
      });
      it("if lambda is too small", async function () {
        await expectRevert.unspecified(
          oracleInstance.setOptimizedParameters(9000)
        );
      });
      it("if lambda is too big", async function () {
        await expectRevert.unspecified(
          oracleInstance.setOptimizedParameters(10000)
        );
      });
      it("executed by invalid user", async function () {
        await expectRevert.unspecified(
          oracleInstance.setOptimizedParameters(9100, {
            from: accounts[1],
          })
        );
      });
    });
  });
});
