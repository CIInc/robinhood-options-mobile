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
 */
export async function getMacroAssessment(): Promise<MacroAssessment> {
  try {
    // Fetch VIX, TNX, and SPY
    // We use "1d" interval and "1y" range to calculate SMAs
    const [vixData, tnxData, spyData] = await Promise.all([
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
    ]);

    let score = 50; // Start at neutral
    const explanation: string[] = [];

    // 1. Evaluate VIX
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

    // Determine Status
    let status: "RISK_ON" | "RISK_OFF" | "NEUTRAL" = "NEUTRAL";
    if (score >= 60) status = "RISK_ON";
    else if (score <= 40) status = "RISK_OFF";

    return {
      status,
      score: Math.max(0, Math.min(100, score)),
      indicators: {
        vix: { value: vixValue, signal: vixSignal, trend: vixTrend },
        tnx: { value: tnxValue, signal: tnxSignal, trend: tnxTrend },
        marketTrend: { value: spyValue, signal: spySignal, trend: spyTrend },
      },
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
      },
      reason: "Failed to fetch macro data.",
      timestamp: Date.now(),
    };
  }
}

export const getMacroAssessmentCall = onCall(async () => {
  return await getMacroAssessment();
});
