import { onRequest } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { getFirestore } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";

const db = getFirestore();

/**
 * Extracts the bearer token from the Authorization header.
 * @param {string | undefined} header The Authorization header value.
 * @return {string | null} The extracted bearer token or null.
 */
function bearerToken(header: string | undefined): string | null {
  if (!header) return null;
  const match = header.match(/^Bearer\s+(\S+)$/i);
  return match ? match[1] : null;
}

/**
 * Checks if the request comes from an authenticated admin user.
 * @param {string | undefined} header The Authorization header value.
 * @return {Promise<boolean>} True if authorized as admin, false otherwise.
 */
async function isAuthorizedAdmin(
  header: string | undefined
): Promise<boolean> {
  const token = bearerToken(header);
  if (!token) return false;
  try {
    const decodedToken = await getAuth().verifyIdToken(token);
    return decodedToken.role === "admin";
  } catch (e) {
    logger.warn("signalDiagnostics authorization check failed", e);
    return false;
  }
}

/**
 * Diagnostic endpoint to check signal data and cache status
 */
export const signalDiagnostics = onRequest(async (request, response) => {
  if (!(await isAuthorizedAdmin(request.headers.authorization))) {
    response.status(401).json({
      error: "Unauthorized: Admin privileges required.",
    });
    return;
  }

  const symbol = (request.query.symbol as string) || "UBER";

  try {
    // Get signal document
    const signalDocId = symbol;
    const signalDoc = await db.doc(`signals/${signalDocId}`).get();
    const spyCache = await db.doc("charts/SPY").get();

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
    response.status(500).json({ error: "Failed to run signal diagnostics" });
  }
});
