import { aggregateEquityCurves } from "../src/backtesting";

describe("aggregateEquityCurves", () => {
  it("correctly aggregates equity curves and missing timestamps", () => {
    const symbolCapital = 10000;
    const results = [
      {
        equityCurve: [
          { timestamp: "2025-01-01T10:00:00.000Z", equity: 10000 },
          { timestamp: "2025-01-01T11:00:00.000Z", equity: 10500 },
          { timestamp: "2025-01-01T12:00:00.000Z", equity: 10200 },
        ],
        buyAndHoldEquityCurve: [
          { timestamp: "2025-01-01T10:00:00.000Z", equity: 10000 },
          { timestamp: "2025-01-01T11:00:00.000Z", equity: 10100 },
          { timestamp: "2025-01-01T12:00:00.000Z", equity: 10050 },
        ],
      },
      {
        equityCurve: [
          { timestamp: "2025-01-01T10:00:00.000Z", equity: 10000 },
          { timestamp: "2025-01-01T10:30:00.000Z", equity: 9900 },
          { timestamp: "2025-01-01T12:00:00.000Z", equity: 10300 },
        ],
        buyAndHoldEquityCurve: [
          { timestamp: "2025-01-01T10:00:00.000Z", equity: 10000 },
          { timestamp: "2025-01-01T10:30:00.000Z", equity: 9950 },
          { timestamp: "2025-01-01T12:00:00.000Z", equity: 10200 },
        ],
      },
    ];

    const combined = aggregateEquityCurves(results, symbolCapital);

    expect(combined).toEqual([
      {
        timestamp: "2025-01-01T10:00:00.000Z",
        equity: 20000,
        buyAndHoldEquity: 20000,
      },
      {
        timestamp: "2025-01-01T10:30:00.000Z",
        equity: 19900,
        buyAndHoldEquity: 19950,
      },
      {
        timestamp: "2025-01-01T11:00:00.000Z",
        equity: 20400,
        buyAndHoldEquity: 20050,
      },
      {
        timestamp: "2025-01-01T12:00:00.000Z",
        equity: 20500,
        buyAndHoldEquity: 20250,
      },
    ]);
  });
});
