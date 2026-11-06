import {
  classifyMarketRegime,
  computeRegimeAttribution,
  computeWalkForwardValidation,
  MarketRegimeType,
} from "../src/backtesting";

describe("classifyMarketRegime", () => {
  it("classifies Bull Low-Vol when price >= SMA and NATR < threshold", () => {
    const regime = classifyMarketRegime(100, 95, 0.95, 1.15);
    expect(regime).toBe<MarketRegimeType>("BULL_LOW_VOL");
  });

  it("classifies Bull High-Vol when price >= SMA and NATR >= threshold", () => {
    const regime = classifyMarketRegime(100, 95, 1.45, 1.15);
    expect(regime).toBe<MarketRegimeType>("BULL_HIGH_VOL");
  });

  it("classifies Bear Low-Vol when price < SMA and NATR < threshold", () => {
    const regime = classifyMarketRegime(90, 95, 0.85, 1.15);
    expect(regime).toBe<MarketRegimeType>("BEAR_LOW_VOL");
  });

  it("classifies Bear High-Vol when price < SMA and NATR >= threshold", () => {
    const regime = classifyMarketRegime(90, 95, 1.85, 1.15);
    expect(regime).toBe<MarketRegimeType>("BEAR_HIGH_VOL");
  });
});

describe("computeRegimeAttribution", () => {
  it("accurately attributes P&L and win counts by entry regime", () => {
    const trades = [
      // Trade 1: Bull Low-Vol, Win ($100 to $110, qty 10 -> +$100)
      {
        timestamp: "2026-01-01T10:00:00Z",
        action: "BUY",
        symbol: "SPY",
        price: 100,
        quantity: 10,
        commission: 0,
        reason: "Signal Entry",
        signalData: null,
        entryRegime: "BULL_LOW_VOL" as MarketRegimeType,
      },
      {
        timestamp: "2026-01-02T10:00:00Z",
        action: "SELL",
        symbol: "SPY",
        price: 110,
        quantity: 10,
        commission: 0,
        reason: "Take Profit",
        signalData: null,
        entryRegime: "BULL_LOW_VOL" as MarketRegimeType,
      },
      // Trade 2: Bull Low-Vol, Loss ($110 to $105, qty 10 -> -$50)
      {
        timestamp: "2026-01-03T10:00:00Z",
        action: "BUY",
        symbol: "SPY",
        price: 110,
        quantity: 10,
        commission: 0,
        reason: "Signal Entry",
        signalData: null,
        entryRegime: "BULL_LOW_VOL" as MarketRegimeType,
      },
      {
        timestamp: "2026-01-04T10:00:00Z",
        action: "SELL",
        symbol: "SPY",
        price: 105,
        quantity: 10,
        commission: 0,
        reason: "Stop Loss",
        signalData: null,
        entryRegime: "BULL_LOW_VOL" as MarketRegimeType,
      },
      // Trade 3: Bear High-Vol, Win ($90 to $95, qty 20 -> +$100)
      {
        timestamp: "2026-01-05T10:00:00Z",
        action: "BUY",
        symbol: "SPY",
        price: 90,
        quantity: 20,
        commission: 0,
        reason: "Signal Entry",
        signalData: null,
        entryRegime: "BEAR_HIGH_VOL" as MarketRegimeType,
      },
      {
        timestamp: "2026-01-06T10:00:00Z",
        action: "SELL",
        symbol: "SPY",
        price: 95,
        quantity: 20,
        commission: 0,
        reason: "Take Profit",
        signalData: null,
        entryRegime: "BEAR_HIGH_VOL" as MarketRegimeType,
      },
    ];

    const result = computeRegimeAttribution(trades, 10000);

    const bullLow = result["BULL_LOW_VOL"];
    expect(bullLow.tradeCount).toBe(2);
    expect(bullLow.winCount).toBe(1);
    expect(bullLow.lossCount).toBe(1);
    expect(bullLow.winRate).toBe(0.5);
    expect(bullLow.winRatePercent).toBe(50);
    expect(bullLow.netProfit).toBe(50);
    expect(bullLow.profitFactor).toBe(2.0); // 100 / 50
    expect(bullLow.averageProfit).toBe(25);

    const bearHigh = result["BEAR_HIGH_VOL"];
    expect(bearHigh.tradeCount).toBe(1);
    expect(bearHigh.winCount).toBe(1);
    expect(bearHigh.lossCount).toBe(0);
    expect(bearHigh.winRatePercent).toBe(100);
    expect(bearHigh.netProfit).toBe(100);
    expect(bearHigh.profitFactor).toBe(999);

    const bearLow = result["BEAR_LOW_VOL"];
    expect(bearLow.tradeCount).toBe(0);
    expect(bearLow.netProfit).toBe(0);
  });
});

describe("computeWalkForwardValidation", () => {
  it("returns INSUFFICIENT_DATA when trade count is below threshold", () => {
    const trades = [
      {
        timestamp: "2026-01-01T10:00:00Z",
        action: "BUY",
        symbol: "SPY",
        price: 100,
        quantity: 10,
        commission: 0,
        reason: "Entry",
        signalData: null,
      },
      {
        timestamp: "2026-01-02T10:00:00Z",
        action: "SELL",
        symbol: "SPY",
        price: 105,
        quantity: 10,
        commission: 0,
        reason: "Exit",
        signalData: null,
      },
    ];
    const wf = computeWalkForwardValidation(trades, 10000);
    expect(wf.stabilityScore).toBe("INSUFFICIENT_DATA");
  });

  it("evaluates robust walk-forward validation when OOS holds", () => {
    const trades: any[] = [];
    // Generate 10 winning trades across time
    for (let i = 1; i <= 10; i++) {
      trades.push({
        timestamp: `2026-01-${i < 10 ? "0" + i : i}T10:00:00Z`,
        action: "BUY",
        symbol: "SPY",
        price: 100,
        quantity: 10,
        commission: 0,
        reason: "Entry",
        signalData: null,
      });
      trades.push({
        timestamp: `2026-01-${i < 10 ? "0" + i : i}T15:00:00Z`,
        action: "SELL",
        symbol: "SPY",
        price: 105,
        quantity: 10,
        commission: 0,
        reason: "Exit",
        signalData: null,
      });
    }

    const wf = computeWalkForwardValidation(trades, 10000, 0.7);
    expect(wf.inSample.totalTrades).toBe(7);
    expect(wf.outOfSample.totalTrades).toBe(3);
    expect(wf.inSample.winRate).toBe(1.0);
    expect(wf.outOfSample.winRate).toBe(1.0);
    expect(wf.stabilityScore).toBe("ROBUST");
  });

  it("detects OVERFITTED when out-of-sample performance collapses", () => {
    const trades: any[] = [];
    // In-Sample: 7 winning trades
    for (let i = 1; i <= 7; i++) {
      trades.push({
        timestamp: `2026-01-0${i}T10:00:00Z`,
        action: "BUY",
        symbol: "SPY",
        price: 100,
        quantity: 10,
        commission: 0,
        reason: "Entry",
        signalData: null,
      });
      trades.push({
        timestamp: `2026-01-0${i}T15:00:00Z`,
        action: "SELL",
        symbol: "SPY",
        price: 110,
        quantity: 10,
        commission: 0,
        reason: "Exit",
        signalData: null,
      });
    }
    // Out-of-Sample: 3 losing trades (steep collapse)
    for (let i = 8; i <= 10; i++) {
      trades.push({
        timestamp: `2026-01-${i < 10 ? "0" + i : i}T10:00:00Z`,
        action: "BUY",
        symbol: "SPY",
        price: 100,
        quantity: 10,
        commission: 0,
        reason: "Entry",
        signalData: null,
      });
      trades.push({
        timestamp: `2026-01-${i < 10 ? "0" + i : i}T15:00:00Z`,
        action: "SELL",
        symbol: "SPY",
        price: 80,
        quantity: 10,
        commission: 0,
        reason: "Exit",
        signalData: null,
      });
    }

    const wf = computeWalkForwardValidation(trades, 10000, 0.7);
    expect(wf.inSample.totalReturn).toBe(700); // 7 * $100
    expect(wf.outOfSample.totalReturn).toBe(-600); // 3 * -$200
    expect(wf.stabilityScore).toBe("OVERFITTED");
  });
});
