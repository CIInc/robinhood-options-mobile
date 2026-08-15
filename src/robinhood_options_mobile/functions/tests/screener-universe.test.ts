import { normalizeScreenerRecord } from "../src/screener-universe";

describe("normalizeScreenerRecord", () => {
  it("maps Twelve Data fields to screener fields", () => {
    const record = normalizeScreenerRecord(
      "aapl",
      {
        symbol: "AAPL",
        name: "Apple Inc.",
        exchange: "NASDAQ",
        sector: "Technology",
        industry: "Consumer Electronics",
      },
      {
        market_capitalization: "3000000000000",
        valuation_ratios: {
          trailing_pe: "30.5",
          price_to_book: "45.2",
        },
        dividends_and_splits: {
          trailing_annual_dividend_yield: "0.0045",
        },
        fifty_two_week: { high: "240", low: "160" },
      },
      { close: "220", average_volume: "50000000" },
    );

    expect(record).toEqual({
      symbol: "AAPL",
      name: "Apple Inc.",
      exchange: "NASDAQ",
      sector: "Technology",
      industry: "Consumer Electronics",
      marketCap: 3000000000000,
      peRatio: 30.5,
      pbRatio: 45.2,
      dividendYield: 0.0045,
      averageVolume: 50000000,
      high52Weeks: 240,
      low52Weeks: 160,
      price: 220,
    });
  });

  it("keeps a valid symbol when optional fundamentals are absent", () => {
    expect(normalizeScreenerRecord("MSFT", {}, {}, {})).toEqual({
      symbol: "MSFT",
      name: "MSFT",
      exchange: "",
      sector: "",
      industry: "",
    });
  });
});
