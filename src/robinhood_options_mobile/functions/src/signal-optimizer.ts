import * as logger from "firebase-functions/logger";
import { VertexAI } from "@google-cloud/vertexai";

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
  try {
    const vertexAI = new VertexAI({
      project: "realizealpha",
      location: "us-central1",
    });

    const model = vertexAI.getGenerativeModel({
      model: "gemini-2.5-flash",
      generationConfig: {
        responseMimeType: "application/json",
      },
    });

    const indicators = multiIndicatorResult.indicators;
    const lastPrices = marketData.closes.slice(-10);
    const lastVolumes = (marketData.volumes || []).slice(-10);
    const lastHighs = (marketData.highs || []).slice(-10);
    const lastLows = (marketData.lows || []).slice(-10);
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

    const prompt = `
      You are an expert financial analyst and trading algorithm.
      Analyze the following technical indicators and market context for ` +
      `${symbol} on a ${interval} interval.
      
      Current Rule-Based Signal: ${multiIndicatorResult.overallSignal}
      Signal Strength: ${multiIndicatorResult.signalStrength}
      
      Technical Indicators:
      - Price Movement: ${indicators.priceMovement.signal} ` +
      `(${indicators.priceMovement.reason})
      - Momentum: ${indicators.momentum.signal} ` +
      `(${indicators.momentum.reason})
      - Market Direction: ${indicators.marketDirection.signal} ` +
      `(${indicators.marketDirection.reason})
      - Volume: ${indicators.volume.signal} (${indicators.volume.reason})
      - MACD: ${indicators.macd.signal} (${indicators.macd.reason})
      - Bollinger Bands: ${indicators.bollingerBands.signal} ` +
      `(${indicators.bollingerBands.reason})
      - Stochastic: ${indicators.stochastic.signal} ` +
      `(${indicators.stochastic.reason})
      - ATR: ${indicators.atr.signal} (${indicators.atr.reason})
      - OBV: ${indicators.obv.signal} (${indicators.obv.reason})
      - VWAP: ${indicators.vwap.signal} (${indicators.vwap.reason})
      - ADX: ${indicators.adx.signal} (${indicators.adx.reason})
      - Williams %R: ${indicators.williamsR.signal} ` +
      `(${indicators.williamsR.reason})
      ${customIndicatorsText}
      Recent Price Action (last 10 closes): ${lastPrices.join(", ")}
      Recent Volumes (last 10): ${lastVolumes.join(", ")}
      Recent Highs (last 10): ${lastHighs.join(", ")}
      Recent Lows (last 10): ${lastLows.join(", ")}
      Market Index Trend (last 5 closes): ${marketTrend.join(", ")}
      Market Index Volumes (last 5): ${marketVolTrend.join(", ")}
      
      Task:
      1. Evaluate the coherence of the indicators.
      2. Assess the strength of the trend and potential for reversal.
      3. Provide a confidence score (0-100) for the trade.
      4. Suggest a refined signal (BUY, SELL, or HOLD).
      5. Provide a concise reasoning.
      
      Output JSON format:
      {
        "confidenceScore": number,
        "refinedSignal": "BUY" | "SELL" | "HOLD",
        "reasoning": "string"
      }
    `;

    const result = await model.generateContent(prompt);
    const responseText = result.response.candidates?.[0].content.parts[0].text;

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
      mlModel: "gemini-2.5-flash",
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
