import { onCall } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as alphaagent from "./alpha-agent";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { POPULAR_SYMBOLS } from "./sentiment-analysis";
import { ALL_STOCKS } from "./stock-list";
import { getMarketData } from "./market-data";

const db = getFirestore();

// getMarketData moved to market-data.ts

/**
 * Executes a trade proposal based on agentic analysis.
 * @param {any} request The callable request object.
 * @return {Promise<object>} The trade proposal result.
 */
export async function performTradeProposal(request: any) {
  logger.info("Initiate Trade Proposal called", { structuredData: true });

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
  };

  logger.info("Agentic Trading Configuration:", config);

  const symbol = request.data.symbol || "SPY";
  const interval = request.data.interval || "1d";
  const range = request.data.range;

  const marketData = await getMarketData(symbol,
    config.smaPeriodFast, config.smaPeriodSlow, interval, range);

  const portfolioState = request.data.portfolioState || {};

  // Delegate to Alpha agent implementation which will call RiskGuard internally
  try {
    const result = await alphaagent.handleAlphaTask(marketData,
      portfolioState, config, interval);
    return result;
  } catch (err) {
    logger.error("Error in initiateTradeProposal", err);
    return { status: "error", message: (err as Error).message || String(err) };
  }
}

export const initiateTradeProposal = onCall(async (request) => {
  return performTradeProposal(request);
});

export const getAgenticTradingConfig = onCall(async () => {
  logger.info("Get Agentic Trading Config called", { structuredData: true });
  // Try reading configuration from Firestore first
  try {
    const doc = await db.doc("agentic_trading/config").get();
    if (doc.exists) {
      const config = doc.data();
      logger.info("Loaded config from Firestore", config);
      return { status: "success", config };
    }
  } catch (err) {
    logger.warn("Failed to read agentic trading config from Firestore", err);
  }

  // Return default configuration as fallback
  const config = {
    smaPeriodFast: 10,
    smaPeriodSlow: 30,
    tradeQuantity: 1,
    maxPositionSize: 100,
    maxPortfolioConcentration: 0.5,
    rsiPeriod: 14,
    marketIndexSymbol: "SPY",
    enableDynamicPositionSizing: false,
    riskPerTrade: 0.01,
    atrMultiplier: 2,
  };
  return { status: "success", config };
});

/**
 * Persist agentic trading configuration to Firestore.
 */
export const setAgenticTradingConfig = onCall(async (request) => {
  const cfg = request.data || {};
  try {
    await db.doc("agentic_trading/config").set(cfg, { merge: true });
    logger.info("Saved agentic trading config to Firestore", cfg);
    return { status: "success", config: cfg };
  } catch (err) {
    logger.error("Failed to save config to Firestore", err);
    return { status: "error", message: (err as Error).message || String(err) };
  }
});

/**
 * Seeds the agentic_trading collection with chart documents for popular
 * symbols. This can be run manually to ensure all popular symbols are
 * monitored.
 */
export const seedAgenticTrading = onCall(async (request) => {
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
      const docRef = db.doc(`agentic_trading/chart_${symbol}`);
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
