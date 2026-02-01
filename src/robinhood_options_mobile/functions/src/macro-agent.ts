import * as logger from "firebase-functions/logger";
import { onCall } from "firebase-functions/v2/https";
import { getMarketData } from "./market-data";
import { computeSMA } from "./technical-indicators";

export interface MacroAssessment {
  status: "RISK_ON" | "RISK_OFF" | "NEUTRAL";
  score: number; // 0 to 100, where 100 is max bullish/risk-on
  indicators: {
    vix: {
      value: number | null;
      signal: "BULLISH" | "BEARISH" | "NEUTRAL";
      trend: string;
    };
    tnx: {
      value: number | null;
      signal: "BULLISH" | "BEARISH" | "NEUTRAL";
      trend: string;
    };
    marketTrend: {
      value: number | null;
      signal: "BULLISH" | "BEARISH" | "NEUTRAL";
      trend: string;
    };
    yieldCurve: {
      value: number | null; // Spread (10Y - 13W)
      signal: "BULLISH" | "BEARISH" | "NEUTRAL";
      trend: string;
    };
    gold: {
      value: number | null;
      signal: "BULLISH" | "BEARISH" | "NEUTRAL";
      trend: string;
    };
    oil: {
      value: number | null;
      signal: "BULLISH" | "BEARISH" | "NEUTRAL";
      trend: string;
    };
    dxy: {
      value: number | null;
      signal: "BULLISH" | "BEARISH" | "NEUTRAL";
      trend: string;
    };
    btc: {
      value: number | null;
      signal: "BULLISH" | "BEARISH" | "NEUTRAL";
      trend: string;
    };
    hyg: {
      value: number | null;
      signal: "BULLISH" | "BEARISH" | "NEUTRAL";
      trend: string;
    };
  };
  sectorRotation: {
    bullish: string[];
    bearish: string[];
  };
  assetAllocation: {
    equity: string;
    fixedIncome: string;
    cash: string;
    commodities: string;
  };
  reason: string;
  timestamp: number;
}

/**
 * Macro Agent
 *
 * Evaluates macroeconomic conditions to adjust trading risk profiles.
 * Currently uses:
 * - VIX (Volatility Index): High VIX (>20) -> Risk Off,
 *   Low VIX (<15) -> Risk On
 * - TNX (10-Year Treasury Yield): Rapidly rising yields
 *   -> Risk Off for Equities
 * - SPY (Market Trend): Above 200 SMA -> Risk On
 * - Yield Curve (10Y - 13W): Inverted -> Risk Off (Recession Warning)
 */
export async function getMacroAssessment(): Promise<MacroAssessment> {
  try {
    // Fetch VIX, TNX, SPY, and IRX (13 Week T-Bill)
    // We use "1d" interval and "1y" range to calculate SMAs
    // Also adding GLD (Gold) and USO (Oil) for broader context
    // Fetch VIX, TNX, SPY, IRX, GLD, USO, BTC, DXY
    // We use "1d" interval and "1y" range to calculate SMAs
    const [
      vixData, tnxData, spyData, irxData, gldData, usoData, btcData,
      dxyData, hygData,
    ] = await Promise.all([
      getMarketData("^VIX", 5, 20, "1d", "1y").catch((e) => {
        logger.error("Failed to fetch VIX data", e);
        return null;
      }),
      getMarketData("^TNX", 10, 50, "1d", "1y").catch((e) => {
        logger.error("Failed to fetch TNX data", e);
        return null;
      }),
      getMarketData("SPY", 50, 200, "1d", "1y").catch((e) => {
        logger.error("Failed to fetch SPY data", e);
        return null;
      }),
      // High freq not needed, just price
      getMarketData("^IRX", 1, 1, "1d", "1y").catch((e) => {
        logger.error("Failed to fetch IRX data", e);
        return null;
      }),
      getMarketData("GLD", 50, 200, "1d", "1y").catch((e) => {
        logger.error("Failed to fetch GLD data", e);
        return null;
      }),
      getMarketData("USO", 50, 200, "1d", "1y").catch((e) => {
        logger.error("Failed to fetch USO data", e);
        return null;
      }),
      getMarketData("BTC-USD", 50, 200, "1d", "1y").catch((e) => {
        logger.error("Failed to fetch BTC data", e);
        return null;
      }),
      // dx-y.nyb often fails, check if empty and fallback to DX=F
      getMarketData("DX-Y.NYB", 50, 200, "1d", "1y")
        .then((data) => {
          if (data && data.closes && data.closes.length > 0) return data;
          logger.info("DX-Y.NYB returned no data, falling back to DX=F");
          return getMarketData("DX=F", 50, 200, "1d", "1y");
        })
        .catch((e) => {
          logger.error("Failed to fetch DXY data", e);
          return null;
        }),
      getMarketData("HYG", 50, 200, "1d", "1y").catch((e) => {
        logger.error("Failed to fetch HYG data", e);
        return null;
      }),
    ]);

    let score = 50; // Start at neutral
    const explanation: string[] = [];

    // 1. Evaluate VIX
    // ... (rest of logic)


    // Unpack data
    // vixData is 0, tnxData 1, spyData 2, irxData 3, gldData 4, usoData 5,
    // btcData 6, dxyData 7, hygData 8
    // const hygData = ... (removed manual extraction, now in destructuring)
    let vixSignal: "BULLISH" | "BEARISH" | "NEUTRAL" = "NEUTRAL";
    let vixTrend = "Flat";
    let vixValue: number | null = null;

    if (vixData && vixData.closes && vixData.closes.length > 0) {
      vixValue = vixData.currentPrice ||
        vixData.closes[vixData.closes.length - 1];
      if (vixValue !== null) {
        if (vixValue < 15) {
          vixSignal = "BULLISH";
          score += 15;
          explanation.push(`VIX is low (${vixValue.toFixed(2)}), ` +
            "suggesting complacency.");
        } else if (vixValue > 25) {
          vixSignal = "BEARISH";
          score -= 20;
          explanation.push(`VIX is high (${vixValue.toFixed(2)}), ` +
            "suggesting fear.");
        } else {
          explanation.push(`VIX is moderate (${vixValue.toFixed(2)}).`);
        }

        // Check trend (SMA 5 vs SMA 20)
        const sma5 = computeSMA(vixData.closes, 5);
        const sma20 = computeSMA(vixData.closes, 20);
        if (sma5 && sma20) {
          if (sma5 > sma20 * 1.05) {
            vixTrend = "Rising";
            score -= 5;
            explanation.push("Volatility is trending up.");
          } else if (sma5 < sma20 * 0.95) {
            vixTrend = "Falling";
            score += 5;
            explanation.push("Volatility is trending down.");
          }
        }
      }
    }

    // 2. Evaluate TNX (Yields)
    let tnxSignal: "BULLISH" | "BEARISH" | "NEUTRAL" = "NEUTRAL";
    let tnxTrend = "Flat";
    let tnxValue: number | null = null;


    if (tnxData && tnxData.closes && tnxData.closes.length > 0) {
      tnxValue = tnxData.currentPrice ||
        tnxData.closes[tnxData.closes.length - 1];

      // Check trend (SMA 10 vs SMA 50) of yields
      const sma10 = computeSMA(tnxData.closes, 10);
      const sma50 = computeSMA(tnxData.closes, 50);

      if (tnxValue !== null && sma10 && sma50) {
        if (sma10 > sma50 * 1.02) {
          tnxSignal = "BEARISH"; // Rising yields are generally bad for equities
          tnxTrend = "Rising";
          score -= 10;
          explanation.push("Yields (TNX) are rising.");
        } else if (sma10 < sma50 * 0.98) {
          tnxSignal = "BULLISH"; // Falling yields can support equities
          tnxTrend = "Falling";
          score += 5;
          explanation.push("Yields (TNX) are falling/stable.");
        } else {
          tnxTrend = "Stable";
        }
      }
    }

    // 3. Evaluate SPY (Market Trend)
    let spySignal: "BULLISH" | "BEARISH" | "NEUTRAL" = "NEUTRAL";
    let spyTrend = "Flat";
    let spyValue: number | null = null;

    if (spyData && spyData.closes && spyData.closes.length > 0) {
      spyValue = spyData.currentPrice ||
        spyData.closes[spyData.closes.length - 1];
      const sma50 = computeSMA(spyData.closes, 50);
      const sma200 = computeSMA(spyData.closes, 200);

      if (spyValue !== null && sma200) {
        if (spyValue > sma200) {
          spySignal = "BULLISH";
          spyTrend = "Above 200 SMA";
          score += 10;
          explanation.push("Market (SPY) is in a long-term uptrend.");
        } else {
          spySignal = "BEARISH";
          spyTrend = "Below 200 SMA";
          score -= 15;
          explanation.push("Market (SPY) is in a long-term downtrend.");
        }
      }

      if (sma50 && sma200) {
        if (sma50 > sma200) {
          score += 5; // Golden Cross area
        } else {
          score -= 5; // Death Cross area
        }
      }
    }

    // 4. Evaluate Yield Curve (10Y - 13W)
    let yieldCurveSignal: "BULLISH" | "BEARISH" | "NEUTRAL" = "NEUTRAL";
    let yieldCurveTrend = "Flat";
    let yieldSpread: number | null = null;

    if (tnxValue !== null && irxData && irxData.closes &&
      irxData.closes.length > 0) {
      const irxValue = irxData.currentPrice ||
        irxData.closes[irxData.closes.length - 1];
      if (irxValue !== null) {
        // Calculate spread. Both ^TNX and ^IRX are typically index points
        // (rate * 10 or just rate)
        // Usually on Yahoo Finance: ^TNX 41.50 (4.15%), ^IRX 52.5 (5.25%).
        // But historically ^TNX was *10. Recent check suggests unified.
        // If TNX > 20, it's likely *10. If IRX < 10, it's likely *1.
        // Normalize to %.
        const normTnx = tnxValue > 20 ? tnxValue / 10 : tnxValue;
        const normIrx = irxValue > 20 ? irxValue / 10 : irxValue;

        yieldSpread = normTnx - normIrx;

        if (yieldSpread < -0.5) {
          yieldCurveSignal = "BEARISH";
          yieldCurveTrend = "Deeply Inverted";
          score -= 15;
          explanation.push("Yield Curve is inverted " +
            `(${yieldSpread.toFixed(2)}%), recession warning.`);
        } else if (yieldSpread < 0) {
          yieldCurveSignal = "BEARISH"; // Mildly inverted
          yieldCurveTrend = "Inverted";
          score -= 5;
          explanation.push("Yield Curve is slightly inverted.");
        } else if (yieldSpread < 0.5) {
          yieldCurveSignal = "NEUTRAL";
          yieldCurveTrend = "Flat";
          // No score change, watch out
        } else {
          yieldCurveSignal = "BULLISH";
          yieldCurveTrend = "Normal";
          score += 5;
          // Normal curve
        }
      }
    }

    // 5. Evaluate Gold (Safe Haven / Inflation)
    let goldSignal: "BULLISH" | "BEARISH" | "NEUTRAL" = "NEUTRAL";
    let goldTrend = "Flat";
    let goldValue: number | null = null;
    if (gldData && gldData.closes && gldData.closes.length > 0) {
      goldValue = gldData.currentPrice ||
        gldData.closes[gldData.closes.length - 1];
      const sma50 = computeSMA(gldData.closes, 50);

      if (goldValue !== null && sma50) {
        if (goldValue > sma50) {
          goldSignal = "BULLISH";
          goldTrend = "Uptrend";
          // Gold rising can be risk-off esp if SPY is dropping
          if (spySignal === "BEARISH") {
            score -= 5;
            explanation.push("Gold is rising while Equities fall (Risk-Off).");
          }
        } else {
          goldSignal = "BEARISH";
          goldTrend = "Downtrend";
        }
      }
    }

    // 6. Evaluate Oil (Inflation / Growth)
    let oilSignal: "BULLISH" | "BEARISH" | "NEUTRAL" = "NEUTRAL";
    let oilTrend = "Flat";
    let oilValue: number | null = null;
    if (usoData && usoData.closes && usoData.closes.length > 0) {
      oilValue = usoData.currentPrice ||
        usoData.closes[usoData.closes.length - 1];
      const sma50 = computeSMA(usoData.closes, 50);
      if (oilValue !== null && sma50) {
        if (oilValue > sma50) {
          oilSignal = "BULLISH";
          oilTrend = "Uptrend";
        } else {
          oilSignal = "BEARISH";
          oilTrend = "Downtrend";
        }
      }
    }

    // 7. Evaluate DXY (USD Strength)
    let dxySignal: "BULLISH" | "BEARISH" | "NEUTRAL" = "NEUTRAL";
    let dxyTrend = "Flat";
    let dxyValue: number | null = null;
    if (dxyData && dxyData.closes && dxyData.closes.length > 0) {
      dxyValue = dxyData.currentPrice ||
        dxyData.closes[dxyData.closes.length - 1];
      const sma200 = computeSMA(dxyData.closes, 200);

      if (dxyValue !== null && sma200) {
        if (dxyValue > sma200) {
          dxySignal = "BEARISH"; // Strong dollar often hurts US multinationals
          dxyTrend = "Strong";
          score -= 5;
          explanation.push("USD is strong (Headwind for equities).");
        } else {
          dxySignal = "BULLISH";
          dxyTrend = "Weak";
          score += 5;
          explanation.push("USD is weak (Tailwind for equities).");
        }
      }
    }

    // 8. Evaluate Bitcoin (Risk Appetite)
    let btcSignal: "BULLISH" | "BEARISH" | "NEUTRAL" = "NEUTRAL";
    let btcTrend = "Flat";
    let btcValue: number | null = null;
    if (btcData && btcData.closes && btcData.closes.length > 0) {
      btcValue = btcData.currentPrice ||
        btcData.closes[btcData.closes.length - 1];
      const sma50 = computeSMA(btcData.closes, 50);

      if (btcValue !== null && sma50) {
        if (btcValue > sma50) {
          btcSignal = "BULLISH";
          btcTrend = "Uptrend";
          score += 5; // Speculative appetite is present
          explanation.push("Crypto markets signaling risk appetite.");
        } else {
          btcSignal = "BEARISH";
          btcTrend = "Downtrend";
          score -= 5;
        }
      }
    }


    // 9. Evaluate HYG (High Yield Bonds / Credit Health)
    let hygSignal: "BULLISH" | "BEARISH" | "NEUTRAL" = "NEUTRAL";
    let hygTrend = "Flat";
    let hygValue: number | null = null;
    if (hygData && hygData.closes && hygData.closes.length > 0) {
      hygValue = hygData.currentPrice ||
        hygData.closes[hygData.closes.length - 1];
      const sma50 = computeSMA(hygData.closes, 50);

      if (hygValue !== null && sma50) {
        if (hygValue > sma50) {
          hygSignal = "BULLISH";
          hygTrend = "Uptrend";
          score += 5;
          explanation.push("Credit markets (HYG) are healthy.");
        } else {
          hygSignal = "BEARISH";
          hygTrend = "Downtrend";
          score -= 5;
          explanation.push("Credit markets (HYG) showing stress.");
        }
      }
    }

    // Determine Status
    let status: "RISK_ON" | "RISK_OFF" | "NEUTRAL" = "NEUTRAL";
    if (score >= 60) status = "RISK_ON";
    else if (score <= 40) status = "RISK_OFF";

    // Sector Rotation Logic
    let sectorsBullish: string[] = [];
    let sectorsBearish: string[] = [];
    let allocation = {
      equity: "60%",
      fixedIncome: "40%",
      cash: "0%",
      commodities: "0%",
    };

    if (status === "RISK_ON") {
      sectorsBullish = [
        "Technology (XLK)",
        "Discretionary (XLY)",
        "Industrials (XLI)",
      ];
      sectorsBearish = [
        "Utilities (XLU)",
        "Staples (XLP)",
        "Gold (GLD)",
      ];
      allocation = {
        equity: "80%",
        fixedIncome: "15%",
        cash: "0%",
        commodities: "5%",
      };
    } else if (status === "RISK_OFF") {
      sectorsBullish = [
        "Utilities (XLU)",
        "Staples (XLP)",
        "Healthcare (XLV)",
      ];
      sectorsBearish = [
        "Discretionary (XLY)",
        "Technology (XLK)",
        "High Beta",
      ];
      allocation = {
        equity: "30%",
        fixedIncome: "40%",
        cash: "20%",
        commodities: "10%",
      };
    } else {
      sectorsBullish = [
        "Energy (XLE)",
        "Financials (XLF)",
        "Quality",
      ];
      sectorsBearish = ["High Growth", "Meme Stocks"];
      allocation = {
        equity: "60%",
        fixedIncome: "30%",
        cash: "5%",
        commodities: "5%",
      };
    }

    return {
      status,
      score: Math.max(0, Math.min(100, score)),
      indicators: {
        vix: { value: vixValue, signal: vixSignal, trend: vixTrend },
        tnx: { value: tnxValue, signal: tnxSignal, trend: tnxTrend },
        marketTrend: { value: spyValue, signal: spySignal, trend: spyTrend },
        yieldCurve: {
          value: yieldSpread,
          signal: yieldCurveSignal,
          trend: yieldCurveTrend,
        },
        gold: {
          value: goldValue,
          signal: goldSignal,
          trend: goldTrend,
        },
        oil: {
          value: oilValue,
          signal: oilSignal,
          trend: oilTrend,
        },
        dxy: {
          value: dxyValue,
          signal: dxySignal,
          trend: dxyTrend,
        },
        btc: {
          value: btcValue,
          signal: btcSignal,
          trend: btcTrend,
        },
        hyg: {
          value: hygValue,
          signal: hygSignal,
          trend: hygTrend,
        },
      },
      sectorRotation: {
        bullish: sectorsBullish,
        bearish: sectorsBearish,
      },
      assetAllocation: allocation,
      reason: explanation.join(" "),
      timestamp: Date.now(),
    };
  } catch (e) {
    logger.error("Error in getMacroAssessment", e);
    return {
      status: "NEUTRAL",
      score: 50,
      indicators: {
        vix: { value: null, signal: "NEUTRAL", trend: "Unknown" },
        tnx: { value: null, signal: "NEUTRAL", trend: "Unknown" },
        marketTrend: { value: null, signal: "NEUTRAL", trend: "Unknown" },
        yieldCurve: { value: null, signal: "NEUTRAL", trend: "Unknown" },
        gold: { value: null, signal: "NEUTRAL", trend: "Unknown" },
        oil: { value: null, signal: "NEUTRAL", trend: "Unknown" },
        dxy: { value: null, signal: "NEUTRAL", trend: "Unknown" },
        btc: { value: null, signal: "NEUTRAL", trend: "Unknown" },
        hyg: { value: null, signal: "NEUTRAL", trend: "Unknown" },
      },
      sectorRotation: {
        bullish: [],
        bearish: [],
      },
      assetAllocation: {
        equity: "--",
        fixedIncome: "--",
        cash: "--",
        commodities: "--",
      },
      reason: "Failed to fetch macro data.",
      timestamp: Date.now(),
    };
  }
}

export const getMacroAssessmentCall = onCall(async () => {
  return await getMacroAssessment();
});
