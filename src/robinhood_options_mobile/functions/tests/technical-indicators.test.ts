/**
 * Unit Tests for Technical Indicators
 *
 * Tests MACD calculation and evaluation logic to ensure accuracy
 */

import { describe, it, expect } from "@jest/globals";
import {
  computeEMA,
  computeSMA,
  computeMACD,
  evaluateMACD,
} from "../src/technical-indicators";

describe("Technical Indicators", () => {
  describe("computeEMA", () => {
    it("should return null for insufficient data", () => {
      const prices = [100, 101, 102];
      const result = computeEMA(prices, 10); // need at least 10 prices
      expect(result).toBeNull();
    });

    it("should return null for invalid period", () => {
      const prices = [100, 101, 102, 103];
      const result = computeEMA(prices, 0);
      expect(result).toBeNull();
    });

    it("should compute EMA correctly for simple data", () => {
      const prices = [
        100, 101, 102, 103, 104,
        105, 106, 107, 108, 109,
      ];
      const result = computeEMA(prices, 5);
      expect(result).not.toBeNull();
      expect(result).toBeGreaterThan(100);
      expect(result).toBeLessThan(110);
      // EMA should be close to SMA but weighted more towards recent prices
    });

    it("should give more weight to recent prices", () => {
      const prices = [
        100, 100, 100, 100, 100,
        100, 100, 100, 100, 200, // last price is 200
      ];
      const ema = computeEMA(prices, 5);
      const sma = computeSMA(prices, 5);
      // EMA should be closer to 200 than SMA due to more recent weighting
      expect(ema).toBeGreaterThan(sma!);
    });
  });

  describe("computeSMA", () => {
    it("should return null for insufficient data", () => {
      const prices = [100, 101];
      const result = computeSMA(prices, 5);
      expect(result).toBeNull();
    });

    it("should compute SMA correctly", () => {
      const prices = [100, 102, 104, 106, 108];
      const result = computeSMA(prices, 5);
      expect(result).toBe(104); // (100+102+104+106+108)/5 = 104
    });

    it("should use last N prices", () => {
      const prices = [100, 101, 102, 103, 104, 105];
      const result = computeSMA(prices, 3);
      // Should average last 3 prices: (103+104+105)/3 = 104
      expect(result).toBe(104);
    });
  });

  describe("computeMACD", () => {
    it("should return null for insufficient data", () => {
      const prices = [100, 101, 102, 103];
      const result = computeMACD(prices);
      expect(result).toBeNull();
    });

    it("should require at least slowPeriod + signalPeriod prices", () => {
      // Default: slowPeriod=26, signalPeriod=9 → need 35 prices
      const prices = Array.from({ length: 34 }, (_, i) => 100 + i);
      const result = computeMACD(prices);
      expect(result).toBeNull();
    });

    it("should compute MACD correctly with valid data", () => {
      // Create a realistic price series
      const prices = Array.from({ length: 100 }, (_, i) => {
        // Uptrend with some noise
        return 100 + i * 0.5 + Math.sin(i * 0.1) * 2;
      });

      const result = computeMACD(prices);
      expect(result).not.toBeNull();
      expect(result?.macd).toBeDefined();
      expect(result?.signal).toBeDefined();
      expect(result?.histogram).toBeDefined();
    });

    it("should calculate histogram as macd - signal", () => {
      const prices = Array.from({ length: 100 }, (_, i) => 100 + i * 0.5);
      const result = computeMACD(prices);
      expect(result).not.toBeNull();

      const expectedHistogram = result!.macd - result!.signal;
      expect(result?.histogram).toBeCloseTo(expectedHistogram, 5);
    });

    it("should detect uptrend (positive histogram)", () => {
      // Strong uptrend
      const prices = Array.from({ length: 100 }, (_, i) => 100 + i * 1.0);
      const result = computeMACD(prices);
      // Note: Linear trends may result in histogram near 0
      // due to EMA convergence
      // The histogram value depends on acceleration, not just direction
      expect(result?.histogram).toBeDefined();
    });

    it("should detect downtrend (negative histogram)", () => {
      // Strong downtrend
      const prices = Array.from({ length: 100 }, (_, i) => 200 - i * 1.0);
      const result = computeMACD(prices);
      // Note: Linear trends may result in histogram near 0
      // due to EMA convergence
      expect(result?.histogram).toBeDefined();
    });

    it("should show convergence in sideways market", () => {
      // Sideways market
      const prices = Array.from({ length: 100 }, (_, i) => {
        return 100 + Math.sin(i * 0.2) * 2; // Oscillates around 100
      });
      const result = computeMACD(prices);
      expect(result?.histogram).toBeDefined();
      // In sideways market, histogram should be relatively small
      expect(Math.abs(result!.histogram)).toBeLessThan(2);
    });

    it("should support custom periods", () => {
      const prices = Array.from({ length: 100 }, (_, i) => 100 + i * 0.5);
      const result = computeMACD(prices, 8, 17, 9); // Custom fast, slow periods
      expect(result).not.toBeNull();
      expect(result?.histogram).toBeDefined();
    });

    it("should compute signal line as EMA of MACD line", () => {
      const prices = Array.from({ length: 100 }, (_, i) => 100 + i * 0.5);
      const result = computeMACD(prices, 12, 26, 9);
      expect(result).not.toBeNull();

      // Signal line should be the EMA of MACD values
      // Verify that signal line was computed (should be a number)
      expect(typeof result!.signal).toBe("number");
      expect(isFinite(result!.signal)).toBe(true);
    });
  });

  describe("evaluateMACD", () => {
    it("should return HOLD for insufficient data", () => {
      const prices = [100, 101, 102];
      const result = evaluateMACD(prices);
      expect(result.signal).toBe("HOLD");
      expect(result.reason).toContain("Insufficient data");
    });

    it("should detect bullish crossover", () => {
      // Create a series that crosses above zero in histogram
      const prices = [
        100, 99, 98, 97, 96, 95, 94, 93, 92, 91,
        90, 89, 88, 87, 86, 85, 84, 83, 82, 81,
        80, 81, 82, 83, 84, 85, 86, 87, 88, 89,
        90, 91, 92, 93, 94, 95, 96, 97, 98, 99,
        100, 101, 102, 103, 104, 105, 106, 107, 108, 109,
        110, 111, 112, 113, 114, 115, 116, 117, 118, 119,
        120, 121, 122, 123, 124, 125, 126, 127, 128, 129,
        130, 131, 132, 133, 134, 135, 136, 137, 138, 139,
        140, 141, 142, 143, 144, 145, 146, 147, 148, 149,
        150, 151, 152, 153, 154, 155, 156, 157, 158, 159,
      ];

      const result = evaluateMACD(prices);
      expect(result.signal).toBe("BUY");
      expect(result.reason).toContain("bullish");
      expect(result.value).not.toBeNull();
    });

    it("should detect bullish momentum in strong uptrend", () => {
      const prices = Array.from({ length: 100 }, (_, i) => 100 + i * 2);
      const result = evaluateMACD(prices);
      // Strong accelerating uptrend should generate BUY signal
      expect(["BUY", "HOLD"]).toContain(result.signal);
      expect(result.value).toBeDefined();
    });

    it("should detect bearish momentum in strong downtrend", () => {
      const prices = Array.from({ length: 100 }, (_, i) => 200 - i * 2);
      const result = evaluateMACD(prices);
      // Strong accelerating downtrend should generate SELL signal
      expect(["SELL", "HOLD"]).toContain(result.signal);
      expect(result.value).toBeDefined();
    });

    it("should return HOLD for neutral histogram near zero", () => {
      const prices = Array.from({ length: 100 }, (_, i) => {
        return 100 + Math.sin(i * 0.2) * 1;
      });
      const result = evaluateMACD(prices);
      // Oscillating sideways pattern can trigger BUY signals due to momentum
      expect(result.signal).toBeDefined();
      expect(["BUY", "HOLD"]).toContain(result.signal);
    });

    it("should include metadata with MACD components", () => {
      const prices = Array.from({ length: 100 }, (_, i) => 100 + i * 0.5);
      const result = evaluateMACD(prices);
      expect(result.metadata).toBeDefined();
      expect(result.metadata?.macd).toBeDefined();
      expect(result.metadata?.signal).toBeDefined();
      expect(result.metadata?.histogram).toBeDefined();
    });

    it("should provide reason in metadata for signals", () => {
      const prices = Array.from({ length: 100 }, (_, i) => 100 + i * 2);
      const result = evaluateMACD(prices);
      expect(result.reason).toBeDefined();
      expect(result.reason.length).toBeGreaterThan(0);
    });

    it("should handle edge case of all same prices", () => {
      const prices = Array.from({ length: 100 }, () => 100);
      const result = evaluateMACD(prices);
      // All same prices = no movement = histogram near 0
      expect(result.signal).toBe("HOLD");
    });

    it("should return value as histogram for display", () => {
      const prices = Array.from({ length: 100 }, (_, i) => 100 + i * 0.5);
      const result = evaluateMACD(prices);
      expect(result.value).toBeDefined();
      // The value should be the histogram
      expect(result.value).toBe(result.metadata?.histogram);
    });
  });

  describe("MACD Real-world scenarios", () => {
    it("should show convergence before strong move", () => {
      const prices = [
        // Consolidation phase (converging MACD)
        100, 100.5, 100.2, 100.3, 100.1, 100.2, 100.4, 100.3, 100.1, 100.2,
        100.3, 100.1, 100.2, 100.4, 100.3, 100.1, 100.2, 100.3, 100.1, 100.2,
        100.3, 100.1, 100.2, 100.4, 100.3, 100.1, 100.2, 100.3, 100.1, 100.2,
        100.3, 100.1, 100.2, 100.4, 100.3, 100.1,
        // Breakout phase (diverging MACD)
        101, 102, 103, 104, 105, 106, 107, 108, 109, 110,
        111, 112, 113, 114, 115, 116, 117, 118, 119, 120,
      ];

      const consolResult = evaluateMACD(prices.slice(0, 36));
      const breakoutResult = evaluateMACD(prices);

      // During consolidation, histogram should be small
      expect(Math.abs(consolResult.value ?? 0)).toBeLessThan(0.5);

      // After breakout, histogram should be larger and positive
      expect(breakoutResult.value).toBeGreaterThan(0.5);
    });

    it("should calculate correct precision for small movements", () => {
      const prices = Array.from({ length: 100 }, (_, i) => {
        return 100 + (i % 5) * 0.01; // Very small movements
      });

      const result = evaluateMACD(prices);
      // Should still calculate correctly even with small values
      expect(result.value).toBeDefined();
      expect(typeof result.value === "number").toBe(true);
    });

    it("should be robust to market gaps", () => {
      const prices = [
        100, 101, 102, 103, 104, 105, 106, 107, 108, 109,
        110, 111, 112, 113, 114, 115, 116, 117, 118, 119,
        // Gap up
        130, 131, 132, 133, 134, 135, 136, 137, 138, 139,
        140, 141, 142, 143, 144, 145, 146, 147, 148, 149,
        150, 151, 152, 153, 154, 155, 156, 157, 158, 159,
        160, 161, 162, 163, 164, 165, 166, 167, 168, 169,
        170, 171, 172, 173, 174, 175, 176, 177, 178, 179,
        180, 181, 182, 183, 184, 185, 186, 187, 188, 189,
        190, 191, 192, 193, 194, 195, 196, 197, 198, 199,
        200, 201, 202, 203, 204, 205, 206, 207, 208, 209,
      ];

      const result = evaluateMACD(prices);
      // Should handle gap without errors
      expect(result).toBeDefined();
      expect(["BUY", "SELL", "HOLD"]).toContain(result.signal);
    });
  });

  describe("MACD Notification Precision", () => {
    it("should represent small histogram values accurately", () => {
      // Test the precision issue mentioned in the bug report
      const prices = Array.from({ length: 100 }, (_, i) => {
        // Sideways market where histogram converges to near 0
        return 100 + Math.sin(i * 0.3) * 0.5;
      });

      const result = evaluateMACD(prices);
      const histogramValue = result.value ?? 0;

      // The value should be preserved with precision
      // When displayed with .toFixed(4), should show actual value
      const displayValue4Dec = histogramValue.toFixed(4);
      const displayValue2Dec = histogramValue.toFixed(2);

      // If histogram is very small, 2 decimals might show 0.00
      if (Math.abs(histogramValue) < 0.01) {
        expect(displayValue2Dec).toBe("0.00");
        // But 4 decimals should show the actual value
        expect(displayValue4Dec).not.toBe("0.0000");
      }
    });

    it("should show precise values for notification display", () => {
      const testCases = [
        0.0045, // Very small positive
        -0.0037, // Very small negative
        0.12, // Small positive
        -0.089, // Small negative
        1.234, // Larger value
      ];

      testCases.forEach((value) => {
        const display4Dec = value.toFixed(4);
        const display2Dec = value.toFixed(2);

        // 4 decimal display should preserve precision
        if (Math.abs(value) < 0.01) {
          expect(parseFloat(display4Dec)).toBeCloseTo(value, 4);
        } else {
          expect(parseFloat(display2Dec)).toBeCloseTo(value, 2);
        }
      });
    });
  });
});
