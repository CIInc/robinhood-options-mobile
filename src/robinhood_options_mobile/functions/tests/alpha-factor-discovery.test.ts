import {
  calculateCorrelation,
  computeCCIArrayLocal,
  computeMFIArrayLocal,
  computeWilliamsRArrayLocal,
  discoverAlphaFactors,
} from "../src/alpha-factor-discovery";

describe("discoverAlphaFactors input validation", () => {
  const sampleFactor = {
    id: "f1",
    name: "RSI",
    type: "RSI",
    parameters: { period: 14 },
  };

  test("rejects unauthenticated request", async () => {
    const request = {
      auth: null,
      data: { factors: [sampleFactor] },
    };

    await expect(
      (discoverAlphaFactors as any).run(request)
    ).rejects.toMatchObject({
      code: "unauthenticated",
    });
  });

  test("rejects missing or empty factors", async () => {
    const request = {
      auth: { uid: "user1" },
      data: { factors: [] },
    };

    await expect(
      (discoverAlphaFactors as any).run(request)
    ).rejects.toMatchObject({
      code: "invalid-argument",
    });
  });

  test("rejects factors with more than 50 configurations", async () => {
    const factors = Array.from({ length: 51 }, (_, i) => ({
      id: `f${i}`,
      name: `RSI_${i}`,
      type: "RSI",
      parameters: { period: 14 },
    }));

    const request = {
      auth: { uid: "user1" },
      data: { factors },
    };

    await expect(
      (discoverAlphaFactors as any).run(request)
    ).rejects.toMatchObject({
      code: "invalid-argument",
    });
  });

  test("rejects invalid forwardHorizon", async () => {
    const request = {
      auth: { uid: "user1" },
      data: {
        factors: [sampleFactor],
        forwardHorizon: -5,
      },
    };

    await expect(
      (discoverAlphaFactors as any).run(request)
    ).rejects.toMatchObject({
      code: "invalid-argument",
    });
  });

  test("rejects invalid or empty symbols list", async () => {
    const request = {
      auth: { uid: "user1" },
      data: {
        factors: [sampleFactor],
        symbols: ["   ", ""],
      },
    };

    await expect(
      (discoverAlphaFactors as any).run(request)
    ).rejects.toMatchObject({
      code: "invalid-argument",
    });
  });
});

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

  describe("calculateCorrelation", () => {
    it("should compute exact correlation and count without indices", () => {
      const x = [1, 2, 3, 4, 5];
      const y = [2, 4, 6, 8, 10]; // Perfect positive correlation r = 1.0

      const result = calculateCorrelation(x, y);

      expect(result.correlation).toBeCloseTo(1.0, 5);
      expect(result.count).toBe(5);
    });

    it("should compute correlation and count over a subset of indices", () => {
      const x = [100, 1, 2, 3, 4, 5, 200];
      const y = [-50, 2, 4, 6, 8, 10, 300];
      const validIndices = [1, 2, 3, 4, 5]; // Subset ignoring outer noise

      const result = calculateCorrelation(x, y, validIndices);

      expect(result.correlation).toBeCloseTo(1.0, 5);
      expect(result.count).toBe(5);
    });

    it("should filter out null and NaN values correctly", () => {
      const x = [1, null, 3, 4, NaN, 6];
      const y = [10, 20, 30, null, 50, 60];

      const result = calculateCorrelation(x, y);

      // Valid pairs: (1,10), (3,30), (6,60) => r = 1.0, count = 3
      expect(result.correlation).toBeCloseTo(1.0, 5);
      expect(result.count).toBe(3);
    });

    it("should return null correlation when < 2 valid pairs exist", () => {
      const x = [1, null, null];
      const y = [10, 20, 30];

      const result = calculateCorrelation(x, y);

      expect(result.correlation).toBeNull();
      expect(result.count).toBe(1);
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

  describe("computeWilliamsRArrayLocal", () => {
    it("should return nulls if history is shorter than period", () => {
      const highs = [10, 11, 12];
      const lows = [8, 9, 10];
      const closes = [9, 10, 11];
      const period = 5;

      const result = computeWilliamsRArrayLocal(highs, lows, closes, period);

      expect(result).toEqual([null, null, null]);
    });

    it("should compute exact Williams %R values for standard prices", () => {
      const highs = [15, 17, 16, 18, 19, 21, 20];
      const lows = [10, 12, 11, 13, 14, 15, 16];
      const closes = [12, 14, 13, 16, 18, 19, 17];
      const period = 5;

      const result = computeWilliamsRArrayLocal(highs, lows, closes, period);

      expect(result).toHaveLength(7);
      // First (period - 1) items should be null
      expect(result[0]).toBeNull();
      expect(result[1]).toBeNull();
      expect(result[2]).toBeNull();
      expect(result[3]).toBeNull();

      // At index 4: window is indices [0..4]
      // highs: [15, 17, 16, 18, 19] => max = 19
      // lows: [10, 12, 11, 13, 14] => min = 10
      // close: closes[4] = 18
      // %R = ((19 - 18) / (19 - 10)) * -100 = (1 / 9) * -100 = -11.1111...
      expect(result[4]).toBeCloseTo(((19 - 18) / (19 - 10)) * -100, 4);

      // At index 5: window is indices [1..5]
      // highs: [17, 16, 18, 19, 21] => max = 21
      // lows: [12, 11, 13, 14, 15] => min = 11
      // close: closes[5] = 19
      // %R = ((21 - 19) / (21 - 11)) * -100 = (2 / 10) * -100 = -20
      expect(result[5]).toBeCloseTo(-20, 4);

      // At index 6: window is indices [2..6]
      // highs: [16, 18, 19, 21, 20] => max = 21
      // lows: [11, 13, 14, 15, 16] => min = 11
      // close: closes[6] = 17
      // %R = ((21 - 17) / (21 - 11)) * -100 = (4 / 10) * -100 = -40
      expect(result[6]).toBeCloseTo(-40, 4);
    });

    it("should return 0 when highest equals lowest (zero range)", () => {
      const highs = [10, 10, 10, 10, 10];
      const lows = [10, 10, 10, 10, 10];
      const closes = [10, 10, 10, 10, 10];

      const result = computeWilliamsRArrayLocal(highs, lows, closes, 5);

      expect(result[4]).toBe(0);
    });
  });
});
