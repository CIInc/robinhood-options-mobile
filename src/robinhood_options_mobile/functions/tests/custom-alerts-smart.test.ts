import { describe, it, expect } from "@jest/globals";
import { evaluateSmartAlert } from "../src/custom-alerts-cron";

describe("Smart custom alert evaluation", () => {
  it("triggers when all rules match", () => {
    const result = evaluateSmartAlert(
      {
        logic: "all",
        rules: [
          { type: "price", condition: "above", value: 100 },
          { type: "volatility", condition: "percent_change", value: 2 },
        ],
      },
      {
        currentPrice: 105,
        closes: [100, 101, 103, 104],
        volumes: [1000, 1100, 1200, 1300],
        percentChange: 3.5,
      }
    );

    expect(result.triggered).toBe(true);
    expect(result.message).toContain("Price");
  });

  it("triggers when any rule matches while respecting a single-rule fallback", () => {
    const result = evaluateSmartAlert(
      {
        logic: "any",
        rules: [
          { type: "price", condition: "above", value: 70 },
          { type: "moving_average", condition: "below", value: 95, period: 3 },
        ],
      },
      {
        currentPrice: 80,
        closes: [100, 99, 98, 97],
        volumes: [1000, 1200, 1250, 1100],
      }
    );

    expect(result.triggered).toBe(true);
    expect(result.message).toContain("Price");
  });

  it("falls back to legacy alert fields when no rules are stored", () => {
    const result = evaluateSmartAlert(
      {
        type: "price",
        condition: "below",
        value: 50,
      },
      {
        currentPrice: 45,
        closes: [60, 58, 57, 54],
        volumes: [2000, 2200, 2400, 2300],
      }
    );

    expect(result.triggered).toBe(true);
    expect(result.message).toContain("Price");
  });
});
