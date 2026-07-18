import { describe, it, expect } from "@jest/globals";
import {
  cacheKey,
  cacheTtlSeconds,
  isAllowedYahooUrl,
} from "../src/yahoo-proxy";

describe("isAllowedYahooUrl", () => {
  it("accepts query1/query2 Yahoo Finance https URLs", () => {
    expect(
      isAllowedYahooUrl(
        "https://query2.finance.yahoo.com/v1/finance/search?q=ms",
      ),
    ).toBe(true);
    expect(
      isAllowedYahooUrl(
        "https://query1.finance.yahoo.com/v7/finance/quote?symbols=AAPL",
      ),
    ).toBe(true);
  });

  it("rejects other hosts, including lookalikes", () => {
    expect(isAllowedYahooUrl("https://finance.yahoo.com/")).toBe(false);
    expect(isAllowedYahooUrl("https://evil.com/steal")).toBe(false);
    expect(
      isAllowedYahooUrl("https://query2.finance.yahoo.com.evil.com/x"),
    ).toBe(false);
    expect(
      isAllowedYahooUrl("https://evil.com/query2.finance.yahoo.com"),
    ).toBe(false);
  });

  it("rejects non-https schemes and malformed URLs", () => {
    expect(
      isAllowedYahooUrl("http://query2.finance.yahoo.com/v1/finance/search"),
    ).toBe(false);
    expect(isAllowedYahooUrl("ftp://query2.finance.yahoo.com/")).toBe(false);
    expect(isAllowedYahooUrl("not a url")).toBe(false);
    expect(isAllowedYahooUrl("")).toBe(false);
  });
});

describe("cacheTtlSeconds", () => {
  const base = "https://query2.finance.yahoo.com";

  it("keeps quotes fresh and lookups long-lived", () => {
    expect(cacheTtlSeconds(`${base}/v7/finance/quote?symbols=AAPL`)).toBe(60);
    expect(
      cacheTtlSeconds(`${base}/v1/finance/search?q=ms`),
    ).toBe(86400);
    expect(
      cacheTtlSeconds(`${base}/v10/finance/quoteSummary/AAPL?modules=x`),
    ).toBe(86400);
  });

  it("uses medium TTLs for charts, chains, and screeners", () => {
    expect(
      cacheTtlSeconds(`${base}/v8/finance/chart/AAPL?range=1d`),
    ).toBe(300);
    expect(
      cacheTtlSeconds(`${base}/v7/finance/options/AAPL`),
    ).toBe(300);
    expect(
      cacheTtlSeconds(`${base}/v1/finance/screener/predefined/saved`),
    ).toBe(600);
  });

  it("falls back to a default for unknown or malformed paths", () => {
    expect(cacheTtlSeconds(`${base}/v1/test/getcrumb`)).toBe(300);
    expect(cacheTtlSeconds("not a url")).toBe(300);
  });
});

describe("cacheKey", () => {
  it("is stable, distinct per URL, and Firestore-id safe", () => {
    const a = cacheKey("https://query2.finance.yahoo.com/v1/finance/search?q=ms");
    const b = cacheKey("https://query2.finance.yahoo.com/v1/finance/search?q=m");
    expect(a).toBe(
      cacheKey("https://query2.finance.yahoo.com/v1/finance/search?q=ms"),
    );
    expect(a).not.toBe(b);
    expect(a).toMatch(/^[0-9a-f]{64}$/);
  });
});
