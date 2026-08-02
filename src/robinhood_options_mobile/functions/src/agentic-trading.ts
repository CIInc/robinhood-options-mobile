import { onCall } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as alphaagent from "./alpha-agent";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { POPULAR_SYMBOLS } from "./sentiment-analysis";
import { ALL_STOCKS } from "./stock-list";
import { getMarketData } from "./market-data";

const db = getFirestore();

const STALE_DATA_DISCLAIMER =
  "This signal was calculated using cached market data that may be " +
  "outdated. Confirm current market conditions before making a trading " +
  "decision.";
const CALCULATION_ERROR_DISCLAIMER =
  "The latest signal calculation could not be completed. The displayed " +
  "signal may be outdated; confirm current market conditions before making " +
  "a trading decision.";

/**
 * Merges user-facing calculation diagnostics into an existing signal.
 * Avoids creating an incomplete signal document before the first success.
 * @param {string} symbol Instrument symbol.
 * @param {string} interval Signal interval.
 * @param {Record<string, unknown>} values Diagnostic values to merge.
 * @return {Promise<void>}
 */
async function updateExistingSignalDiagnostics(
  symbol: string,
  interval: string,
  values: Record<string, unknown>
) {
  const signalDocId = interval === "1d" ? symbol : `${symbol}_${interval}`;
  const docRef = db.doc(`signals/${signalDocId}`);

  try {
    const updates = Object.fromEntries(
      Object.entries(values).map(([key, value]) => [
        `diagnostics.${key}`,
        value,
      ])
    );
    await docRef.update(updates);
  } catch (error) {
    const errorCode = (error as { code?: string | number })?.code;
    if (errorCode === 5 || errorCode === "not-found") return;
    logger.warn(`Failed to update calculation diagnostics for ${symbol}`, {
      interval,
      error,
    });
  }
}

// getMarketData moved to market-data.ts

/**
 * Executes a trade proposal based on agentic analysis.
 * @param {any} request The callable request object.
 * @return {Promise<object>} The trade proposal result.
 */
export async function performTradeProposal(request: any) {
  const config = {
    smaPeriodFast: request.data.smaPeriodFast || 10,
    smaPeriodSlow: request.data.smaPeriodSlow || 30,
    tradeQuantity: request.data.tradeQuantity || 1,
    maxPositionSize: request.data.maxPositionSize || 100,
    maxPortfolioConcentration: request.data.maxPortfolioConcentration || 0.5,
    enableDynamicPositionSizing:
      request.data.enableDynamicPositionSizing || false,
    riskPerTrade: request.data.riskPerTrade || 0.01,
    atrMultiplier: request.data.atrMultiplier || 2,
    rsiPeriod: request.data.rsiPeriod || 14,
    rocPeriod: request.data.rocPeriod || 9,
    enableSectorLimits: request.data.enableSectorLimits || false,
    maxSectorExposure: request.data.maxSectorExposure || 0.2,
    enableCorrelationChecks: request.data.enableCorrelationChecks || false,
    maxCorrelation: request.data.maxCorrelation || 0.8,
    enableVolatilityFilters: request.data.enableVolatilityFilters || false,
    minVolatility: request.data.minVolatility || 0,
    maxVolatility: request.data.maxVolatility || 100,
    enableDrawdownProtection: request.data.enableDrawdownProtection || false,
    maxDrawdown: request.data.maxDrawdown || 0.2,
    reduceSizeOnRiskOff: request.data.reduceSizeOnRiskOff || false,
    riskOffSizeReduction: request.data.riskOffSizeReduction || 0.5,
    skipSignalUpdate: request.data.skipSignalUpdate || false,
    skipRiskGuard: request.data.skipRiskGuard || false,
    tradingMode: request.data.tradingMode || "systematic",
    enabledIndicators: request.data.enabledIndicators,
  };

  logger.info("Initiated Trade Proposal for symbol " +
    `${request.data.symbol}`, config, { structuredData: true });

  const symbol = request.data.symbol || "SPY";
  const interval = request.data.interval || "1d";
  const range = request.data.range;
  const portfolioState = request.data.portfolioState || {};
  const lastAttemptAt = Date.now();

  await updateExistingSignalDiagnostics(symbol, interval, {
    lastAttemptAt,
    calculationStatus: "running",
    warning: null,
  });

  // Delegate to Alpha agent implementation which will call RiskGuard internally
  try {
    const marketData = await getMarketData(symbol,
      config.smaPeriodFast, config.smaPeriodSlow, interval, range);
    const result = await alphaagent.handleAlphaTask(marketData,
      portfolioState, config, interval);

    const completedAt = Date.now();
    const metadata = marketData?.metadata || {};
    const hasUsableMarketData = Array.isArray(marketData?.closes) &&
      marketData.closes.length > 0;
    const calculationFailed = result?.status === "error" ||
      !hasUsableMarketData;
    const usedStaleCache = metadata.usedStaleCache === true;

    await updateExistingSignalDiagnostics(symbol, interval, {
      lastAttemptAt,
      ...(calculationFailed ? {} : {
        lastSuccessfulCalculationAt: completedAt,
      }),
      marketDataAsOf: metadata.marketDataAsOf || null,
      usedStaleCache,
      dataSource: metadata.dataSource || "unknown",
      calculationStatus: calculationFailed ? "failed" :
        (usedStaleCache ? "stale_data" : "success"),
      warning: calculationFailed ? CALCULATION_ERROR_DISCLAIMER :
        (usedStaleCache ? STALE_DATA_DISCLAIMER : null),
      interval,
      barCount: marketData?.closes?.length || 0,
    });

    return result;
  } catch (err) {
    logger.error("Error in initiateTradeProposal", err);
    await updateExistingSignalDiagnostics(symbol, interval, {
      lastAttemptAt,
      calculationStatus: "failed",
      warning: CALCULATION_ERROR_DISCLAIMER,
      interval,
    });
    return { status: "error", message: (err as Error).message || String(err) };
  }
}

export const initiateTradeProposal = onCall({
  secrets: ["TWELVE_DATA_API_KEY", "GEMINI_API_KEY"],
}, async (request) => {
  return performTradeProposal(request);
});

/**
 * Seeds the charts collection with chart documents for popular
 * symbols. This can be run manually to ensure all popular symbols are
 * monitored.
 */
export const seedAgenticTrading = onCall({
  secrets: ["TWELVE_DATA_API_KEY", "GEMINI_API_KEY"],
}, async (request) => {
  const inputSymbols = request.data.symbols;
  const useFullList = request.data.full === true;

  let targetSymbols: string[] = [];

  if (inputSymbols && Array.isArray(inputSymbols)) {
    targetSymbols = inputSymbols;
  } else if (useFullList) {
    targetSymbols = Array.from(new Set([...POPULAR_SYMBOLS, ...ALL_STOCKS]));
  } else {
    // Default to strict popular list unless full requested
    targetSymbols = POPULAR_SYMBOLS;
  }

  let addedCount = 0;
  const errors: any[] = [];
  let processedCount = 0;

  logger.info("Seeding agentic trading for " + targetSymbols.length +
    " symbols");

  // Process in chunks of 50 to avoid limits
  const CHUNK_SIZE = 50;
  for (let i = 0; i < targetSymbols.length; i += CHUNK_SIZE) {
    const chunk = targetSymbols.slice(i, i + CHUNK_SIZE);
    const promises = chunk.map(async (symbol) => {
      const docRef = db.doc(`charts/${symbol}`);
      try {
        const doc = await docRef.get();
        if (!doc.exists) {
          // Create an empty placeholder
          // the cron job or getMarketData will populate it
          await docRef.set({
            symbol,
            created: FieldValue.serverTimestamp(),
            seeded: true,
            chart: null, // Explicitly null to force cache miss
          });
          logger.info(`Created chart document for ${symbol}`);
          return 1;
        }
        return 0;
      } catch (e) {
        logger.error(`Error checking/creating ${symbol}`, e);
        errors.push({ symbol, error: String(e) });
        return 0;
      }
    });

    const results = await Promise.all(promises);
    addedCount += results.reduce<number>((a, b) => a + b, 0);
    processedCount += chunk.length;
    logger.info(`Processed ${processedCount}/${targetSymbols.length}`);
  }

  return {
    status: "success",
    addedCount,
    totalProcessed: targetSymbols.length,
    errors,
  };
});
