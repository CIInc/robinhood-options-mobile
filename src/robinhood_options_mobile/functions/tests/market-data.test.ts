import { describe, expect, test, jest } from "@jest/globals";
import { HttpsError } from "firebase-functions/v2/https";
import { fetchWithRetry } from "../src/utils";

// Mock node-fetch and utils to avoid actual network calls
jest.mock("node-fetch", () => ({
  __esModule: true,
  default: jest.fn(),
}));

jest.mock("../src/utils", () => ({
  fetchWithRetry: jest.fn(async () => ({
    ok: true,
    json: async () => ({
      AAPL: {
        symbol: "AAPL",
        close: "150.00",
        change: "1.50",
        percent_change: "1.0",
        volume: "1000000",
        high: "151.00",
        low: "149.00",
        open: "149.50",
        name: "Apple Inc.",
        timestamp: 1600000000,
      },
    }),
    text: async () =>
      "( {\"STATUS\": {\"ERROR_CODE\": \"0\"}, \"QUOTES\": {\"AAPL\": " +
      "{\"symbol\": \"AAPL\", \"last\": 150.0}}} )",
  })),
}));

// Mock firebase-admin/firestore lazy getter
jest.mock("firebase-admin/firestore", () => ({
  getFirestore: jest.fn(() => ({})),
}));

import {
  fetchFromTwelveData,
  getQuotesCall,
  isMarketDataCacheStale,
  normalizeMarketBars,
} from "../src/market-data";

const mockedFetchWithRetry = jest.mocked(fetchWithRetry);

describe("normalizeMarketBars", () => {
  test("keeps OHLCV values aligned when a bar has a missing close", () => {
    const result = normalizeMarketBars(
      [1_700_000_000, 1_700_086_400, 1_700_172_800],
      {
        open: [100, 101, 102],
        high: [101, 102, 103],
        low: [99, 100, 101],
        close: [100.5, null, 102.5],
        volume: [1_000, 2_000, null],
      },
    );

    expect(result).toEqual({
      timestamps: [1_700_000_000, 1_700_172_800],
      opens: [100, 102],
      highs: [101, 103],
      lows: [99, 101],
      closes: [100.5, 102.5],
      volumes: [1_000, 0],
    });
  });
});

describe("fetchFromTwelveData timestamps", () => {
  test.each([
    ["2026-11-09 15:15:00", "2026-11-09T15:15:00Z"],
    ["2026-10-30 14:15:00", "2026-10-30T14:15:00Z"],
  ])("parses UTC intraday bars for %s", async (datetime, expected) => {
    process.env.TWELVE_DATA_API_KEY = "test_key";
    mockedFetchWithRetry.mockImplementationOnce(async () => ({
      ok: true,
      json: async () => ({
        meta: {
          symbol: "AAPL",
          currency: "USD",
          exchange: "NASDAQ",
        },
        values: [{
          datetime,
          open: "100.00",
          high: "105.00",
          low: "99.00",
          close: "104.00",
          volume: "1234",
        }],
      }),
    } as any));

    const result = await fetchFromTwelveData("AAPL", "15m", "1d");

    expect(mockedFetchWithRetry).toHaveBeenCalledWith(
      expect.stringContaining("timezone=UTC")
    );
    expect(result.timestamp).toEqual([
      Math.floor(Date.parse(expected) / 1000),
    ]);
    expect(result.indicators.quote[0]).toEqual({
      open: [100],
      high: [105],
      low: [99],
      close: [104],
      volume: [1234],
    });
  });

  test("preserves daily date-only timestamps and OHLC values", async () => {
    process.env.TWELVE_DATA_API_KEY = "test_key";
    mockedFetchWithRetry.mockImplementationOnce(async () => ({
      ok: true,
      json: async () => ({
        meta: {
          symbol: "AAPL",
          currency: "USD",
          exchange: "NASDAQ",
        },
        values: [{
          datetime: "2026-11-09",
          open: "100.00",
          high: "105.00",
          low: "99.00",
          close: "104.00",
          volume: "1234",
        }],
      }),
    } as any));

    const result = await fetchFromTwelveData("AAPL", "1d", "1mo");

    expect(result.timestamp).toEqual([
      Math.floor(Date.parse("2026-11-09T00:00:00Z") / 1000),
    ]);
    expect(result.meta.currentTradingPeriod.regular.end).toBe(
      Math.floor(Date.parse("2026-11-09T00:00:00Z") / 1000)
    );
    expect(result.indicators.quote[0]).toEqual({
      open: [100],
      high: [105],
      low: [99],
      close: [104],
      volume: [1234],
    });
  });
});

describe("isMarketDataCacheStale", () => {
  test("treats fresh Twelve Data 1d cache within 15m cooldown as fresh", () => {
    const fridayBarSec = Math.floor(Date.parse("2026-11-20T00:00:00Z") / 1000);
    const cache = {
      updated: Date.parse("2026-11-23T14:30:49Z"),
      chart: {
        timestamp: [fridayBarSec],
      },
    };
    const now = new Date("2026-11-23T14:38:00Z");

    expect(isMarketDataCacheStale(cache, "1d", { now })).toBe(false);
  });

  test("marks prior-day 1d bar cached at 9:30 AM ET stale later in session",
    () => {
      const fridayBarSec = Math.floor(
        Date.parse("2026-11-20T00:00:00Z") / 1000
      );
      const cache = {
        updated: Date.parse("2026-11-23T14:30:49Z"),
        chart: {
          timestamp: [fridayBarSec],
          meta: {
            currentTradingPeriod: {
              regular: {
                end: Math.floor(Date.parse("2026-11-23T14:30:49Z") / 1000),
              },
            },
          },
        },
      };
      const now = new Date("2026-11-23T19:38:00Z");

      expect(isMarketDataCacheStale(cache, "1d", { now })).toBe(true);
    });

  test("refreshes intraday 1d cache once after 4:00 PM ET close", () => {
    const mondayBarSec = Math.floor(Date.parse("2026-11-23T00:00:00Z") / 1000);
    const preCloseCache = {
      updated: Date.parse("2026-11-23T19:00:00Z"),
      chart: { timestamp: [mondayBarSec] },
    };
    expect(
      isMarketDataCacheStale(preCloseCache, "1d", {
        now: new Date("2026-11-23T21:05:00Z"),
      })
    ).toBe(true);

    const postCloseCache = {
      updated: Date.parse("2026-11-23T21:05:00Z"),
      chart: { timestamp: [mondayBarSec] },
    };
    expect(
      isMarketDataCacheStale(postCloseCache, "1d", {
        now: new Date("2026-11-23T21:10:00Z"),
      })
    ).toBe(false);
  });
});

describe("getQuotesCall Security & Input Validation", () => {
  test("rejects unauthenticated request (null auth)", async () => {
    const request = {
      auth: null,
      data: { symbols: ["AAPL"] },
    };

    const callFn = () => (getQuotesCall as any).run(request);

    await expect(callFn()).rejects.toThrow(HttpsError);
    await expect(callFn()).rejects.toMatchObject({
      code: "unauthenticated",
    });
  });

  test("rejects unauthenticated request (missing uid in auth)", async () => {
    const request = {
      auth: { token: {} },
      data: { symbols: ["AAPL"] },
    };

    const callFn = () => (getQuotesCall as any).run(request);

    await expect(callFn()).rejects.toMatchObject({
      code: "unauthenticated",
    });
  });

  test("rejects missing or non-array symbols payload", async () => {
    const requestObject = {
      auth: { uid: "user123" },
      data: { symbols: "AAPL" },
    };

    const callFn = () => (getQuotesCall as any).run(requestObject);

    await expect(callFn()).rejects.toMatchObject({
      code: "invalid-argument",
    });
  });

  test("rejects empty symbols array", async () => {
    const requestEmpty = {
      auth: { uid: "user123" },
      data: { symbols: [] },
    };

    const callFn = () => (getQuotesCall as any).run(requestEmpty);

    await expect(callFn()).rejects.toMatchObject({
      code: "invalid-argument",
    });
  });

  test("rejects oversized symbols array (> 100 elements)", async () => {
    const oversizedSymbols = Array.from({ length: 101 }, (_, i) => `SYM${i}`);
    const requestOversized = {
      auth: { uid: "user123" },
      data: { symbols: oversizedSymbols },
    };

    const callFn = () => (getQuotesCall as any).run(requestOversized);

    await expect(callFn()).rejects.toMatchObject({
      code: "invalid-argument",
    });
  });

  test("rejects array containing non-string elements", async () => {
    const requestInvalidElements = {
      auth: { uid: "user123" },
      data: { symbols: ["AAPL", 123, null] },
    };

    const callFn = () => (getQuotesCall as any).run(requestInvalidElements);

    await expect(callFn()).rejects.toMatchObject({
      code: "invalid-argument",
    });
  });

  test("rejects array with strings exceeding 20 characters", async () => {
    const requestLongSymbol = {
      auth: { uid: "user123" },
      data: { symbols: ["VERYLONGSYMBOLNAMEEXCEEDINGLIMIT"] },
    };

    const callFn = () => (getQuotesCall as any).run(requestLongSymbol);

    await expect(callFn()).rejects.toMatchObject({
      code: "invalid-argument",
    });
  });

  test("accepts valid authenticated symbols request", async () => {
    process.env.TWELVE_DATA_API_KEY = "test_key";
    const validRequest = {
      auth: { uid: "user123" },
      data: { symbols: ["AAPL"] },
    };

    const result = await (getQuotesCall as any).run(validRequest);

    expect(result).toHaveProperty("AAPL");
    expect(result.AAPL.symbol).toBe("AAPL");
    expect(result.AAPL.last).toBe(150.0);
  });
});
