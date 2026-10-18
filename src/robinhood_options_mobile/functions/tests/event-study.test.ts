import { calculateEventStudy } from "../src/event-study";

/** Creates a compact chart fixture for the calculator test.
 * @param {number[]} closes Closing prices.
 * @return {object} Chart-shaped fixture.
 */
function data(closes: number[]) {
  return {
    timestamps: closes.map((_, index) => 1_700_000_000 + index * 86_400),
    closes,
  };
}

describe("calculateEventStudy", () => {
  it("calculates returns around the nearest trading date", () => {
    const result = calculateEventStudy(
      "ABC", "SPY", "Earnings", "2023-11-16", 1, 2,
      2,
      data([100, 98, 110, 112]), data([100, 99, 101, 102]),
    );

    expect(result.tradingEventDate).toBe("2023-11-16");
    expect(result.sampleSize).toBe(3);
    expect(result.eventDayAssetReturn).toBeCloseTo(0.1224, 3);
    expect(result.eventDayBenchmarkReturn).toBeCloseTo(0.0202, 3);
    expect(result.eventDayAbnormalReturn).toBeCloseTo(0.1022, 3);
    expect(result.cumulativeAssetReturn).toBeCloseTo(0.1428, 3);
    expect(result.cumulativeAbnormalReturn).toBeCloseTo(
      0.1125,
      3,
    );
    expect(result.points.map((point) => point.offset)).toEqual([-1, 0, 1]);
    expect(result.rollingWindow).toBe(2);
    expect(result.rollingStats).toHaveLength(2);
    expect(result.rollingStats[1].volatility).toBeGreaterThan(0);
    expect(result.rollingStats[1].beta).toBeGreaterThan(0);
    expect(result.rollingStats[1].correlation).toBeGreaterThan(0.9);
  });
});
