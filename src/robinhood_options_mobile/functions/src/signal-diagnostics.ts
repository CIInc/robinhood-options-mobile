import { onRequest } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { getFirestore } from "firebase-admin/firestore";

const db = getFirestore();

/**
 * Diagnostic endpoint to check signal data and cache status
 */
export const signalDiagnostics = onRequest(async (request, response) => {
  const symbol = (request.query.symbol as string) || "UBER";

  try {
    // Get signal document
    const signalDoc = await db.doc(`agentic_trading/signals_${symbol}`).get();
    const spyCache = await db.doc("agentic_trading/chart_SPY").get();

    const result: any = {
      symbol,
      timestamp: new Date().toISOString(),
    };

    if (signalDoc.exists) {
      const data = signalDoc.data();
      if (data) {
        const ageMinutes =
          Math.round((Date.now() - data.timestamp) / 1000 / 60);
        const mdIndicator =
          data.multiIndicatorResult?.indicators?.marketDirection;
        result.signal = {
          timestamp: new Date(data.timestamp).toISOString(),
          ageMinutes,
          overallSignal: data.signal,
          marketDirection: {
            signal: mdIndicator?.signal,
            fastMA: mdIndicator?.metadata?.fastMA,
            slowMA: mdIndicator?.metadata?.slowMA,
            trendStrength: mdIndicator?.metadata?.trendStrength,
            reason: mdIndicator?.reason,
          },
        };
      }
    } else {
      result.signal = null;
    }

    if (spyCache.exists) {
      const spyData = spyCache.data();
      if (spyData) {
        const closes =
          spyData.chart?.indicators?.quote?.[0]?.close?.filter(
            (p: number | null) => p !== null
          ) || [];
        result.spyCache = {
          timestamp: new Date(spyData.updated).toISOString(),
          ageMinutes:
            Math.round((Date.now() - spyData.updated) / 1000 / 60),
          priceCount: closes.length,
          lastFivePrices: closes.slice(-5),
        };
      }
    } else {
      result.spyCache = null;
    }

    response.json(result);
  } catch (error) {
    logger.error("Error in signalDiagnostics", error);
    response.status(500).json({ error: String(error) });
  }
});
