import * as riskguard from "./riskguard-agent";
import { onCall } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as indicators from "./technical-indicators";
import { optimizeSignal } from "./signal-optimizer";
import { getMacroAssessment } from "./macro-agent";
import { getMarketData } from "./market-data";
import { fetchGammaExposure, evaluateGammaExposure } from "./gamma-exposure";
import { handleAgenticDecision } from "./agentic-agent";
import { getFirestore } from "firebase-admin/firestore";

const db = getFirestore();
const SHARED_CONTEXT_TTL_MS = 5 * 60 * 1000;

type MacroAssessment = Awaited<ReturnType<typeof getMacroAssessment>>;

let macroAssessmentCache: {
  expiresAt: number;
  promise: Promise<MacroAssessment>;
} | null = null;

const marketIndexCache = new Map<string, {
  expiresAt: number;
  promise: Promise<any>;
}>();

/**
 * Returns one shared macro assessment for adjacent signal calculations.
 * @return {Promise<MacroAssessment>} Shared macro assessment promise.
 */
function getSharedMacroAssessment(): Promise<MacroAssessment> {
  const now = Date.now();
  if (macroAssessmentCache && macroAssessmentCache.expiresAt > now) {
    return macroAssessmentCache.promise;
  }

  const promise = db.collection("macro_assessments")
    .orderBy("timestamp", "desc")
    .limit(1)
    .get()
    .then((snapshot) => {
      if (!snapshot.empty) {
        const doc = snapshot.docs[0];
        logger.info(`Using persisted macro assessment ${doc.id}`);
        return doc.data() as MacroAssessment;
      }
      return getMacroAssessment();
    }).catch((error) => {
      macroAssessmentCache = null;
      throw error;
    });
  macroAssessmentCache = {
    expiresAt: now + SHARED_CONTEXT_TTL_MS,
    promise,
  };
  return promise;
}

/**
 * Returns shared daily index data for concurrent signal calculations.
 * @param {string} symbol Market index symbol.
 * @param {number} fastPeriod Fast moving-average period.
 * @param {number} slowPeriod Slow moving-average period.
 * @return {Promise<any>} Shared market data promise.
 */
function getSharedMarketIndexData(
  symbol: string,
  fastPeriod: number,
  slowPeriod: number
): Promise<any> {
  const cacheKey = `${symbol}:${fastPeriod}:${slowPeriod}`;
  const now = Date.now();
  const cached = marketIndexCache.get(cacheKey);
  if (cached && cached.expiresAt > now) return cached.promise;

  const promise = getMarketData(
    symbol,
    fastPeriod,
    slowPeriod,
    "1d"
  ).catch((error) => {
    marketIndexCache.delete(cacheKey);
    throw error;
  });
  marketIndexCache.set(cacheKey, {
    expiresAt: now + SHARED_CONTEXT_TTL_MS,
    promise,
  });
  return promise;
}


/**
 * Handle Alpha agent logic for trade signal and risk assessment.
 * Uses multi-indicator analysis (Price Movement, Momentum,
 * Market Direction, Volume)
 * @param {object} marketData - Market data including closes,
 *                               volumes, and symbol.
 * @param {object} portfolioState - Current portfolio state.
 * @param {object} config - Trading configuration.
 * @param {string} interval - Chart interval (1d, 1h, 30m, 15m).
 * @return {Promise<object>} The result of the Alpha agent task.
 */
export async function handleAlphaTask(marketData: any,
  portfolioState: any, config: any, interval = "1d") {
  const logMsg = "Alpha agent: handleAlphaTask called " +
    "with multi-indicator analysis";
  logger.info(logMsg, { marketData, portfolioState, config, interval });

  const opens: number[] = marketData?.opens || [];
  const highs: number[] = marketData?.highs || [];
  const lows: number[] = marketData?.lows || [];
  const closes: number[] = marketData?.closes || [];
  const volumes: number[] = marketData?.volumes || [];
  const symbol = marketData?.symbol || "SPY";

  // Fetch market index data (SPY by default, or QQQ if configured)
  const marketIndexSymbol = config?.marketIndexSymbol || "SPY";

  // Determine if GEX is enabled for this run
  const enabledIndicatorKeys: string[] = config?.enabledIndicators ?
    Object.entries(config.enabledIndicators)
      .filter(([, v]) => v === true)
      .map(([k]) => k) :
    [];
  const gexEnabled = enabledIndicatorKeys.includes("gammaExposure") ||
    enabledIndicatorKeys.length === 0; // also fetch if all indicators active

  const [marketIndexData, macroAssessment, gexData] = await Promise.all([
    getSharedMarketIndexData(
      marketIndexSymbol,
      config?.smaPeriodFast || 10,
      config?.smaPeriodSlow || 30
    ),
    getSharedMacroAssessment(),
    gexEnabled ? fetchGammaExposure(
      symbol,
      undefined,
      undefined,
      undefined,
      config?.gexCacheOnly === true
    ).catch((e) => {
      logger.warn(`GEX fetch failed for ${symbol}`, e);
      return null;
    }) : Promise.resolve(null),
  ]);

  // Log detailed market data for debugging cache consistency
  const lastFewPrices = marketIndexData.closes.slice(-5);
  logger.info("📊 Market index data retrieved", {
    symbol: marketIndexSymbol,
    pricesLength: marketIndexData.closes.length,
    volumesLength: marketIndexData.volumes.length,
    lastFivePrices: lastFewPrices,
    lastPrice: lastFewPrices[lastFewPrices.length - 1],
  });

  // Evaluate all 20 technical indicators
  const indicatorConfig = {
    rsiPeriod: config?.rsiPeriod || 14,
    rocPeriod: config?.rocPeriod || 9,
    marketFastPeriod: config?.smaPeriodFast || 10,
    marketSlowPeriod: config?.smaPeriodSlow || 30,
    customIndicators: config?.customIndicators || [],
    enabledIndicators: enabledIndicatorKeys.length > 0 ?
      enabledIndicatorKeys : undefined,
  };

  logger.info(`📊 Evaluating indicators for ${symbol} with config`, {
    marketFastPeriod: indicatorConfig.marketFastPeriod,
    marketSlowPeriod: indicatorConfig.marketSlowPeriod,
    configSmaPeriodFast: config?.smaPeriodFast,
    configSmaPeriodSlow: config?.smaPeriodSlow,
    marketDataClosesLength: marketIndexData.closes.length,
    symbolDataClosesLength: closes.length,
    marketIndexDataLastFive: marketIndexData.closes.slice(-5),
    gexEnabled,
    gexAvailable: !!gexData,
  });

  // Pre-compute GEX indicator result if data available
  const gammaExposureResult = gexData ?
    evaluateGammaExposure(gexData) :
    undefined;

  const multiIndicatorResult = indicators.evaluateAllIndicators(
    { opens, highs, lows, closes, volumes },
    marketIndexData,
    indicatorConfig,
    gammaExposureResult
  );

  const lastPrice = closes.length > 0 ?
    closes[closes.length - 1] : marketData?.currentPrice || 0;

  // --- AGENTIC REASONING MODE BRANCH ---
  if (config?.tradingMode === "reasoning") {
    try {
      const agenticResult = await handleAgenticDecision(
        symbol,
        interval,
        marketData,
        multiIndicatorResult,
        macroAssessment,
        gexData,
        portfolioState,
        config
      );

      const quantity = agenticResult.quantity || config?.tradeQuantity || 1;
      const proposal = {
        symbol,
        action: agenticResult.signal,
        reason: agenticResult.reason,
        confidence: agenticResult.confidence,
        quantity,
        price: lastPrice,
        interval,
        multiIndicatorResult,
        gexData,
        macroAssessment,
        agenticResult,
        agentic: true,
      };

      // Run RiskGuard even for Agentic mode to ensure safety
      let assessment;
      if (config?.skipRiskGuard) {
        assessment = {
          approved: agenticResult.signal !== "HOLD",
          skipped: true,
          reason: "RiskGuard skipped by configuration",
          metrics: {},
        };
      } else {
        assessment = await riskguard.assessTrade(
          proposal, portfolioState, config,
          {
            ...marketData,
            marketIndexCloses: marketIndexData.closes,
          });
      }

      // If agentic decision is to HOLD, follow standard rejection flow
      if (agenticResult.signal === "HOLD" || !assessment.approved) {
        return {
          status: "rejected",
          message: `Agentic: ${agenticResult.reason}. ` +
            `RiskGuard Approved: ${assessment.approved}`,
          reason: agenticResult.reason,
          signal: "HOLD",
          interval,
          multiIndicatorResult,
          agentic: true,
          assessment,
          analysis: {
            score: agenticResult.confidence,
            reason: agenticResult.reason,
          },
        };
      }

      // If approved, proceed with the proposed quantity from agent
      return {
        status: "approved",
        message: `Agentic approved ${agenticResult.signal} for ${symbol}`,
        proposal,
        assessment,
        agentic: true,
        analysis: {
          score: agenticResult.confidence,
          reason: agenticResult.reason,
        },
      };
    } catch (err) {
      logger.error(`Error in Agentic decision for ${symbol}`, err);
      throw err;
    }
  }

  // --- SYSTEMATIC RULES (ALGO) MODE CONTINUES ---

  // Integrate Macro Assessment
  if (macroAssessment) {
    multiIndicatorResult.macroAssessment = {
      status: macroAssessment.status,
      score: macroAssessment.score,
      reason: macroAssessment.reason,
    };

    // Adjust signal strength based on macro score
    if (macroAssessment.status === "RISK_OFF" &&
      multiIndicatorResult.overallSignal === "BUY") {
      multiIndicatorResult.signalStrength = Math.max(0,
        multiIndicatorResult.signalStrength - 15);
      multiIndicatorResult.reason += " (Macro Risk Off: -15 confidence)";
    } else if (macroAssessment.status === "RISK_ON" &&
      multiIndicatorResult.overallSignal === "BUY") {
      multiIndicatorResult.signalStrength = Math.min(100,
        multiIndicatorResult.signalStrength + 10);
      multiIndicatorResult.reason += " (Macro Risk On: +10 confidence)";
    }
  }

  // Check if indicators have changed since last run to avoid expensive ML calls
  const signalDocId = interval === "1d" ?
    `${symbol}` : `${symbol}_${interval}`;
  let previousSignalDoc: any = null;
  try {
    const doc = await db.doc(`signals/${signalDocId}`).get();
    if (doc.exists) {
      previousSignalDoc = doc.data();
    }
  } catch (e) {
    logger.warn(`Error fetching previous signal for ${symbol}`, e);
  }

  let optimization: any = null;
  let indicatorsChanged = true;

  if (previousSignalDoc && previousSignalDoc.multiIndicatorResult) {
    // Simple string comparison of indicators object
    // This assumes key order stability which is generally true in V8
    const prevIndicators = JSON.stringify(
      previousSignalDoc.multiIndicatorResult.indicators
    );
    const currIndicators = JSON.stringify(multiIndicatorResult.indicators);
    if (prevIndicators === currIndicators) {
      indicatorsChanged = false;
      logger.info(`Indicators unchanged for ${symbol}, ` +
        "reusing previous optimization");
      // Reuse previous optimization if available
      optimization = previousSignalDoc.optimization;
    }
  }

  // Optimize signal with ML
  // Only run optimization if indicators changed
  if (indicatorsChanged) {
    try {
      optimization = await optimizeSignal(
        symbol,
        interval,
        multiIndicatorResult,
        { opens, highs, lows, closes, volumes },
        marketIndexData
      );
    } catch (error) {
      logger.error(`Error running signal optimization for ${symbol}`, error);
    }
  }

  let { allGreen, indicators: indicatorResults,
    overallSignal, reason } = multiIndicatorResult;

  // Apply ML Optimization (Smart Filter)
  if (optimization && optimization.confidenceScore > 75) {
    // If ML strongly disagrees with a trade signal, downgrade to HOLD
    if (overallSignal !== "HOLD" &&
      optimization.refinedSignal === "HOLD") {
      logger.info(
        `📉 ML Optimization for ${symbol} downgraded ${overallSignal} ` +
        "to HOLD",
        {
          original: overallSignal,
          mlSignal: optimization.refinedSignal,
          confidence: optimization.confidenceScore,
          reason: optimization.reasoning,
        }
      );
      overallSignal = "HOLD";
      reason = `ML Optimization: ${optimization.reasoning}. ` +
        `(Was: ${multiIndicatorResult.overallSignal})`;
      // Update the result object for storage consistency
      multiIndicatorResult.overallSignal = "HOLD";
      multiIndicatorResult.reason = reason;
    } else if (overallSignal === "HOLD" &&
      optimization.refinedSignal !== "HOLD") {
      // If ML strongly disagrees with a HOLD signal, upgrade to BUY/SELL
      logger.info(
        `📈 ML Optimization for ${symbol} upgraded HOLD to ` +
        `${optimization.refinedSignal}`,
        {
          original: overallSignal,
          mlSignal: optimization.refinedSignal,
          confidence: optimization.confidenceScore,
          reason: optimization.reasoning,
        }
      );
      overallSignal = optimization.refinedSignal;
      reason = `ML Optimization: ${optimization.reasoning}. (Was: HOLD)`;
      // Update the result object for storage consistency
      multiIndicatorResult.overallSignal = optimization.refinedSignal;
      multiIndicatorResult.reason = reason;
    }
  }

  logger.info("Multi-indicator evaluation", {
    allGreen,
    overallSignal,
    interval,
    symbol,
    marketIndexSymbol,
    indicators: indicatorResults,
  });


  // Calculate indicator statistics for reporting
  const indicatorValues = [
    ...Object.values(multiIndicatorResult.indicators),
    ...(multiIndicatorResult.customIndicators ?
      Object.values(multiIndicatorResult.customIndicators) : []),
  ];
  const totalIndicators = indicatorValues.length;
  const buyCount = indicatorValues.filter(
    (i: any) => i.signal === "BUY").length;
  const sellCount = indicatorValues.filter(
    (i: any) => i.signal === "SELL").length;
  const holdCount = indicatorValues.filter(
    (i: any) => i.signal === "HOLD").length;
  const alignedCount = overallSignal === "BUY" ? buyCount :
    (overallSignal === "SELL" ? sellCount : holdCount);

  const analysis = {
    score: multiIndicatorResult.signalStrength,
    consensus: {
      buy: buyCount,
      sell: sellCount,
      hold: holdCount,
      total: totalIndicators,
      aligned: alignedCount,
    },
    supportingIndicators: indicatorValues
      .filter((i: any) => i.signal === overallSignal)
      .map((i: any) => i.name),
    conflictingIndicators: indicatorValues
      .filter((i: any) => i.signal !== overallSignal && i.signal !== "HOLD")
      .map((i: any) => i.name),
    macroImpact: multiIndicatorResult.macroAssessment ? {
      status: multiIndicatorResult.macroAssessment.status,
      score: multiIndicatorResult.macroAssessment.score,
    } : null,
  };

  const supportingStr = analysis.supportingIndicators.join(", ");
  const outputMessage = `Alpha agent: ${overallSignal} (${interval}). ` +
    `Score: ${analysis.score}/100. ` +
    `Driven by: ${supportingStr || "None"}. ` +
    `Consensus: ${alignedCount}/${totalIndicators} indicators aligned.`;

  // If not all indicators are green, hold
  if (overallSignal === "HOLD") {
    // Persist signal only if it changed from the previous signal
    if (!config?.skipSignalUpdate) {
      const prevResult = previousSignalDoc?.multiIndicatorResult;
      const currResult = multiIndicatorResult;

      const signalChanged = !previousSignalDoc ||
        previousSignalDoc.signal !== overallSignal ||
        previousSignalDoc.reason !== reason ||
        JSON.stringify(prevResult) !== JSON.stringify(currResult);

      if (signalChanged) {
        try {
          const { getFirestore } = await import("firebase-admin/firestore");
          const db = getFirestore();
          const signalDocId = interval === "1d" ?
            symbol : `${symbol}_${interval}`;
          const now = new Date();
          const signalDoc = {
            timestamp: now.getTime(),
            date: new Date(now.getFullYear(), now.getMonth(), now.getDate()),
            symbol: symbol,
            interval: interval,
            signal: overallSignal,
            reason,
            multiIndicatorResult,
            optimization,
            currentPrice: marketData.currentPrice,
            config,
            portfolioState,
            diagnostics: {
              signalChangedAt: now.getTime(),
            },
          };
          await db.doc(`signals/${signalDocId}`).set(signalDoc);
          logger.info(
            `Alpha agent stored HOLD signal for ${interval} (${symbol})`,
            signalDoc
          );
        } catch (err) {
          logger.warn(`Failed to persist trade signal for ${symbol}`, err);
        }
      } else {
        const now = new Date();
        await db.doc(`signals/${signalDocId}`).set({
          timestamp: now.getTime(),
          date: new Date(now.getFullYear(), now.getMonth(), now.getDate()),
          currentPrice: marketData.currentPrice,
          diagnostics: {
            lastSuccessfulCalculationAt: now.getTime(),
          },
        }, { merge: true });
        logger.info(
          `Signal unchanged for ${symbol} - refreshed calculation timestamp`
        );
      }
    } else {
      logger.info(`Skipping signal update for ${symbol} (HOLD)`);
    }

    return {
      status: "rejected",
      message: outputMessage,
      reason,
      signal: overallSignal,
      interval,
      multiIndicatorResult,
      optimization,
      analysis,
    };
  }

  let quantity = config?.tradeQuantity || 1;
  let dynamicSizingDetails: any = null;

  // Dynamic Position Sizing (RiskGuard Expansion)
  // Only apply for BUY signals as this is an entry sizing model
  if (config?.enableDynamicPositionSizing && overallSignal === "BUY") {
    const atrValue = multiIndicatorResult.indicators.atr.value;
    if (atrValue && atrValue > 0) {
      const accountValue = riskguard.calculatePortfolioValue(portfolioState);
      // Default risk per trade 1% (0.01), ATR multiplier 2
      const riskPerTrade = config.riskPerTrade || 0.01;
      const atrMultiplier = config.atrMultiplier || 2;

      let dynamicQty = riskguard.calculateDynamicPositionSize(
        accountValue,
        riskPerTrade,
        atrValue,
        atrMultiplier
      );

      const rawCalculatedQty = dynamicQty;
      let cappedBy = null;

      if (dynamicQty > 0) {
        // --- Apply Risk Limits to Dynamic Quantity ---
        const currentPosition = riskguard.getCurrentPosition(portfolioState,
          symbol);

        // 1. Max Position Size Cap
        const maxPositionSize = config.maxPositionSize || 100;
        const availableSpace = Math.max(0, maxPositionSize - currentPosition);

        if (dynamicQty > availableSpace) {
          logger.info("Dynamic Position Sizing: Capping quantity " +
            `${dynamicQty} to available space ${availableSpace} ` +
            `(Max ${maxPositionSize}, Current ${currentPosition})`);
          dynamicQty = availableSpace;
          cappedBy = "maxPositionSize";
        }

        // 2. Max Portfolio Concentration Cap
        const maxPortfolioConcentration =
          config.maxPortfolioConcentration || 0.5;
        if (lastPrice > 0) {
          const maxValue = accountValue * maxPortfolioConcentration;
          const maxTotalQty = Math.floor(maxValue / lastPrice);
          const availableQtyByConc = Math.max(0, maxTotalQty - currentPosition);

          if (dynamicQty > availableQtyByConc) {
            logger.info("Dynamic Position Sizing: Capping quantity " +
              `${dynamicQty} to concentration limit ${availableQtyByConc} ` +
              `(MaxConc ${maxPortfolioConcentration}, Price ${lastPrice})`);
            dynamicQty = availableQtyByConc;
            cappedBy = "maxPortfolioConcentration";
          }
        }

        if (dynamicQty > 0) {
          quantity = dynamicQty;
          logger.info(
            `Dynamic Position Sizing: Final quantity ${quantity} ` +
            `based on Account Value $${accountValue.toFixed(2)}, ` +
            `Risk ${riskPerTrade * 100}%, ATR ${atrValue.toFixed(2)}, ` +
            `Multiplier ${atrMultiplier}`);
        } else {
          logger.warn("Dynamic Position Sizing: Calculated 0 quantity after " +
            "risk caps, falling back to fixed quantity");
        }
      } else {
        logger.warn("Dynamic Position Sizing: Calculated 0 quantity, " +
          "falling back to fixed quantity");
      }

      dynamicSizingDetails = {
        rawCalculatedQty,
        finalQty: quantity,
        cappedBy,
        atr: atrValue,
        riskPerTrade,
        atrMultiplier,
        accountValue,
      };
    } else {
      logger.warn("Dynamic Position Sizing: ATR not available, " +
        "falling back to fixed quantity");
    }
  }

  // --- Macro Risk Adjustment ---
  // If enabled, reduce position size by user-configured
  // % (default 50%) during RISK_OFF conditions
  if (config?.reduceSizeOnRiskOff &&
    overallSignal === "BUY" &&
    multiIndicatorResult.macroAssessment?.status === "RISK_OFF") {
    const originalQty = quantity;
    const reductionPercent = config.riskOffSizeReduction || 0.5;
    const keepPercent = 1.0 - reductionPercent;
    // Reduce by %, floor to integer
    quantity = Math.floor(quantity * keepPercent);

    logger.info(`⚠️ Macro Risk Off: Reduced quantity from ${originalQty} ` +
      `to ${quantity} (${reductionPercent * 100}% reduction)`);

    reason += ` (Size reduced ${reductionPercent * 100}% due to RISK_OFF)`;

    if (dynamicSizingDetails) {
      dynamicSizingDetails.macroRiskData = {
        status: "RISK_OFF",
        action: `reduce_${reductionPercent * 100}_percent`,
        originalQty,
        finalQty: quantity,
      };
    }
  }

  const proposal = {
    symbol,
    action: overallSignal,
    reason: reason,
    quantity,
    price: lastPrice,
    interval,
    multiIndicatorResult,
    dynamicSizingDetails,
  };

  // Call riskguard to assess
  let assessment;
  if (config?.skipRiskGuard) {
    logger.info("Skipping RiskGuard assessment due to skipRiskGuard config");
    assessment = {
      approved: true,
      skipped: true,
      reason: "RiskGuard skipped by configuration",
      metrics: {},
    };
  } else {
    assessment = await riskguard.assessTrade(
      proposal, portfolioState, config,
      {
        ...marketData,
        marketIndexCloses: marketIndexData.closes,
      });
  }

  // Persist trade signal to Firestore only if it changed
  if (!config?.skipSignalUpdate) {
    const prevResult = previousSignalDoc?.multiIndicatorResult;
    const currResult = multiIndicatorResult;

    const signalChanged = !previousSignalDoc ||
      previousSignalDoc.signal !== overallSignal ||
      previousSignalDoc.reason !== reason ||
      JSON.stringify(prevResult) !== JSON.stringify(currResult);

    if (signalChanged) {
      try {
        const { getFirestore } = await import("firebase-admin/firestore");
        const db = getFirestore();
        const signalDocId = interval === "1d" ?
          symbol : `${symbol}_${interval}`;
        const now = new Date();
        const signalDoc = {
          timestamp: now.getTime(),
          date: new Date(now.getFullYear(), now.getMonth(), now.getDate()),
          symbol: symbol,
          interval: interval,
          signal: overallSignal,
          reason,
          multiIndicatorResult,
          optimization,
          currentPrice: marketData.currentPrice,
          config,
          portfolioState,
          proposal,
          assessment,
          diagnostics: {
            signalChangedAt: now.getTime(),
          },
        };
        await db.doc(`signals/${signalDocId}`).set(signalDoc);
        logger.info(`Alpha agent stored ${interval} trade signal`, signalDoc);
      } catch (err) {
        logger.warn(`Failed to persist trade signal for ${symbol}`, err);
      }
    } else {
      const now = new Date();
      await db.doc(`signals/${signalDocId}`).set({
        timestamp: now.getTime(),
        date: new Date(now.getFullYear(), now.getMonth(), now.getDate()),
        currentPrice: marketData.currentPrice,
        diagnostics: {
          lastSuccessfulCalculationAt: now.getTime(),
        },
      }, { merge: true });
      logger.info(
        `Signal unchanged for ${symbol} - refreshed calculation timestamp`
      );
    }
  } else {
    logger.info(`Skipping signal update for ${symbol} (${overallSignal})`);
  }

  if (!assessment.approved) {
    return {
      status: "rejected",
      message: `RiskGuard agent rejected the proposal: ${assessment.reason}`,
      reason: assessment.reason,
      proposal: proposal,
      assessment: assessment,
      interval,
      multiIndicatorResult,
      optimization,
      analysis,
    };
  }

  return {
    status: "approved",
    message: outputMessage,
    proposal: proposal,
    assessment: assessment,
    interval,
    multiIndicatorResult,
    optimization,
    analysis,
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
