import * as logger from "firebase-functions/logger";
import { onCall } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { getMarketData } from "./market-data";
import { computeSMA } from "./technical-indicators";
import { VertexAI } from "@google-cloud/vertexai";

const db = getFirestore();
const messaging = getMessaging();

export interface MacroStrategy {
  name: string;
  icon: string;
  risk: string;
  description: string;
}

// Indicator weights in the scoring system (should sum to 100)
// Note: Not currently used in weighted scoring, but kept for future
// implementation of indicator-specific weights
export interface MacroAssessment {
  status: "RISK_ON" | "RISK_OFF" | "NEUTRAL";
  score: number; // 0 to 100, where 100 is max bullish/risk-on
  confidence: number; // 0-100, how confident are we in this assessment
  signalDivergence: {
    bullishCount: number; // Count of bullish signals
    bearishCount: number; // Count of bearish signals
    neutralCount: number; // Count of neutral signals
    isConflicted: boolean; // True if signals are mixed (uncertainty)
  };
  indicators: {
    vix: {
      value: number | null;
      signal: "BULLISH" | "BEARISH" | "NEUTRAL";
      trend: string;
      momentum?: string; // Rising/Falling velocity
    };
    tnx: {
      value: number | null;
      signal: "BULLISH" | "BEARISH" | "NEUTRAL";
      trend: string;
      momentum?: string;
    };
    marketTrend: {
      value: number | null;
      signal: "BULLISH" | "BEARISH" | "NEUTRAL";
      trend: string;
      momentum?: string;
    };
    yieldCurve: {
      value: number | null; // Spread (10Y - 13W)
      signal: "BULLISH" | "BEARISH" | "NEUTRAL";
      trend: string;
      momentum?: string;
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
    putCallRatio: {
      value: number | null;
      signal: "BULLISH" | "BEARISH" | "NEUTRAL";
      trend: string;
    };
    advDecline: {
      value: number | null;
      signal: "BULLISH" | "BEARISH" | "NEUTRAL";
      trend: string;
    };
    riskAppetite: {
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
  strategies?: MacroStrategy[];
  reason: string;
  aiAnalysis?: string;
  timestamp: number;
}

/**
 * Calculates momentum (direction and velocity) of an indicator
 * @param {number[]} closes - Array of closing prices
 * @param {number} period - Number of periods to check
 * @return {string} String describing momentum direction and strength
 */
function calculateMomentum(closes: number[], period = 5): string {
  if (closes.length < period + 5) return "Flat";

  const recent = closes.slice(-period);
  const previous = closes.slice(-period - 5, -5);

  const recentAvg = recent.reduce((a, b) => a + b) / recent.length;
  const prevAvg = previous.reduce((a, b) => a + b) / previous.length;

  const change = ((recentAvg - prevAvg) / prevAvg) * 100;

  if (change > 5) return "Strong Upward";
  if (change > 1) return "Moderately Rising";
  if (change > -1) return "Sideways";
  if (change > -5) return "Moderately Falling";
  return "Strong Downward";
}

/**
 * Calculates confidence in the assessment based on signal agreement
 * @param {number} bullishCount - Number of bullish signals
 * @param {number} bearishCount - Number of bearish signals
 * @param {number} totalIndicators - Total number of indicators
 * @return {number} Confidence score (0-100)
 */
function calculateConfidence(
  bullishCount: number,
  bearishCount: number,
  totalIndicators: number
): number {
  // Perfect agreement (all one direction) = 90-100
  // Strong agreement (75%+ in one direction) = 75-89
  // Moderate agreement (60-75%) = 60-74
  // Mixed signals (40-60%) = 40-59
  // Conflicted = 20-39

  const max = Math.max(bullishCount, bearishCount);
  const min = Math.min(bullishCount, bearishCount);
  const neutralCount = totalIndicators - bullishCount - bearishCount;
  const percentage = (max / totalIndicators) * 100;

  // Penalize high neutral count (lack of conviction)
  const neutralPenalty = (neutralCount / totalIndicators) * 15;

  // Penalize conflicting signals (both bull and bear strong)
  const conflictPenalty = min > totalIndicators * 0.25 ? 10 : 0;

  let baseConfidence: number;
  if (percentage >= 90) {
    baseConfidence = 90 + (percentage - 90);
  } else if (percentage >= 75) {
    baseConfidence = 75 + (percentage - 75);
  } else if (percentage >= 60) {
    baseConfidence = 60 + (percentage - 60);
  } else if (percentage >= 50) {
    baseConfidence = 45 + (percentage - 50) * 0.5;
  } else {
    baseConfidence = 30 + (percentage - 40) * 0.3;
  }

  return Math.max(20, Math.min(100,
    baseConfidence - neutralPenalty - conflictPenalty));
}

/**
 * Macro Agent
 *
 * Evaluates macroeconomic conditions to adjust trading risk profiles.
 * Features: weighted indicators, confidence scoring & divergence analysis.
 *
 * Key Indicators:
 * - VIX (20% weight): Volatility measure
 * - SPY (20%): Market trend
 * - TNX (15%): Yields
 * - Yield Curve (15%): Recession warning
 * - PCR (10%): Sentiment
 * - HYG (8%): Credit health
 * - Others (12%): Gold, Oil, DXY, BTC, NYA, IWM
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
      dxyData, hygData, pccrData, nyaData, iwmData,
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
      // Put/Call Ratio with fallback
      getMarketData("^PCC", 1, 1, "1d", "1y")
        .then((data) => {
          if (data && data.closes && data.closes.length > 0) return data;
          logger.info("^PCC (Equity) no data, falling back to ^CPC (Total)");
          return getMarketData("^CPC", 1, 1, "1d", "1y");
        })
        .then((data) => {
          if (data && data.closes && data.closes.length > 0) return data;
          logger.info("^CPC (Total) no data, falling back to ^CPCE");
          return getMarketData("^CPCE", 1, 1, "1d", "1y");
        })
        .catch((e) => {
          logger.error("Failed to fetch Put/Call data", e);
          return null;
        }),
      getMarketData("^NYA", 50, 200, "1d", "1y").catch((e) => {
        logger.error("Failed to fetch NYA data", e);
        return null;
      }),
      getMarketData("IWM", 50, 200, "1d", "1y").catch((e) => {
        logger.error("Failed to fetch IWM data", e);
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
        // More nuanced VIX evaluation with weighted scoring
        if (vixValue < 12) {
          vixSignal = "BULLISH";
          score += 15; // Slightly reduced to account for structural low vol
          explanation.push(`VIX is very low (${vixValue.toFixed(2)}), ` +
            "complacency check - watch for reversals.");
        } else if (vixValue < 15) {
          vixSignal = "BULLISH";
          score += 10; // Reduced from 12
          explanation.push(`VIX is low (${vixValue.toFixed(2)}), ` +
            "suggesting low market stress.");
        } else if (vixValue < 20) {
          vixSignal = "BULLISH"; // BULLISH in normal range
          score += 5; // Balanced
          explanation.push(`VIX is in healthy range (${vixValue.toFixed(2)}).`);
        } else if (vixValue < 25) {
          vixSignal = "NEUTRAL";
          score -= 3; // Reduced penalty from 5
          explanation.push(`VIX is elevated (${vixValue.toFixed(2)}), ` +
            "moderate caution warranted.");
        } else if (vixValue < 35) {
          vixSignal = "BEARISH";
          score -= 15; // Reduced from 18
          explanation.push(`VIX is high (${vixValue.toFixed(2)}), ` +
            "significant market fear.");
        } else {
          vixSignal = "BEARISH";
          score -= 20; // Reduced from 25
          explanation.push(`VIX is extreme (${vixValue.toFixed(2)}), ` +
            "panic conditions - potential reversal zone.");
        }

        // Check trend (SMA 5 vs SMA 20)
        const sma5 = computeSMA(vixData.closes, 5);
        const sma20 = computeSMA(vixData.closes, 20);
        if (sma5 && sma20) {
          if (sma5 > sma20 * 1.10) {
            vixTrend = "Sharply Rising";
            score -= 8; // Accelerating fear
            explanation.push("Volatility is spiking rapidly.");
          } else if (sma5 > sma20 * 1.05) {
            vixTrend = "Rising";
            score -= 5;
            explanation.push("Volatility is trending up.");
          } else if (sma5 < sma20 * 0.90) {
            vixTrend = "Sharply Falling";
            score += 8; // Fear subsiding
            explanation.push("Volatility is collapsing.");
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
      const rawValue = tnxData.currentPrice ||
        tnxData.closes[tnxData.closes.length - 1];
      // Normalize yields if they are in bps*10 (e.g. 40.86 -> 4.086)
      tnxValue = (rawValue !== null && rawValue > 20) ?
        rawValue / 10 : rawValue;

      // Check trend (SMA 10 vs SMA 50) of yields
      const sma10 = computeSMA(tnxData.closes, 10);
      const sma50 = computeSMA(tnxData.closes, 50);

      if (tnxValue !== null && sma10 && sma50) {
        // Normalize SMA values for comparison if needed
        const normSma10 = sma10 > 20 ? sma10 / 10 : sma10;
        const normSma50 = sma50 > 20 ? sma50 / 10 : sma50;

        // Consider both absolute level and trend
        // Very high yields (>5%) are restrictive,
        // very low (<2%) are stimulative
        let yieldLevelAdjustment = 0;
        if (tnxValue > 5.5) {
          yieldLevelAdjustment = -8; // Very restrictive
          explanation.push(`Yields are very high (${tnxValue.toFixed(2)}%), ` +
            "restrictive for growth.");
        } else if (tnxValue > 4.5) {
          yieldLevelAdjustment = -4; // Elevated
        } else if (tnxValue < 2.5) {
          yieldLevelAdjustment = 5; // Very accommodative
          explanation.push(`Yields are low (${tnxValue.toFixed(2)}%), ` +
            "supportive environment.");
        } else if (tnxValue < 3.5) {
          yieldLevelAdjustment = 2; // Moderately supportive
        }

        if (normSma10 > normSma50 * 1.05) {
          tnxSignal = "BEARISH"; // Rapidly rising yields
          tnxTrend = "Sharply Rising";
          score -= 10; // Reduced from 15
          explanation
            .push("Yields (TNX) are rising rapidly - tightening conditions.");
        } else if (normSma10 > normSma50 * 1.02) {
          tnxSignal = "BEARISH"; // Rising yields
          tnxTrend = "Rising";
          score -= 5; // Reduced from 10
          explanation.push("Yields (TNX) are rising.");
        } else if (normSma10 < normSma50 * 0.95) {
          tnxSignal = "BULLISH"; // Falling yields can support equities
          tnxTrend = "Sharply Falling";
          score += 15; // Increased from 10
          explanation
            .push("Yields (TNX) are falling rapidly - easing conditions.");
        } else if (normSma10 < normSma50 * 0.98) {
          tnxSignal = "BULLISH";
          tnxTrend = "Falling";
          score += 8; // Increased from 5
          explanation.push("Yields (TNX) are falling/stable.");
        } else {
          tnxTrend = "Stable";
        }

        score += yieldLevelAdjustment;
      }
    }

    // 3. Evaluate SPY (Market Trend) - WEIGHTED as primary indicator
    let spySignal: "BULLISH" | "BEARISH" | "NEUTRAL" = "NEUTRAL";
    let spyTrend = "Flat";
    let spyValue: number | null = null;

    if (spyData && spyData.closes && spyData.closes.length > 0) {
      spyValue = spyData.currentPrice ||
        spyData.closes[spyData.closes.length - 1];
      const sma50 = computeSMA(spyData.closes, 50);
      const sma200 = computeSMA(spyData.closes, 200);

      if (spyValue !== null && sma200 && sma50) {
        const above200Pct = ((spyValue - sma200) / sma200) * 100;

        if (spyValue > sma200) {
          spySignal = "BULLISH";
          if (above200Pct > 10) {
            spyTrend = "Strong Uptrend";
            score += 15; // Well above 200 SMA = strong trend
            explanation.push("Market (SPY) is " +
              `${above200Pct.toFixed(1)}% above 200 SMA - ` +
              "strong uptrend.");
          } else if (above200Pct > 5) {
            spyTrend = "Uptrend";
            score += 12;
            explanation.push("Market (SPY) is in a solid uptrend.");
          } else {
            spyTrend = "Above 200 SMA";
            score += 8;
            explanation.push("Market (SPY) is above 200 SMA.");
          }
        } else {
          spySignal = "BEARISH";
          if (above200Pct < -10) {
            spyTrend = "Strong Downtrend";
            score -= 20; // Deep below 200 SMA = bear market
            explanation.push("Market (SPY) is " +
              `${Math.abs(above200Pct).toFixed(1)}% below 200 SMA - ` +
              "bear market.");
          } else if (above200Pct < -5) {
            spyTrend = "Downtrend";
            score -= 15;
            explanation.push("Market (SPY) is in a downtrend.");
          } else {
            spyTrend = "Below 200 SMA";
            score -= 10;
            explanation.push("Market (SPY) is below 200 SMA.");
          }
        }

        // Golden/Death Cross - important confirmations
        if (sma50 > sma200 * 1.02) {
          score += 8; // Strong Golden Cross
          explanation.push("Golden Cross confirmed - bullish momentum.");
        } else if (sma50 > sma200) {
          score += 5; // Golden Cross area
        } else if (sma50 < sma200 * 0.98) {
          score -= 8; // Strong Death Cross
          explanation.push("Death Cross confirmed - bearish momentum.");
        } else if (sma50 < sma200) {
          score -= 5; // Death Cross area
        }
      }
    }

    // 4. Evaluate Yield Curve (10Y - 13W) - IMPORTANT recession indicator
    let yieldCurveSignal: "BULLISH" | "BEARISH" | "NEUTRAL" = "NEUTRAL";
    let yieldCurveTrend = "Flat";
    let yieldSpread: number | null = null;

    if (tnxValue !== null && irxData && irxData.closes &&
      irxData.closes.length > 0) {
      const irxValue = irxData.currentPrice ||
        irxData.closes[irxData.closes.length - 1];
      if (irxValue !== null) {
        // Calculate spread. Both ^TNX and ^IRX are typically index points
        // Normalize to %.
        const normTnx = tnxValue > 20 ? tnxValue / 10 : tnxValue;
        const normIrx = irxValue > 20 ? irxValue / 10 : irxValue;

        yieldSpread = normTnx - normIrx;

        if (yieldSpread < -1.0) {
          yieldCurveSignal = "BEARISH";
          yieldCurveTrend = "Severely Inverted";
          score -= 15; // Prolonged inversion had delayed impact
          explanation.push("Yield Curve severely inverted " +
            `(${yieldSpread.toFixed(2)}%), high recession probability.`);
        } else if (yieldSpread < -0.5) {
          yieldCurveSignal = "BEARISH";
          yieldCurveTrend = "Deeply Inverted";
          score -= 10; // Reduced from 18
          explanation.push("Yield Curve deeply inverted " +
            `(${yieldSpread.toFixed(2)}%), recession warning.`);
        } else if (yieldSpread < -0.2) {
          yieldCurveSignal = "BEARISH";
          yieldCurveTrend = "Moderately Inverted";
          score -= 5; // Reduced from 10
          explanation.push("Yield Curve moderately inverted - caution.");
        } else if (yieldSpread < 0) {
          yieldCurveSignal = "BEARISH";
          yieldCurveTrend = "Slightly Inverted";
          score -= 2; // Reduced from 5
          explanation.push("Yield Curve slightly inverted.");
        } else if (yieldSpread < 0.5) {
          yieldCurveSignal = "NEUTRAL";
          yieldCurveTrend = "Flat";
          score -= 2; // Flat curve not ideal
          explanation.push("Yield Curve is flat - watch for inversion.");
        } else if (yieldSpread < 1.5) {
          yieldCurveSignal = "NEUTRAL";
          yieldCurveTrend = "Normal";
          score += 5;
          explanation.push("Yield Curve is normal.");
        } else if (yieldSpread < 2.5) {
          yieldCurveSignal = "BULLISH";
          yieldCurveTrend = "Steep";
          score += 8;
          explanation.push(
            "Yield Curve is steep - healthy growth expectations.");
        } else {
          yieldCurveSignal = "BULLISH";
          yieldCurveTrend = "Very Steep";
          score += 10;
          explanation.push(
            "Yield Curve very steep - strong growth environment.");
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
      const sma200 = computeSMA(gldData.closes, 200);

      if (goldValue !== null && sma50 && sma200) {
        const aboveSma50 = goldValue > sma50;
        const aboveSma200 = goldValue > sma200;

        if (aboveSma50 && aboveSma200) {
          goldSignal = "BULLISH";
          goldTrend = "Strong Uptrend";
          // Strong gold rally = potential risk-off sentiment
          if (spySignal === "BEARISH" || vixSignal === "BEARISH") {
            score -= 8; // Flight to safety scenario
            explanation.push(
              "Gold in strong uptrend amid equity weakness (Risk-Off).");
          } else {
            score -= 3; // Inflation concerns but equities holding
            explanation.push(
              "Gold rallying - watch for inflation/uncertainty.");
          }
        } else if (aboveSma50) {
          goldSignal = "NEUTRAL";
          goldTrend = "Uptrend";
          if (spySignal === "BEARISH") {
            score -= 5;
            explanation.push("Gold rising while Equities fall (Risk-Off).");
          }
        } else if (!aboveSma50 && !aboveSma200) {
          goldSignal = "BEARISH";
          goldTrend = "Downtrend";
          score += 3; // Risk-on environment
          explanation.push("Gold weakness suggests risk-on sentiment.");
        } else {
          goldSignal = "NEUTRAL";
          goldTrend = "Consolidating";
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
      const sma50 = computeSMA(dxyData.closes, 50);
      const sma200 = computeSMA(dxyData.closes, 200);

      if (dxyValue !== null && sma50 && sma200) {
        const pctAbove200 = ((dxyValue - sma200) / sma200) * 100;

        if (dxyValue > sma50 && dxyValue > sma200) {
          dxySignal = "BEARISH"; // Strong dollar hurts multinationals
          if (pctAbove200 > 3) {
            dxyTrend = "Very Strong";
            score -= 8;
            explanation.push(
              "USD very strong - significant headwind for equities.");
          } else {
            dxyTrend = "Strong";
            score -= 5;
            explanation.push("USD is strong (Headwind for equities).");
          }
        } else if (dxyValue < sma50 && dxyValue < sma200) {
          dxySignal = "BULLISH";
          if (pctAbove200 < -3) {
            dxyTrend = "Very Weak";
            score += 8;
            explanation.push("USD very weak - strong tailwind for equities.");
          } else {
            dxyTrend = "Weak";
            score += 5;
            explanation.push("USD is weak (Tailwind for equities).");
          }
        } else {
          dxySignal = "NEUTRAL";
          dxyTrend = "Mixed";
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
    // CRITICAL risk indicator
    let hygSignal: "BULLISH" | "BEARISH" | "NEUTRAL" = "NEUTRAL";
    let hygTrend = "Flat";
    let hygValue: number | null = null;
    if (hygData && hygData.closes && hygData.closes.length > 0) {
      hygValue = hygData.currentPrice ||
        hygData.closes[hygData.closes.length - 1];
      const sma20 = computeSMA(hygData.closes, 20);
      const sma50 = computeSMA(hygData.closes, 50);
      const sma200 = computeSMA(hygData.closes, 200);

      if (hygValue !== null && sma20 && sma50 && sma200) {
        const above20 = hygValue > sma20;
        const above50 = hygValue > sma50;
        const above200 = hygValue > sma200;
        const pctFrom50 = ((hygValue - sma50) / sma50) * 100;

        if (above20 && above50 && above200) {
          hygSignal = "BULLISH";
          hygTrend = "Strong Uptrend";
          score += 8; // Credit health is critical for risk-on
          explanation.push(
            "Credit markets (HYG) very healthy - strong risk appetite.");
        } else if (above50) {
          hygSignal = "BULLISH";
          hygTrend = "Uptrend";
          score += 5;
          explanation.push("Credit markets (HYG) are healthy.");
        } else if (!above20 && !above50 && !above200) {
          hygSignal = "BEARISH";
          hygTrend = "Strong Downtrend";
          score -= 12; // Severe credit stress = major warning
          explanation.push(
            "Credit markets (HYG) under severe stress - " +
            "major risk-off signal.");
        } else if (pctFrom50 < -2) {
          hygSignal = "BEARISH";
          hygTrend = "Downtrend";
          score -= 8;
          explanation.push("Credit markets (HYG) showing significant stress.");
        } else if (!above50) {
          hygSignal = "BEARISH";
          hygTrend = "Downtrend";
          score -= 5;
          explanation.push("Credit markets (HYG) showing stress.");
        } else {
          hygSignal = "NEUTRAL";
          hygTrend = "Mixed";
        }
      }
    }

    // 10. Evaluate Put/Call Ratio
    // Based on LuxAlgo documentation:
    // https://www.luxalgo.com/blog/putcall-ratio-key-options-sentiment/
    // Extreme readings serve as contrarian indicators for market reversals.
    // Standard total average is ~0.97, Equity average is ~0.7.
    let pccrSignal: "BULLISH" | "BEARISH" | "NEUTRAL" = "NEUTRAL";
    let pccrTrend = "Flat";
    let pccrValue: number | null = null;
    if (pccrData && pccrData.closes && pccrData.closes.length > 0) {
      pccrValue = pccrData.currentPrice ||
        pccrData.closes[pccrData.closes.length - 1];
      if (pccrValue !== null) {
        // Use LuxAlgo's 'Entry and Exit Timing' thresholds
        // (Typically Total PCR)
        if (pccrValue > 1.23) {
          pccrSignal = "BULLISH"; // Extreme fear is contrarian bullish
          pccrTrend = "Extreme Fear (Bottoming)";
          score += 10;
          explanation.push(`Extreme fear in PCR (${pccrValue.toFixed(2)}) ` +
            "signals a potential bottom (Contrarian Bullish).");
        } else if (pccrValue < 0.72) {
          pccrSignal = "BEARISH"; // Extreme greed is contrarian bearish
          pccrTrend = "Extreme Greed (Topping)";
          score -= 10;
          explanation.push(`Extreme greed in PCR (${pccrValue.toFixed(2)}) ` +
            "signals a potential top (Contrarian Bearish).");
        } else if (pccrValue > 1.05) {
          pccrSignal = "BEARISH";
          pccrTrend = "Bearish Sentiment";
          score -= 5;
          explanation.push("Moderately bearish sentiment in Put/Call ratio.");
        } else if (pccrValue < 0.85) {
          pccrSignal = "BULLISH";
          pccrTrend = "Bullish Sentiment";
          score += 5;
          explanation.push("Moderately bullish sentiment in Put/Call ratio.");
        } else {
          pccrSignal = "NEUTRAL";
          pccrTrend = "Neutral";
          explanation.push("Put/Call ratio is in the neutral zone.");
        }
      }
    }

    // 11. Evaluate Advance/Decline (Broad Market Strength)
    let nyaSignal: "BULLISH" | "BEARISH" | "NEUTRAL" = "NEUTRAL";
    let nyaTrend = "Flat";
    let nyaValue: number | null = null;
    if (nyaData && nyaData.closes && nyaData.closes.length > 0) {
      nyaValue = nyaData.currentPrice ||
        nyaData.closes[nyaData.closes.length - 1];
      const sma200 = computeSMA(nyaData.closes, 200);
      if (nyaValue !== null && sma200) {
        if (nyaValue > sma200) {
          nyaSignal = "BULLISH";
          nyaTrend = "Broad Strength";
          score += 5;
          explanation.push("Broad market (NYSE) is showing strength.");
        } else {
          nyaSignal = "BEARISH";
          nyaTrend = "Broad Weakness";
          score -= 5;
        }
      }
    }

    // 12. Evaluate Risk Appetite (IWM vs SPY)
    let riskSignal: "BULLISH" | "BEARISH" | "NEUTRAL" = "NEUTRAL";
    let riskTrend = "Flat";
    let riskValue: number | null = null;
    if (iwmData && iwmData.closes && iwmData.closes.length > 0 &&
      spyData && spyData.closes && spyData.closes.length > 0) {
      const iwmPrice = iwmData.currentPrice ||
        iwmData.closes[iwmData.closes.length - 1];
      const spyPrice = spyData.currentPrice ||
        spyData.closes[spyData.closes.length - 1];

      if (iwmPrice && spyPrice) {
        riskValue = iwmPrice / spyPrice;
        // Check 10-day trend of ratio
        const iwmCloses = iwmData.closes;
        const spyCloses = spyData.closes;
        const ratioCloses = iwmCloses.map((c, i) => c / spyCloses[i]);
        const sma10 = computeSMA(ratioCloses, 10);
        const currentRatio = ratioCloses[ratioCloses.length - 1];

        if (sma10) {
          if (currentRatio > sma10 * 1.01) {
            riskSignal = "BULLISH";
            riskTrend = "Improving";
            score += 5;
            explanation.push("Small caps outperforming (Risk Appetite Inc).");
          } else if (currentRatio < sma10 * 0.99) {
            riskSignal = "BEARISH";
            riskTrend = "Deteriorating";
            score -= 5;
            explanation.push("Small caps underperforming (Risk Aversion).");
          }
        }
      }
    }

    // Determine Status with more nuanced thresholds
    let status: "RISK_ON" | "RISK_OFF" | "NEUTRAL" = "NEUTRAL";
    if (score >= 65) {
      status = "RISK_ON";
    } else if (score <= 35) {
      status = "RISK_OFF";
    } else {
      // In neutral zone (35-65), check if we're leaning one way
      if (score >= 55) {
        // Mildly bullish but not quite risk-on
        status = "NEUTRAL";
      } else if (score <= 45) {
        // Mildly bearish but not quite risk-off
        status = "NEUTRAL";
      }
    }

    // Calculate Signal Divergence and Confidence
    const signals = [
      vixSignal, tnxSignal, spySignal, yieldCurveSignal,
      goldSignal, oilSignal, dxySignal, btcSignal,
      hygSignal, pccrSignal, nyaSignal, riskSignal,
    ];

    const bullishCount = signals.filter((s) => s === "BULLISH").length;
    const bearishCount = signals.filter((s) => s === "BEARISH").length;
    const neutralCount = signals.filter((s) => s === "NEUTRAL").length;

    // Signals conflicted if neither dominates (neither > 33% of max)
    const maxCount = Math.max(bullishCount, bearishCount);
    const minCount = Math.min(bullishCount, bearishCount);
    const isConflicted =
      (minCount > maxCount * 0.33) || (neutralCount > 4);

    const confidence = calculateConfidence(
      bullishCount,
      bearishCount,
      signals.length,
    );

    // Add momentum to key indicators
    const vixMomentum =
      vixData && vixData.closes ?
        calculateMomentum(vixData.closes) :
        "Unknown";
    const spyMomentum =
      spyData && spyData.closes ?
        calculateMomentum(spyData.closes) :
        "Unknown";
    const tnxMomentum =
      tnxData && tnxData.closes ?
        calculateMomentum(tnxData.closes) :
        "Unknown";
    const yieldMomentum =
      yieldCurveSignal === "NEUTRAL" ?
        "Stable" :
        yieldCurveSignal === "BEARISH" ?
          "Worsening" :
          "Improving";

    // Sector Rotation Logic
    let sectorsBullish: string[] = [];
    let sectorsBearish: string[] = [];
    let strategies: MacroStrategy[] = [];
    let allocation = {
      equity: "60%",
      fixedIncome: "30%",
      cash: "5%",
      commodities: "5%",
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
      strategies = [
        {
          name: "Bull Call Spread",
          icon: "call_made",
          risk: "Limited",
          description: "Capitalize on upside while limiting cost.",
        },
        {
          name: "Cash Secured Put",
          icon: "shield",
          risk: "Defined",
          description: "Generate income and entry at lower prices.",
        },
        {
          name: "Long Call",
          icon: "add_circle",
          risk: "Premium",
          description: "Max leverage for strong directional moves.",
        },
      ];
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
      strategies = [
        {
          name: "Bear Put Spread",
          icon: "call_received",
          risk: "Limited",
          description: "Profit from downside with lower premium cost.",
        },
        {
          name: "Covered Call",
          icon: "security",
          risk: "Stock Risk",
          description: "Generate income to offset potential losses.",
        },
        {
          name: "Long Put",
          icon: "remove_circle",
          risk: "Premium",
          description: "Direct hedge against market further declines.",
        },
      ];
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
      strategies = [
        {
          name: "Iron Condor",
          icon: "compare_arrows",
          risk: "Limited",
          description: "Profit from range-bound, sideways markets.",
        },
        {
          name: "Calendar Spread",
          icon: "calendar_today",
          risk: "Volatility",
          description: "Benefit from time decay and rising IV.",
        },
        {
          name: "Butterfly",
          icon: "filter_vintage",
          risk: "Limited",
          description: "Low cost way to play a specific price target.",
        },
      ];
    }

    return {
      status,
      score: Math.max(0, Math.min(100, score)),
      confidence: Math.round(confidence),
      signalDivergence: {
        bullishCount,
        bearishCount,
        neutralCount,
        isConflicted,
      },
      indicators: {
        vix: {
          value: vixValue,
          signal: vixSignal,
          trend: vixTrend,
          momentum: vixMomentum,
        },
        tnx: {
          value: tnxValue,
          signal: tnxSignal,
          trend: tnxTrend,
          momentum: tnxMomentum,
        },
        marketTrend: {
          value: spyValue,
          signal: spySignal,
          trend: spyTrend,
          momentum: spyMomentum,
        },
        yieldCurve: {
          value: yieldSpread,
          signal: yieldCurveSignal,
          trend: yieldCurveTrend,
          momentum: yieldMomentum,
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
        putCallRatio: {
          value: pccrValue,
          signal: pccrSignal,
          trend: pccrTrend,
        },
        advDecline: {
          value: nyaValue,
          signal: nyaSignal,
          trend: nyaTrend,
        },
        riskAppetite: {
          value: riskValue,
          signal: riskSignal,
          trend: riskTrend,
        },
      },
      sectorRotation: {
        bullish: sectorsBullish,
        bearish: sectorsBearish,
      },
      assetAllocation: allocation,
      strategies,
      reason: explanation.map((e) => `- ${e}`).join("\n"),
      timestamp: Date.now(),
    };
  } catch (e) {
    logger.error("Error in getMacroAssessment", e);
    return {
      status: "NEUTRAL",
      score: 50,
      confidence: 20,
      signalDivergence: {
        bullishCount: 0,
        bearishCount: 0,
        neutralCount: 12,
        isConflicted: true,
      },
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
        putCallRatio: { value: null, signal: "NEUTRAL", trend: "Unknown" },
        advDecline: { value: null, signal: "NEUTRAL", trend: "Unknown" },
        riskAppetite: { value: null, signal: "NEUTRAL", trend: "Unknown" },
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

/**
 * Uses Gemini to generate a narrative AI analysis of the macro environment.
 * @param {MacroAssessment} assessment The raw assessment data.
 * @return {Promise<string>} The AI analysis.
 */
async function getAiMacroAnalysis(
  assessment: MacroAssessment
): Promise<string> {
  if (!process.env.GEMINI_API_KEY) {
    return "AI Analysis unavailable (missing API key).";
  }

  const vertexAI = new VertexAI({
    project: "realizealpha",
    location: "us-central1",
  });

  const model = vertexAI.getGenerativeModel({
    model: "gemini-2.5-flash-lite",
  });

  const {
    vix, tnx, marketTrend: spy, yieldCurve: curv,
    dxy, btc, putCallRatio: pcr,
    advDecline: nya,
  } = assessment.indicators;
  const status = assessment.status;
  const score = assessment.score;
  const reason = assessment.reason;
  const prompt = `
    Analyze the following macroeconomic data and provide a concise, 
    insightful market narrative (2-3 paragraphs max). 
    Focus on the "Why" and "What's Next" for a retail options trader.
    
    Current Sentiment: ${status} (Score: ${score}/100)
    Summary of Indicators: ${reason}
    
    Detailed Indicators:
    - VIX: ${vix.value} (${vix.signal})
    - Yields (TNX): ${tnx.value} (${tnx.signal})
    - Trend (SPY): ${spy.value} (${spy.signal})
    - Curve: ${curv?.value}% (${curv?.signal})
    - USD: ${dxy?.value} (${dxy?.signal})
    - BTC: ${btc?.value} (${btc?.signal})
    - PCR: ${pcr?.value} (${pcr?.signal})
    - NYA: ${nya?.value} (${nya?.signal})
    
    Guidance:
    - Bull Sectors: ${assessment.sectorRotation.bullish.join(", ")}
    - Bear Sectors: ${assessment.sectorRotation.bearish.join(", ")}
    - Equity Allocation: ${assessment.assetAllocation.equity}
    - Cash Allocation: ${assessment.assetAllocation.cash}
    
    Output in Markdown format. Use professional but accessible language.
  `;

  try {
    const { response } = await model.generateContent({
      contents: [{ role: "user", parts: [{ text: prompt }] }],
    });
    const text = response.candidates?.[0]?.content?.parts?.[0]?.text;
    return typeof text === "string" ? text : "AI Analysis failed to generate.";
  } catch (error) {
    logger.error("AI Macro Analysis error", error);
    return "AI Analysis encountered an error.";
  }
}

/**
 * Saves the macro assessment to history, maintaining a maximum of 100 entries.
 * Uses a date-based ID to ensure only one assessment is persisted per day.
 * @param {MacroAssessment} assessment The assessment to save.
 */
async function saveMacroAssessmentToHistory(assessment: MacroAssessment) {
  try {
    // en-CA gives YYYY-MM-DD format
    const formatter = new Intl.DateTimeFormat("en-CA", {
      timeZone: "America/New_York",
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
    });
    const dateStr = formatter.format(new Date());

    // Check previous assessment to see if regime changed
    const previousSnapshot = await db.collection("macro_assessments")
      .orderBy("timestamp", "desc")
      .limit(2)
      .get();

    let previousStatus: string | null = null;
    if (previousSnapshot.docs.length > 0) {
      // If the first doc is today, get the second one
      if (previousSnapshot.docs[0].id === dateStr &&
        previousSnapshot.docs.length > 1) {
        previousStatus = previousSnapshot.docs[1].data().status;
      } else if (previousSnapshot.docs[0].id !== dateStr) {
        previousStatus = previousSnapshot.docs[0].data().status;
      }
    }

    // Save to historical collection using date as ID to persist once per day
    await db.collection("macro_assessments").doc(dateStr).set({
      ...assessment,
      timestamp: Date.now(),
    });

    // If regime changed, trigger a notification
    if (previousStatus && previousStatus !== assessment.status) {
      logger.info(`Macro regime changed from ${previousStatus} ` +
        `to ${assessment.status}`);

      // Get users who have macro notifications enabled
      const usersSnapshot = await db.collection("user")
        .where("fcmTokens", "!=", [])
        .get();

      const tokens: string[] = [];
      usersSnapshot.forEach((doc) => {
        const data = doc.data();
        // Check if user has macro notifications enabled
        // (default to true if not set)
        const settings = data.notificationSettings || {};
        if (settings.macroAlerts !== false && data.fcmTokens &&
          Array.isArray(data.fcmTokens)) {
          tokens.push(...data.fcmTokens);
        }
      });

      if (tokens.length > 0) {
        const emoji = assessment.status === "RISK_ON" ? "🟢" :
          assessment.status === "RISK_OFF" ? "🔴" : "🟡";
        const title = `${emoji} Macro Regime Shift: ${assessment.status}`;
        const body = "Market environment has shifted to " +
          `${assessment.status} (Score: ${assessment.score}). ` +
          "Tap to view updated strategy guidance.";

        const message = {
          notification: {
            title,
            body,
          },
          data: {
            type: "macro_alert",
            status: assessment.status,
            score: assessment.score.toString(),
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          },
          tokens: [...new Set(tokens)], // Deduplicate tokens
        };

        try {
          const response = await messaging.sendEachForMulticast(message);
          logger.info(`Sent macro alert to ${response.successCount} devices`);
        } catch (error) {
          logger.error("Error sending macro alert notifications", error);
        }
      }
    }

    // Keep history manageable (e.g., last 100 entries)
    const historySnapshot = await db.collection("macro_assessments")
      .orderBy("timestamp", "desc")
      .offset(100)
      .get();

    if (!historySnapshot.empty) {
      const batch = db.batch();
      historySnapshot.docs.forEach((doc) => {
        batch.delete(doc.ref);
      });
      await batch.commit();
    }
  } catch (error) {
    logger.error("Failed to save macro history", error);
  }
}

export const getMacroAssessmentCall = onCall({
  secrets: ["GEMINI_API_KEY", "TWELVE_DATA_API_KEY"],
}, async () => {
  const assessment = await getMacroAssessment();

  // Add AI analysis
  assessment.aiAnalysis = await getAiMacroAnalysis(assessment);

  // Persist to history
  await saveMacroAssessmentToHistory(assessment);

  return assessment;
});

/**
 * Daily macro assessment cron.
 * Runs at 4:00 PM Eastern Time.
 */
export const macroAssessmentCron = onSchedule({
  schedule: "0 16 * * *", // 4:00 PM ET daily
  timeZone: "America/New_York",
  secrets: ["GEMINI_API_KEY"],
  memory: "1GiB",
  timeoutSeconds: 300,
}, async () => {
  logger.info("🕐 Daily Macro Assessment Cron triggered at 4:00 PM ET");
  const assessment = await getMacroAssessment();
  assessment.aiAnalysis = await getAiMacroAnalysis(assessment);
  await saveMacroAssessmentToHistory(assessment);
  logger.info("✅ Daily Macro Assessment Cron completed");
});

export const getMacroHistoryCall = onCall({
  secrets: ["TWELVE_DATA_API_KEY"],
}, async (request) => {
  const limit = request.data.limit || 30;
  const snapshot = await db.collection("macro_assessments")
    .orderBy("timestamp", "desc")
    .limit(limit)
    .get();

  return snapshot.docs.map((doc) => doc.data()).reverse();
});
