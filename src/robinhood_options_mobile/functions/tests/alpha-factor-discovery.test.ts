import {
  computeADXArrayLocal,
  computeCCIArrayLocal,
  computeMFIArrayLocal,
} from "../src/alpha-factor-discovery";

describe("Alpha Factor Discovery - Local Indicator Functions", () => {
  describe("computeCCIArrayLocal", () => {
    it("should return array of nulls if history is shorter than period", () => {
      const highs = [10, 11, 12];
      const lows = [8, 9, 10];
      const closes = [9, 10, 11];
      const result = computeCCIArrayLocal(highs, lows, closes, 5);

      expect(result).toHaveLength(3);
      expect(result.every((v) => v === null)).toBe(true);
    });

    it("should compute valid CCI values for standard price series", () => {
      // 10 periods of sample data
      const highs = [12, 13, 15, 14, 16, 17, 18, 17, 19, 20];
      const lows = [8, 9, 10, 10, 11, 12, 13, 12, 14, 15];
      const closes = [10, 11, 13, 12, 14, 15, 16, 14, 17, 18];
      const period = 5;

      const result = computeCCIArrayLocal(highs, lows, closes, period);

      expect(result).toHaveLength(10);
      // First period - 1 elements should be null
      for (let i = 0; i < period - 1; i++) {
        expect(result[i]).toBeNull();
      }
      // Subsequent elements should be numbers
      for (let i = period - 1; i < result.length; i++) {
        expect(typeof result[i]).toBe("number");
        expect(Number.isFinite(result[i])).toBe(true);
      }
    });

    it("should return 0 when mean deviation is 0 (flat prices)", () => {
      const highs = [10, 10, 10, 10, 10];
      const lows = [10, 10, 10, 10, 10];
      const closes = [10, 10, 10, 10, 10];

      const result = computeCCIArrayLocal(highs, lows, closes, 5);

      expect(result[4]).toBe(0);
    });
  });

  describe("computeADXArrayLocal", () => {
    it("should return nulls if history is shorter than period * 2", () => {
      const highs = [10, 11, 12, 13, 14];
      const lows = [8, 9, 10, 11, 12];
      const closes = [9, 10, 11, 12, 13];

      const result = computeADXArrayLocal(highs, lows, closes, 5);

      expect(result).toHaveLength(5);
      expect(result.every((v) => v === null)).toBe(true);
    });

    it("should compute valid ADX values for standard price series", () => {
      const n = 20;
      const period = 5;
      const highs = Array.from({ length: n }, (_, i) => 10 + i * 1.5 + (i % 2));
      const lows = Array.from({ length: n }, (_, i) => 8 + i * 1.5 - (i % 2));
      const closes = Array.from({ length: n }, (_, i) => 9 + i * 1.5);

      const result = computeADXArrayLocal(highs, lows, closes, period);

      expect(result).toHaveLength(n);
      const expectedPadding = 2 * period - 1;
      for (let i = 0; i < expectedPadding; i++) {
        expect(result[i]).toBeNull();
      }
      for (let i = expectedPadding; i < n; i++) {
        expect(typeof result[i]).toBe("number");
        expect(Number.isFinite(result[i])).toBe(true);
      }
    });
  });

  describe("computeMFIArrayLocal", () => {
    it("should return nulls if history is shorter than period + 1", () => {
      const highs = [10, 11, 12];
      const lows = [8, 9, 10];
      const closes = [9, 10, 11];
      const volumes = [1000, 1200, 1100];

      const result = computeMFIArrayLocal(
        highs, lows, closes, volumes, 5
      );

      expect(result).toHaveLength(3);
      expect(result.every((v) => v === null)).toBe(true);
    });

    it("should compute valid MFI values for standard prices & volumes", () => {
      const highs = [12, 13, 15, 14, 16, 17, 18, 17, 19, 20];
      const lows = [8, 9, 10, 10, 11, 12, 13, 12, 14, 15];
      const closes = [10, 11, 13, 12, 14, 15, 16, 14, 17, 18];
      const volumes = [
        1000, 1200, 1500, 800, 2000, 1800, 2200, 900, 2500, 3000,
      ];
      const period = 5;

      const result = computeMFIArrayLocal(
        highs, lows, closes, volumes, period
      );

      expect(result).toHaveLength(10);
      // First period elements should be null
      for (let i = 0; i < period; i++) {
        expect(result[i]).toBeNull();
      }
      // Subsequent elements should be MFI scores between 0 and 100
      for (let i = period; i < result.length; i++) {
        expect(typeof result[i]).toBe("number");
        expect(result[i]).toBeGreaterThanOrEqual(0);
        expect(result[i]).toBeLessThanOrEqual(100);
      }
    });

    it("should return 100 when negative money flow is 0", () => {
      const highs = [10, 12, 14, 16, 18, 20];
      const lows = [8, 10, 12, 14, 16, 18];
      const closes = [9, 11, 13, 15, 17, 19];
      const volumes = [100, 100, 100, 100, 100, 100];

      const result = computeMFIArrayLocal(highs, lows, closes, volumes, 3);

      expect(result[3]).toBe(100);
      expect(result[4]).toBe(100);
      expect(result[5]).toBe(100);
    });
  });
});
