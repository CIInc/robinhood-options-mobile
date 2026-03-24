import { onCall } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { getFirestore } from "firebase-admin/firestore";
import * as indicators from "./technical-indicators";
import * as riskguard from "./riskguard-agent";
import { getMarketData } from "./market-data";

const db = getFirestore();

interface FuturesSignalConfig {
  tradeQuantity?: number;
  maxContracts?: number;
  maxNotional?: number;
  maxDailyLoss?: number;
  minSignalStrength?: number;
  rsiPeriod?: number;
  rocPeriod?: number;
  smaPeriodFast?: number;
  smaPeriodSlow?: number;
  marketIndexSymbol?: string;
  enabledIndicators?: Record<string, boolean>;
  enableDynamicPositionSizing?: boolean;
  riskPerTrade?: number;
  atrMultiplier?: number;
  skipRiskGuard?: boolean;
  skipSignalUpdate?: boolean;
  multiIntervalAnalysis?: boolean;
  contractMultiplier?: number;
  stopLossPct?: number;
  takeProfitPct?: number;
  trailingStopEnabled?: boolean;
  trailingStopAtrMultiplier?: number;
}

/**
 * Build and evaluate a futures signal from market data and config.
 * @param {any} request Callable request payload.
 * @return {Promise<object>} Signal evaluation result.
 */
export async function performFuturesSignal(request: any) {
  const data = request.data || {};
  const symbol = data.symbol as string;
  const contractId = data.contractId as string;
  const interval = (data.interval as string) || "1h";
  const config: FuturesSignalConfig = data.config || {};
  const portfolioState = data.portfolioState || {};

  if (!symbol || !contractId) {
    return { status: "error", message: "symbol and contractId are required" };
  }

  const marketData = await getMarketData(
    symbol,
    config.smaPeriodFast || 10,
    config.smaPeriodSlow || 30,
    interval
  );

  const marketIndexSymbol = config.marketIndexSymbol || "ES=F";
  const marketIndexData = await getMarketData(
    marketIndexSymbol,
    config.smaPeriodFast || 10,
    config.smaPeriodSlow || 30,
    "1d"
  );

  const enabledIndicators = config.enabledIndicators ?
    Object.entries(config.enabledIndicators)
      .filter(([, v]) => v === true)
      .map(([k]) => k) :
    undefined;

  const multiIndicatorResult = indicators.evaluateAllIndicators(
    {
      opens: marketData.opens,
      highs: marketData.highs,
      lows: marketData.lows,
      closes: marketData.closes,
      volumes: marketData.volumes,
    },
    marketIndexData,
    {
      rsiPeriod: config.rsiPeriod,
      rocPeriod: config.rocPeriod,
      marketFastPeriod: config.smaPeriodFast,
      marketSlowPeriod: config.smaPeriodSlow,
      enabledIndicators,
    }
  );

  let overallSignal = multiIndicatorResult.overallSignal;
  let reason = multiIndicatorResult.reason;
  const minSignalStrength = config.minSignalStrength ?? 0;

  if (multiIndicatorResult.signalStrength < minSignalStrength) {
    overallSignal = "HOLD";
    reason = `Signal strength ${multiIndicatorResult.signalStrength} ` +
      `below minimum ${minSignalStrength}`;
  }

  // Multi-interval confirmation (Expert mode)
  if (config.multiIntervalAnalysis && overallSignal !== "HOLD") {
    const higherInterval = interval === "15m" ?
      "1h" : interval === "1h" ? "1d" : null;
    if (higherInterval) {
      const higherData = await getMarketData(
        symbol,
        config.smaPeriodFast || 10,
        config.smaPeriodSlow || 30,
        higherInterval
      );
      const higherResult = indicators.evaluateAllIndicators(
        {
          opens: higherData.opens,
          highs: higherData.highs,
          lows: higherData.lows,
          closes: higherData.closes,
          volumes: higherData.volumes,
        },
        marketIndexData,
        {
          rsiPeriod: config.rsiPeriod,
          rocPeriod: config.rocPeriod,
          marketFastPeriod: config.smaPeriodFast,
          marketSlowPeriod: config.smaPeriodSlow,
          enabledIndicators,
        }
      );
      if (higherResult.overallSignal !== overallSignal) {
        overallSignal = "HOLD";
        reason = `Higher timeframe ${higherInterval} ` +
          `(${higherResult.overallSignal}) disagrees with ${interval} ` +
          `(${overallSignal})`;
      }
    }
  }

  const lastPrice = marketData.currentPrice ??
    (marketData.closes.length > 0 ?
      marketData.closes[marketData.closes.length - 1] :
      0);
  const contractMultiplier = config.contractMultiplier || 1;
  let quantity = config.tradeQuantity || 1;

  if (config.enableDynamicPositionSizing &&
    overallSignal === "BUY" &&
    multiIndicatorResult.indicators.atr.value &&
    multiIndicatorResult.indicators.atr.value! > 0) {
    const accountValue = riskguard.calculatePortfolioValue(portfolioState);
    const dynamicQty = riskguard.calculateDynamicPositionSize(
      accountValue,
      config.riskPerTrade || 0.01,
      multiIndicatorResult.indicators.atr.value!,
      config.atrMultiplier || 2
    );
    if (dynamicQty > 0) {
      quantity = dynamicQty;
    }
  }

  if (config.maxContracts != null && quantity > config.maxContracts) {
    quantity = config.maxContracts;
  }

  const proposal = {
    symbol,
    contractId,
    action: overallSignal,
    quantity,
    price: lastPrice,
    notional: lastPrice * quantity * contractMultiplier,
    contractMultiplier,
    interval,
    reason,
  };

  if (config.maxNotional != null && proposal.notional > config.maxNotional) {
    return {
      status: "rejected",
      reason: "Max notional exceeded",
      proposal,
      multiIndicatorResult,
    };
  }

  if (config.maxDailyLoss != null &&
    portfolioState?.dailyPnl != null &&
    Number(portfolioState.dailyPnl) < -Math.abs(config.maxDailyLoss)) {
    return {
      status: "rejected",
      reason: "Max daily loss exceeded",
      proposal,
      multiIndicatorResult,
    };
  }

  let assessment: any = { approved: true, skipped: true };
  if (!config.skipRiskGuard && overallSignal !== "HOLD") {
    assessment = await riskguard.assessTrade(
      {
        symbol: contractId,
        quantity,
        price: lastPrice * contractMultiplier,
        action: overallSignal,
      },
      portfolioState,
      {
        maxPositionSize: config.maxContracts,
        maxPortfolioConcentration: 1.0,
      },
      marketData
    );
  }

  if (!config.skipSignalUpdate) {
    const signalDocId = interval === "1d" ?
      `${contractId}` :
      `${contractId}_${interval}`;
    const now = new Date();
    await db.doc(`signals/${signalDocId}`).set({
      timestamp: now.getTime(),
      date: new Date(now.getFullYear(), now.getMonth(), now.getDate()),
      symbol,
      contractId,
      interval,
      signal: overallSignal,
      reason,
      multiIndicatorResult,
      currentPrice: lastPrice,
      config,
      proposal,
      assessment,
    });
  }

  if (overallSignal === "HOLD") {
    return {
      status: "rejected",
      reason,
      proposal,
      multiIndicatorResult,
    };
  }

  if (!assessment?.approved) {
    return {
      status: "rejected",
      reason: assessment?.reason || "RiskGuard rejected",
      proposal,
      assessment,
      multiIndicatorResult,
    };
  }

  return {
    status: "approved",
    proposal,
    assessment,
    multiIndicatorResult,
  };
}

export const getFuturesSignals = onCall(async (request) => {
  try {
    return await performFuturesSignal(request);
  } catch (err) {
    logger.error("getFuturesSignals failed", err);
    return { status: "error", message: (err as Error).message };
  }
});
