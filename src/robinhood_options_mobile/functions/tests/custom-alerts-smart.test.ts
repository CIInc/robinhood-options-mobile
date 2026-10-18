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

  it("triggers when any rule matches with fallback", () => {
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

  it("triggers on GEX thresholds (Call Wall / Put Wall / Net GEX)", () => {
    const result = evaluateSmartAlert(
      {
        logic: "all",
        rules: [
          { type: "gex", condition: "above_call_wall", value: 0 },
          { type: "gex", condition: "net_gex_above", value: 50 },
        ],
      },
      {
        symbol: "NVDA",
        currentPrice: 130,
        gexData: {
          totalNetGEX: 75000000,
          callWall: 125,
          putWall: 110,
          gammaFlip: 120,
        },
      }
    );

    expect(result.triggered).toBe(true);
    expect(result.message).toContain("Call Wall");
    expect(result.message).toContain("Net GEX");
  });

  it("triggers on Dynamic Thresholds using ATR expansion", () => {
    const result = evaluateSmartAlert(
      {
        logic: "all",
        rules: [
          { type: "dynamic_threshold", condition: "above_band", value: 1.5 },
        ],
      },
      {
        symbol: "AAPL",
        currentPrice: 235,
        closes: [220, 222, 225, 228],
        atr: 3.0,
      }
    );

    expect(result.triggered).toBe(true);
    expect(result.message).toContain("upper dynamic band");
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
