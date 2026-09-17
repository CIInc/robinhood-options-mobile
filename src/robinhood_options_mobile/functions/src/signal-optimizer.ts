import * as logger from "firebase-functions/logger";
import { GoogleGenAI } from "@google/genai";

interface OptimizationResult {
  confidenceScore: number;
  refinedSignal: "BUY" | "SELL" | "HOLD";
  reasoning: string;
  mlModel: string;
}

/**
 * Optimizes the trade signal using a machine learning model (Gemini).
 * @param {string} symbol - The stock symbol.
 * @param {string} interval - The chart interval.
 * @param {any} multiIndicatorResult - The result from the technical indicators.
 * @param {any} marketData - Recent market data.
 * @param {any} marketIndexData - Market index data (SPY/QQQ).
 * @return {Promise<OptimizationResult>} The optimized signal result.
 */
export async function optimizeSignal(
  symbol: string,
  interval: string,
  multiIndicatorResult: any,
  marketData: any,
  marketIndexData: any
): Promise<OptimizationResult> {
  // Cost optimization: Skip AI if signal strength is weak
  // Increased threshold to 50 to reduce costs
  if (multiIndicatorResult.signalStrength < 50) {
    return null as any;
  }

  // Cost optimization: Skip AI for HOLD signals
  // unless they are strong (potential breakout)
  if (multiIndicatorResult.overallSignal === "HOLD" &&
    multiIndicatorResult.signalStrength < 70) {
    return null as any;
  }

  try {
    const indicators = multiIndicatorResult.indicators;
    const lastPrices = marketData.closes.slice(-5);
    const lastVolumes = (marketData.volumes || []).slice(-5);
    const lastHighs = (marketData.highs || []).slice(-5);
    const lastLows = (marketData.lows || []).slice(-5);
    const marketTrend = marketIndexData.closes.slice(-5);
    const marketVolTrend = (marketIndexData.volumes || []).slice(-5);

    let customIndicatorsText = "";
    if (multiIndicatorResult.customIndicators) {
      customIndicatorsText = "\nCustom Indicators:\n";
      for (const [name, result] of
        Object.entries(multiIndicatorResult.customIndicators)) {
        const res = result as any;
        customIndicatorsText += `- ${name}: ${res.signal} (${res.reason})\n`;
      }
    }

    const prompt = `Role:Financial Analyst.Task:Analyze ${symbol} (${interval}).
Signal:${multiIndicatorResult.overallSignal} ` +
      `Strength:${multiIndicatorResult.signalStrength}
Indicators:
Price:${indicators.priceMovement.signal}(${indicators.priceMovement.reason})
Mom:${indicators.momentum.signal}(${indicators.momentum.reason})
Dir:${indicators.marketDirection.signal}(${indicators.marketDirection.reason})
Vol:${indicators.volume.signal}(${indicators.volume.reason})
MACD:${indicators.macd.signal}(${indicators.macd.reason})
BB:${indicators.bollingerBands.signal}(${indicators.bollingerBands.reason})
Stoch:${indicators.stochastic.signal}(${indicators.stochastic.reason})
ATR:${indicators.atr.signal}(${indicators.atr.reason})
OBV:${indicators.obv.signal}(${indicators.obv.reason})
VWAP:${indicators.vwap.signal}(${indicators.vwap.reason})
ADX:${indicators.adx.signal}(${indicators.adx.reason})
W%R:${indicators.williamsR.signal}(${indicators.williamsR.reason})
Ichimoku:${indicators.ichimoku.signal}(${indicators.ichimoku.reason})` +
      `${customIndicatorsText}
Prices:${lastPrices.join(",")}
Vols:${lastVolumes.join(",")}
Highs:${lastHighs.join(",")}
Lows:${lastLows.join(",")}
MktTrend:${marketTrend.join(",")}
MktVols:${marketVolTrend.join(",")}
Output JSON:{confidenceScore(0-100),refinedSignal(BUY/SELL/HOLD),reasoning}`;

    const ai = new GoogleGenAI({
      apiKey: process.env.GEMINI_API_KEY,
    });
    const primaryModel = process.env.AI_MODEL_NAME || "gemini-3.1-flash-lite";

    let result;
    try {
      result = await ai.models.generateContent({
        model: primaryModel,
        contents: prompt,
        config: {
          responseMimeType: "application/json",
          maxOutputTokens: 120,
          temperature: 0.1,
        },
      });
    } catch (modelErr) {
      if (primaryModel !== "gemini-2.5-flash-lite") {
        logger.warn(
          `Model ${primaryModel} failed in signal optimizer, ` +
          "falling back to gemini-2.5-flash-lite",
          modelErr,
        );
        result = await ai.models.generateContent({
          model: "gemini-2.5-flash-lite",
          contents: prompt,
          config: {
            responseMimeType: "application/json",
            maxOutputTokens: 120,
            temperature: 0.1,
          },
        });
      } else {
        throw modelErr;
      }
    }

    const responseText = result.text ||
      result.candidates?.[0]?.content?.parts?.[0]?.text;

    if (!responseText) {
      throw new Error("Empty response from Gemini");
    }

    const optimization = JSON.parse(responseText);

    logger.info(`Signal optimized for ${symbol}`, {
      originalSignal: multiIndicatorResult.overallSignal,
      refinedSignal: optimization.refinedSignal,
      confidence: optimization.confidenceScore,
    });

    return {
      confidenceScore: optimization.confidenceScore,
      refinedSignal: optimization.refinedSignal,
      reasoning: optimization.reasoning,
      mlModel: "gemini-3.1-flash-lite",
    };
  } catch (error) {
    logger.error("Error optimizing signal with ML", error);
    // Fallback to original signal if ML fails
    return {
      confidenceScore: multiIndicatorResult.signalStrength || 50,
      refinedSignal: multiIndicatorResult.overallSignal,
      reasoning: "ML optimization failed, falling back to rule-based signal.",
      mlModel: "none",
    };
  }
}
