import { describe, expect, it } from "@jest/globals";
import { InstitutionalAccumulation } from "../src/whale-watch-models";
import { rankInstitutionalActivity } from "../src/whale-watch-utils";

const holding = (
  symbol: string,
  sharesHeld: number,
): InstitutionalAccumulation => ({
  symbol,
  institutionName: "Test Fund",
  sharesHeld,
  changeInShares: 0,
  percentChange: 0,
  positionValue: 0,
  reportDate: "2026-08-10",
});

describe("rankInstitutionalActivity", () => {
  it("ranks positive changes from the previous holdings snapshot", () => {
    const result = rankInstitutionalActivity(
      [holding("AAPL", 140), holding("MSFT", 230)],
      { AAPL: 100, MSFT: 200 },
    );

    expect(result.mode).toBe("accumulation");
    expect(result.topSymbols).toEqual([
      { symbol: "AAPL", score: 40 },
      { symbol: "MSFT", score: 30 },
    ]);
  });

  it("falls back to current holdings on the first snapshot", () => {
    const result = rankInstitutionalActivity([
      holding("AAPL", 100),
      holding("AAPL", 50),
      holding("MSFT", 120),
    ]);

    expect(result.mode).toBe("holdings");
    expect(result.topSymbols).toEqual([
      { symbol: "AAPL", score: 150 },
      { symbol: "MSFT", score: 120 },
    ]);
    expect(result.currentHoldings).toEqual({ AAPL: 150, MSFT: 120 });
  });

  it("uses holdings when no institution increased its position", () => {
    const result = rankInstitutionalActivity(
      [holding("AAPL", 90), holding("MSFT", 200)],
      { AAPL: 100, MSFT: 200 },
    );

    expect(result.mode).toBe("holdings");
    expect(result.topSymbols[0]).toEqual({ symbol: "MSFT", score: 200 });
  });
});
