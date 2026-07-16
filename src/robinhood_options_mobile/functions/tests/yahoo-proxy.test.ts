import { describe, it, expect } from "@jest/globals";
import { isAllowedYahooUrl } from "../src/yahoo-proxy";

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
