
import { describe, it, expect } from "@jest/globals";
import {
  evaluateCustomIndicator,
  CustomIndicatorConfig,
} from "../src/technical-indicators";

describe("evaluateCustomIndicator", () => {
  const prices = [10, 11, 12, 13, 14, 15, 14, 13, 12, 11, 10];
  const highs = prices;
  const lows = prices;
  const volumes = prices.map(() => 1000);

  it("should evaluate SMA GreaterThan condition", () => {
    // Last price is 10. SMA(period=2) of [11, 10] is 10.5
    // SMA(period=5) of [14, 13, 12, 11, 10] is 12
    const config: CustomIndicatorConfig = {
      id: "test-sma",
      name: "Test SMA",
      type: "SMA",
      parameters: { period: 5 },
      condition: "LessThan",
      threshold: 13,
      compareToPrice: false,
    };

    const result = evaluateCustomIndicator(
      config, prices, highs, lows, volumes);
    expect(result.value).toBe(12);
    expect(result.signal).toBe("BUY"); // 12 < 13
  });

  it("should evaluate MACD component selection", () => {
    // Need enough data for MACD
    const longPrices = Array(50).fill(10).map((v, i) => v + i);
    // uptrend. MACD > Signal > 0 usually.

    // MACD Line
    const configMacd: CustomIndicatorConfig = {
      id: "test-macd-line",
      name: "Test MACD Line",
      type: "MACD",
      parameters: { component: "macd" },
      condition: "GreaterThan",
      threshold: 0,
    };
    const resMacd = evaluateCustomIndicator(
      configMacd, longPrices, longPrices, longPrices, []);
    expect(resMacd.value).toBeGreaterThan(0);

    // Signal Line
    const configSignal: CustomIndicatorConfig = {
      id: "test-macd-signal",
      name: "Test MACD Signal",
      type: "MACD",
      parameters: { component: "signal" },
      condition: "GreaterThan",
      threshold: 0,
    };
    const resSignal = evaluateCustomIndicator(
      configSignal, longPrices, longPrices, longPrices, []);
    expect(resSignal.value).toBeGreaterThan(0);

    // Histogram
    const configHist: CustomIndicatorConfig = {
      id: "test-macd-hist",
      name: "Test MACD Hist",
      type: "MACD",
      parameters: { component: "histogram" },
      condition: "GreaterThan",
      threshold: -100,
      // Should be roughly constant or slightly positive in linear trend?
    };
    const resHist = evaluateCustomIndicator(
      configHist, longPrices, longPrices, longPrices, []);
    expect(resHist.value).toBeDefined();
    // MACD approx diff of EMAs. linear trend 10,11,12...
    // EMA12lag is approx 6. EMA26lag is approx 13.
    // fastEMA > slowEMA in uptrend. So MACD > 0.
  });

  it("should detect CrossOverAbove", () => {
    // Scenario: Indicator starts below threshold, then goes above.
    // period=2 SMA.
    // Candle 1: [10, 10]. SMA=10. Threshold=11. (10 < 11)
    // Candle 2: [10, 10, 12]. SMA(2) of [10, 12] = 11. (11 not > 11) - Wait.
    // Let's use simpler numbers.
    // Threshold = 10.
    // Prev Value = 9. Current Value = 11. -> CrossOverAbove.

    const p = [5, 5, 9, 13]; // SMA(1) of 9 is 9. SMA(1) of 13 is 13.
    // config period=1 for simplicity.

    const config: CustomIndicatorConfig = {
      id: "test-crossover",
      name: "Test Cross",
      type: "SMA",
      parameters: { period: 1 },
      condition: "CrossOverAbove",
      threshold: 10,
    };

    // Evaluate at end (13). Prev was 9.
    // 9 <= 10 (True). 13 > 10 (True). -> BUY.
    const res = evaluateCustomIndicator(config, p, p, p, []);
    expect(res.value).toBe(13);
    expect(res.signal).toBe("BUY");
    expect(res.metadata?.prevValue).toBe(9);

    // Test No Crossover (Already above)
    const p2 = [5, 11, 13]; // Prev 11 (>10). Curr 13 (>10).
    const res2 = evaluateCustomIndicator(config, p2, p2, p2, []);
    expect(res2.signal).toBe("HOLD");
  });

  it("should detect CrossOverBelow", () => {
    // Threshold = 10.
    // Prev = 11. Curr = 9. -> CrossOverBelow.
    const p = [15, 11, 9];
    const config: CustomIndicatorConfig = {
      id: "test-crossover-below",
      name: "Test Cross Below",
      type: "SMA",
      parameters: { period: 1 },
      condition: "CrossOverBelow",
      threshold: 10,
    };

    const res = evaluateCustomIndicator(config, p, p, p, []);
    expect(res.value).toBe(9);
    // Signal is BUY because condition met (even if it's a bearish cross,
    // the "signal" field indicates condition met)
    expect(res.signal).toBe("BUY");
  });
});
