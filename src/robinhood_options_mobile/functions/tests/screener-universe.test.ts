import { HttpsError } from "firebase-functions/v2/https";
import {
  normalizeScreenerRecord,
  seedScreenerUniverseCall,
} from "../src/screener-universe";

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

describe("seedScreenerUniverseCall Security Checks", () => {
  it("rejects unauthenticated caller", async () => {
    const unauthenticatedRequest = {
      auth: null,
      data: {},
    };

    const callFn = () =>
      (seedScreenerUniverseCall as any).run(unauthenticatedRequest);

    await expect(callFn()).rejects.toThrow(HttpsError);
    await expect(callFn()).rejects.toMatchObject({
      code: "unauthenticated",
    });
  });

  it("rejects non-admin caller", async () => {
    const nonAdminRequest = {
      auth: { uid: "user123", token: { role: "user" } },
      data: {},
    };

    const callFn = () =>
      (seedScreenerUniverseCall as any).run(nonAdminRequest);

    await expect(callFn()).rejects.toThrow(HttpsError);
    await expect(callFn()).rejects.toMatchObject({
      code: "permission-denied",
    });
  });

  it("allows admin caller (fails at API key check)", async () => {
    const adminRequest = {
      auth: { uid: "admin123", token: { role: "admin" } },
      data: {},
    };

    const callFn = () =>
      (seedScreenerUniverseCall as any).run(adminRequest);

    // If TWELVE_DATA_API_KEY is not set in test environment,
    // it throws failed-precondition, which confirms authorization passed!
    await expect(callFn()).rejects.toMatchObject({
      code: "failed-precondition",
    });
  });
});
