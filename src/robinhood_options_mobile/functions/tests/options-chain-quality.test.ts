import { describe, expect, test } from "@jest/globals";
import {
  hasUsableOptionsOpenInterest,
  YahooOptionsResult,
} from "../src/options-flow-utils";

describe("hasUsableOptionsOpenInterest", () => {
  test("rejects a sparse chain without open interest", () => {
    const chain: YahooOptionsResult = {
      options: [{
        calls: [{ strike: 100, openInterest: 0 }],
        puts: [{ strike: 95, openInterest: 0 }],
      }],
    };

    expect(hasUsableOptionsOpenInterest(chain)).toBe(false);
  });

  test("accepts open interest aggregated across expirations", () => {
    const chain: YahooOptionsResult = {
      options: [
        { calls: [{ strike: 100, openInterest: 250 }], puts: [] },
        { calls: [], puts: [{ strike: 95, openInterest: 300 }] },
      ],
    };

    expect(hasUsableOptionsOpenInterest(chain)).toBe(true);
  });
});
