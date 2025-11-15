import * as riskguard from "./riskguard-agent";
import { onCall } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";

/**
 * Compute the Simple Moving Average (SMA) for a given period.
 * @param {number[]} prices - Array of prices.
 * @param {number} period - The period for the SMA.
 * @return {number|null} The computed SMA or null if not enough data.
 */
export function computeSMA(prices: number[], period: number): number | null {
  if (!prices || prices.length < period || period <= 0) return null;
  const slice = prices.slice(prices.length - period);
  const sum = slice.reduce((a, b) => a + b, 0);
  return sum / period;
}

/**
 * Handle Alpha agent logic for trade signal and risk assessment.
 * @param {object} marketData - Market data including prices and symbol.
 * @param {object} portfolioState - Current portfolio state.
 * @param {object} config - Trading configuration.
 * @return {Promise<object>} The result of the Alpha agent task.
 */
export async function handleAlphaTask(marketData: any,
  portfolioState: any, config: any) {
  logger.info("Alpha agent: handleAlphaTask called",
    { marketData, portfolioState, config });

  const prices: number[] = marketData?.prices || [];
  const smaPeriodFast = config?.smaPeriodFast || 10;
  const smaPeriodSlow = config?.smaPeriodSlow || 30;
  const fast = computeSMA(prices, smaPeriodFast);
  const slow = computeSMA(prices, smaPeriodSlow);

  // Need previous SMA to detect crossover.
  // Compute with one-step lag if possible
  const fastPrev = prices.length > smaPeriodFast ?
    computeSMA(prices.slice(0, prices.length - 1), smaPeriodFast) :
    null;
  const slowPrev = prices.length > smaPeriodSlow ?
    computeSMA(prices.slice(0, prices.length - 1), smaPeriodSlow) :
    null;

  logger.info("Alpha agent SMAs", {
    [`${smaPeriodFast}-day SMA`]: fast,
    [`${smaPeriodSlow}-day SMA`]: slow,
    [`Previous ${smaPeriodFast}-day SMA`]: fastPrev,
    [`Previous ${smaPeriodSlow}-day SMA`]: slowPrev,
    smaPeriodFast,
    smaPeriodSlow,
    prices,
  });

  let signal: "BUY" | "SELL" | "HOLD" = "HOLD";
  let reason = "";
  if (fast !== null && slow !== null &&
    fastPrev !== null && slowPrev !== null) {
    if (fast > slow && fastPrev <= slowPrev) {
      signal = "BUY";
      reason = `${smaPeriodFast}-day SMA crossed above ` +
        `${smaPeriodSlow}-day SMA (${fast.toFixed(2)} > ${slow.toFixed(2)})`;
    } else if (fast < slow && fastPrev >= slowPrev) {
      signal = "SELL";
      reason = `${smaPeriodFast}-day SMA crossed below ` +
        `${smaPeriodSlow}-day SMA (${fast.toFixed(2)} < ${slow.toFixed(2)})`;
    } else {
      reason = `No crossover (${smaPeriodFast}-day SMA=${fast?.toFixed(2)},` +
        ` ${smaPeriodSlow}-day SMA=${slow?.toFixed(2)},` +
        ` Previous ${smaPeriodFast}-day SMA=${fastPrev?.toFixed(2)},` +
        ` Previous ${smaPeriodSlow}-day SMA=${slowPrev?.toFixed(2)})`;
    }
  } else {
    reason = "Insufficient data for SMA calculation.";
  }

  if (signal === "HOLD") {
    return {
      status: "no_action",
      message: "Alpha agent: No SMA crossover signal.",
      reason,
      signal,
    };
  }

  const lastPrice = prices.length > 0 ?
    prices[prices.length - 1] : marketData?.currentPrice || 0;
  const quantity = config?.tradeQuantity || 1;

  const proposal = {
    symbol: marketData?.symbol || "SPY",
    action: signal,
    reason: reason,
    quantity,
    price: lastPrice,
  };

  // Call riskguard to assess
  const assessment = await riskguard.assessTrade(proposal,
    portfolioState, config);

  // Persist trade signal to Firestore
  try {
    const { getFirestore } = await import("firebase-admin/firestore");
    const db = getFirestore();
    const symbol = marketData.symbol || "UNKNOWN";
    const signalDoc = {
      timestamp: Date.now(),
      signal,
      reason,
      [`${smaPeriodFast}-day SMA`]: fast,
      [`${smaPeriodSlow}-day SMA`]: slow,
      [`Previous ${smaPeriodFast}-day SMA`]: fastPrev,
      [`Previous ${smaPeriodSlow}-day SMA`]: slowPrev,
      currentPrice: marketData.currentPrice,
      pricesLength: Array.isArray(marketData.prices) ?
        marketData.prices.length : 0,
      config,
      portfolioState,
      proposal,
      assessment,
    };
    await db.doc(`agentic_trading/signals_${symbol}`)
      .set(signalDoc); // , { merge: true }
    // await db.collection(`agentic_trading/signals_${symbol}`)
    //   .add({
    //     timestamp: Date.now(),
    //     signal,
    //     reason,
    //     fast,
    //     slow,
    //     fastPrev,
    //     slowPrev,
    //     currentPrice: marketData.currentPrice,
    //     pricesLength: Array.isArray(marketData.prices) ?
    //       marketData.prices.length : 0,
    //     portfolioState,
    //     config,
    //   });
    logger.info("Alpha agent stored trade signal", signalDoc);
  } catch (err) {
    logger.warn("Failed to persist trade signal", err);
  }

  if (!assessment.approved) {
    return {
      status: "rejected",
      message: "RiskGuard agent rejected the proposal",
      proposal: proposal, assessment: assessment,
    };
  }

  return {
    status: "approved",
    message: "Alpha agent approved proposal after risk check",
    proposal: proposal, assessment: assessment,
  };
}

/**
 * Cloud Function to handle Alpha agent task via HTTP trigger.
 * @param {object} request - The request object containing
 *                          marketData, portfolioState, and config.
 * @returns {Promise<object>} The Alpha agent task result.
 */
export const alphabotTask = onCall(async (request) => {
  logger.info("Alpha agent task called via onCall", { data: request.data });
  const marketData = request.data.marketData || {};
  const portfolioState = request.data.portfolioState || {};
  const config = request.data.config || {};
  const result = await handleAlphaTask(marketData,
    portfolioState, config);
  return result;
});
