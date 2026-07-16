import { describe, it, expect } from "@jest/globals";
import {
  computePaperAccountEquity,
  isTradingDay,
} from "../src/paper-trading-utils";

describe("isTradingDay", () => {
  it("accepts weekdays in Eastern Time", () => {
    // 2026-07-15 is a Wednesday.
    expect(isTradingDay(new Date("2026-07-15T20:30:00Z"))).toBe(true);
  });

  it("rejects Saturday and Sunday in Eastern Time", () => {
    // 2026-07-18 is a Saturday, 2026-07-19 a Sunday.
    expect(isTradingDay(new Date("2026-07-18T20:30:00Z"))).toBe(false);
    expect(isTradingDay(new Date("2026-07-19T20:30:00Z"))).toBe(false);
  });

  it("uses the exchange time zone, not UTC", () => {
    // 01:00 UTC Saturday is still 21:00 Friday in New York.
    expect(isTradingDay(new Date("2026-07-18T01:00:00Z"))).toBe(true);
  });
});

describe("computePaperAccountEquity", () => {
  it("returns cash for an empty account", () => {
    expect(computePaperAccountEquity({ cashBalance: 100000 }, {})).toBe(
      100000,
    );
  });

  it("values long stock at the live price with entry fallback", () => {
    const data = {
      cashBalance: 1000,
      positions: [
        {
          quantity: 10,
          average_buy_price: 100,
          instrumentObj: { symbol: "AAPL" },
        },
        {
          quantity: 5,
          average_buy_price: 50,
          instrumentObj: { symbol: "NOQUOTE" },
        },
      ],
    };
    // AAPL priced live at 110; NOQUOTE falls back to its entry price.
    expect(computePaperAccountEquity(data, { AAPL: 110 })).toBe(
      1000 + 10 * 110 + 5 * 50,
    );
  });

  it("values short stock as a negative position", () => {
    const data = {
      cashBalance: 101500, // includes 1,500 short proceeds
      positions: [
        {
          quantity: -10,
          average_buy_price: 150,
          instrumentObj: { symbol: "AAPL" },
        },
      ],
    };
    // Flat at entry: proceeds offset the liability.
    expect(computePaperAccountEquity(data, { AAPL: 150 })).toBe(100000);
    // Price falls: the short gains value.
    expect(computePaperAccountEquity(data, { AAPL: 140 })).toBe(100100);
  });

  it("subtracts written (credit) option positions as liabilities", () => {
    const data = {
      cashBalance: 100500, // includes the 500 premium
      optionPositions: [
        {
          quantity: 1,
          direction: "credit",
          average_open_price: 5.0,
        },
      ],
    };
    // Written put valued at its open premium: equity is flat at open.
    expect(computePaperAccountEquity(data, {})).toBe(100000);
  });

  it("adds long option positions at the mark with premium fallback", () => {
    const data = {
      cashBalance: 99500,
      optionPositions: [
        {
          quantity: 1,
          direction: "debit",
          average_open_price: 5.0,
          optionInstrument: {
            optionMarketData: { adjustedMarkPrice: 6.5 },
          },
        },
      ],
    };
    expect(computePaperAccountEquity(data, {})).toBe(99500 + 650);
  });

  it("includes futures open P&L", () => {
    const data = {
      cashBalance: 100000,
      futuresPositions: [
        {
          quantity: 2,
          avgPrice: 5000,
          lastPrice: 5010,
          multiplier: 50,
        },
        {
          quantity: -1,
          avgPrice: 5000,
          lastPrice: 5010,
          multiplier: 50,
        },
      ],
    };
    // Long: +2x10x50 = 1000; short: -1x10x50 = -500.
    expect(computePaperAccountEquity(data, {})).toBe(100000 + 1000 - 500);
  });

  it("handles a mixed account", () => {
    const data = {
      cashBalance: 50000,
      positions: [
        { quantity: 100, average_buy_price: 140,
          instrumentObj: { symbol: "AAPL" } },
        { quantity: -10, average_buy_price: 200,
          instrumentObj: { symbol: "TSLA" } },
      ],
      optionPositions: [
        { quantity: 1, direction: "credit", average_open_price: 3.0 },
        { quantity: 2, direction: "debit", average_open_price: 2.0 },
      ],
      futuresPositions: [
        { quantity: 1, avgPrice: 100, lastPrice: 105, multiplier: 10 },
      ],
    };
    const expected =
      50000 +
      100 * 150 + // AAPL long at live price
      -10 * 195 + // TSLA short at live price
      -1 * 3.0 * 100 + // written call liability
      2 * 2.0 * 100 + // long options at premium fallback
      1 * 5 * 10; // futures open P&L
    expect(
      computePaperAccountEquity(data, { AAPL: 150, TSLA: 195 }),
    ).toBe(expected);
  });
});
