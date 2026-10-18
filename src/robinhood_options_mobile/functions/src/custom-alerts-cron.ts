import { initializeApp, getApps } from "firebase-admin/app";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { logger } from "firebase-functions";
import { getMarketData } from "./market-data";
import { computeSMA, computeRSI, computeATR } from "./technical-indicators";

if (getApps().length === 0) {
  initializeApp();
}

const db = getFirestore();
const messaging = getMessaging();

type AlertRule = {
  type?: string;
  condition?: string;
  value?: number;
  period?: number;
};

type SmartAlertInput = {
  symbol?: string;
  currentPrice?: number;
  closes?: number[];
  volumes?: number[];
  type?: string;
  condition?: string;
  value?: number;
  period?: number;
  logic?: "all" | "any";
  rules?: AlertRule[];
};

type MarketSnapshotInput = {
  symbol?: string;
  currentPrice?: number;
  highs?: number[];
  lows?: number[];
  closes?: number[];
  volumes?: number[];
  percentChange?: number;
  gexData?: {
    totalNetGEX?: number;
    callWall?: number;
    putWall?: number;
    gammaFlip?: number;
    cotmp?: number;
    plusGex?: number;
    dealerPositioning?: string;
  };
  atr?: number;
};

/**
 * Evaluate whether a custom alert should trigger using the current market data.
 * Supports both legacy single-condition alerts and multi-rule smart alerts.
 *
 * @param {SmartAlertInput} alert
 * @param {MarketSnapshotInput} marketSnapshot
 * @return {{ triggered: boolean, triggerValue: number, message: string }}
 */
export function evaluateSmartAlert(
  alert: SmartAlertInput,
  marketSnapshot: MarketSnapshotInput,
): { triggered: boolean; triggerValue: number; message: string } {
  const rules = (alert.rules && alert.rules.length > 0) ?
    alert.rules :
    [{
      type: alert.type,
      condition: alert.condition,
      value: alert.value,
      period: alert.period,
    }];

  const symbol = marketSnapshot.symbol ?? alert.symbol ?? "UNKNOWN";
  const currentPrice = marketSnapshot.currentPrice ?? 0;
  const closes = marketSnapshot.closes ?? [];
  const volumes = marketSnapshot.volumes ?? [];
  const derivedPercentChange = closes.length > 1 ?
    ((closes[closes.length - 1] - closes[closes.length - 2]) /
      Math.max(closes[closes.length - 2], 0.0001)) * 100 :
    0;
  const percentChange = marketSnapshot.percentChange ?? derivedPercentChange;
  const logic = alert.logic ?? "all";

  const evaluated: Array<{
    matched: boolean;
    message: string;
    value: number;
  }> = [];

  for (const rule of rules) {
    const type = rule.type ?? "price";
    const condition = rule.condition ?? "above";
    const value = rule.value ?? 0;
    const period = rule.period ?? 14;

    let matched = false;
    let message = "";
    let triggerValue = 0;

    if (type === "price") {
      if (condition === "above" && currentPrice > value) {
        matched = true;
        triggerValue = currentPrice;
        message = `Price for ${symbol} is $${currentPrice.toFixed(2)} ` +
          `(Target: > $${value})`;
      } else if (condition === "below" && currentPrice < value) {
        matched = true;
        triggerValue = currentPrice;
        message = `Price for ${symbol} is $${currentPrice.toFixed(2)} ` +
          `(Target: < $${value})`;
      }
    } else if (type === "volume") {
      const currentVolume = volumes.length > 0 ?
        volumes[volumes.length - 1] : 0;
      if ((condition === "spike" || condition === "above") &&
        currentVolume > value) {
        matched = true;
        triggerValue = currentVolume;
        message = `Volume for ${symbol} spiked to ` +
          `${currentVolume.toLocaleString()} ` +
          `(Target: > ${value.toLocaleString()})`;
      }
    } else if (type === "volatility") {
      if (condition === "percent_change" && Math.abs(percentChange) > value) {
        matched = true;
        triggerValue = percentChange;
        message = `${symbol} moved ${percentChange.toFixed(2)}% ` +
          `(Target: > ${value}%)`;
      }
    } else if (type === "moving_average") {
      if (!closes.length) {
        matched = false;
      } else {
        const sma = computeSMA(closes, period);
        if (sma !== null) {
          if (condition === "above" && sma > value) {
            matched = true;
            triggerValue = sma;
            message = `SMA(${period}) for ${symbol} is ${sma.toFixed(2)} ` +
              `(Target: > ${value})`;
          } else if (condition === "below" && sma < value) {
            matched = true;
            triggerValue = sma;
            message = `SMA(${period}) for ${symbol} is ${sma.toFixed(2)} ` +
              `(Target: < ${value})`;
          }
        }
      }
    } else if (type === "rsi") {
      if (!closes.length) {
        matched = false;
      } else {
        const rsi = computeRSI(closes, period);
        if (rsi !== null) {
          if (condition === "above" && rsi > value) {
            matched = true;
            triggerValue = rsi;
            message = `RSI(${period}) for ${symbol} is ${rsi.toFixed(2)} ` +
              `(Target: > ${value})`;
          } else if (condition === "below" && rsi < value) {
            matched = true;
            triggerValue = rsi;
            message = `RSI(${period}) for ${symbol} is ${rsi.toFixed(2)} ` +
              `(Target: < ${value})`;
          }
        }
      }
    } else if (type === "gex") {
      const gex = marketSnapshot.gexData;
      if (!gex) {
        matched = false;
      } else if (condition === "above" || condition === "net_gex_above") {
        const netGexM = (gex.totalNetGEX ?? 0) / 1e6;
        if (netGexM > value) {
          matched = true;
          triggerValue = netGexM;
          message = `Net GEX for ${symbol} is $${netGexM.toFixed(2)}M ` +
            `(Target: > $${value}M)`;
        }
      } else if (condition === "below" || condition === "net_gex_below") {
        const netGexM = (gex.totalNetGEX ?? 0) / 1e6;
        if (netGexM < value) {
          matched = true;
          triggerValue = netGexM;
          message = `Net GEX for ${symbol} is $${netGexM.toFixed(2)}M ` +
            `(Target: < $${value}M)`;
        }
      } else if (condition === "above_call_wall" && gex.callWall != null) {
        if (currentPrice >= gex.callWall) {
          matched = true;
          triggerValue = currentPrice;
          message = `${symbol} reached Call Wall ` +
            `($${gex.callWall.toFixed(2)})`;
        }
      } else if (condition === "below_put_wall" && gex.putWall != null) {
        if (currentPrice <= gex.putWall) {
          matched = true;
          triggerValue = currentPrice;
          message = `${symbol} breached Put Wall ` +
            `($${gex.putWall.toFixed(2)})`;
        }
      } else if (condition === "above_gamma_flip" && gex.gammaFlip != null) {
        if (currentPrice >= gex.gammaFlip) {
          matched = true;
          triggerValue = currentPrice;
          message = `${symbol} crossed above Gamma Flip ` +
            `($${gex.gammaFlip.toFixed(2)})`;
        }
      } else if (condition === "below_gamma_flip" && gex.gammaFlip != null) {
        if (currentPrice <= gex.gammaFlip) {
          matched = true;
          triggerValue = currentPrice;
          message = `${symbol} crossed below Gamma Flip ` +
            `($${gex.gammaFlip.toFixed(2)})`;
        }
      }
    } else if (type === "dynamic_threshold" || type === "atr") {
      const highs = marketSnapshot.highs ?? [];
      const lows = marketSnapshot.lows ?? [];
      let atrVal = marketSnapshot.atr;
      if (
        atrVal == null &&
        highs.length >= period &&
        lows.length >= period &&
        closes.length >= period
      ) {
        atrVal = computeATR(highs, lows, closes, period) ?? undefined;
      }
      if (atrVal == null) {
        atrVal = currentPrice * 0.02; // 2% fallback
      }

      const referencePrice = closes.length > 1 ?
        closes[closes.length - 2] : currentPrice;
      const upperBand = referencePrice + value * atrVal;
      const lowerBand = referencePrice - value * atrVal;

      if (condition === "above" || condition === "above_band") {
        if (currentPrice > upperBand) {
          matched = true;
          triggerValue = currentPrice;
          message = `${symbol} broke upper dynamic band ` +
            `($${upperBand.toFixed(2)}, ${value}x ATR)`;
        }
      } else if (condition === "below" || condition === "below_band") {
        if (currentPrice < lowerBand) {
          matched = true;
          triggerValue = currentPrice;
          message = `${symbol} broke lower dynamic band ` +
            `($${lowerBand.toFixed(2)}, ${value}x ATR)`;
        }
      } else if (condition === "spike" || condition === "expansion") {
        if (atrVal > value) {
          matched = true;
          triggerValue = atrVal;
          message = `ATR(${period}) for ${symbol} expanded to ` +
            `$${atrVal.toFixed(2)} (Target: > $${value})`;
        }
      }
    }

    evaluated.push({ matched, message, value: triggerValue });
  }

  if (evaluated.length === 0) {
    return {
      triggered: false,
      triggerValue: 0,
      message: "No valid alert rules",
    };
  }

  const matchedRules = evaluated.filter((entry) => entry.matched);
  const triggered = logic === "any" ?
    matchedRules.length > 0 :
    matchedRules.length === evaluated.length;

  if (!triggered) {
    return {
      triggered: false,
      triggerValue: 0,
      message: "Alert conditions not met",
    };
  }

  const combinedMessage = matchedRules.map((r) => r.message).join(" • ");
  const bestMatch = matchedRules[0] ?? evaluated[0];
  return {
    triggered: true,
    triggerValue: bestMatch.value,
    message: matchedRules.length > 1 ? combinedMessage : bestMatch.message,
  };
}

/**
 * Fetch all FCM tokens for a user.
 * @param {string} userId - The ID of the user.
 * @return {Promise<string[]>} A promise that resolves to an array of tokens.
 */
async function getUserFCMTokens(userId: string): Promise<string[]> {
  try {
    const userDoc = await db.collection("user").doc(userId).get();
    const userData = userDoc.data() as any;
    // Devices expected as array of objects with optional fcmToken
    const devices: Array<{ fcmToken?: string | null }> =
      userData?.devices || [];
    const fcmTokens: string[] = devices
      .map((device) => device.fcmToken)
      .filter((token): token is string => token != null && token !== "");

    if (fcmTokens.length === 0) {
      logger.info("No FCM tokens found for user", { userId });
      return [];
    }
    return Array.isArray(fcmTokens) ? fcmTokens : [];
  } catch (e) {
    logger.warn(`Failed to fetch FCM tokens for user ${userId}`, e);
    return [];
  }
}

/**
 * Check custom alerts periodically.
 */
export const checkCustomAlerts = onSchedule("every 5 minutes", async () => {
  logger.info("Starting checkCustomAlerts...");

  // 1. Get all active alerts
  const alertsSnap = await db.collectionGroup("alerts")
    .where("active", "==", true)
    .get();

  if (alertsSnap.empty) {
    logger.info("No active alerts found.");
    return;
  }

  // 2. Group by symbol
  const alertsBySymbol: { [symbol: string]: any[] } = {};
  alertsSnap.forEach((doc) => {
    const data = doc.data();
    data.id = doc.id;
    data.ref = doc.ref;

    // if (!data.symbol) {
    //   logger.warn(`Alert ${data.id} missing symbol, ` +
    //     `skipping for ${data.userId}`);
    //   // doc.ref.delete();
    //   // Skip alerts with no symbol
    //   return;
    // }

    if (!alertsBySymbol[data.symbol]) {
      alertsBySymbol[data.symbol] = [];
    }
    alertsBySymbol[data.symbol].push(data);
  });

  const symbols = Object.keys(alertsBySymbol);
  logger.info(`Checking alerts for ${symbols.length} symbols: ` +
    `${symbols.join(", ")}`);

  // 3. Process each symbol
  for (const symbol of symbols) {
    try {
      // Determine max period needed for indicators
      let maxPeriod = 21; // Default
      for (const alert of alertsBySymbol[symbol]) {
        if ((alert.type === "moving_average" || alert.type === "rsi") &&
          alert.period) {
          maxPeriod = Math.max(maxPeriod, alert.period + 14); // Buffer
        }
      }

      // Fetch market data
      // (Daily for now, maybe intraday needed for volume/volatility)
      const marketData = await getMarketData(symbol, maxPeriod, maxPeriod,
        "1d");
      const currentPrice = marketData.currentPrice;
      const volumes = marketData.volumes as number[];
      const closes = marketData.closes as number[];

      if (currentPrice === null || currentPrice === undefined) {
        logger.warn(`No price data for ${symbol}`);
        continue;
      }

      // Calculate basic volatility (daily range percentage)
      // (High - Low) / Open? Or just absolute change from yesterday?
      // Let's use % change from previous close for "percent_change" condition
      const prevClose = closes.length > 1 ?
        closes[closes.length - 2] : currentPrice;
      const percentChange = ((currentPrice - prevClose) / prevClose) * 100;

      for (const alert of alertsBySymbol[symbol]) {
        // Check cooldown (default 60 mins)
        const lastTriggered = alert.lastTriggered instanceof Timestamp ?
          alert.lastTriggered.toMillis() :
          alert.lastTriggered; // if number
        const cooldownMs = (alert.cooldownMinutes || 60) * 60 * 1000;
        if (lastTriggered && (Date.now() - lastTriggered) < cooldownMs) {
          continue;
        }

        const evaluation = evaluateSmartAlert(
          {
            symbol,
            type: alert.type,
            condition: alert.condition,
            value: alert.value,
            period: alert.period,
            logic: alert.logic,
            rules: alert.rules,
          },
          {
            symbol,
            currentPrice,
            closes,
            volumes,
            percentChange,
          }
        );

        if (evaluation.triggered) {
          const triggerValue = evaluation.triggerValue;
          const message = evaluation.message;
          logger.info(`Alert triggered for ${symbol}: ${message}`);

          // Send Notification
          if (!alert.userId) {
            logger.warn(`Alert ${alert.id} has no userId`);
          } else {
            const tokens = await getUserFCMTokens(alert.userId);
            if (tokens.length > 0) {
              const notification = {
                tokens: tokens,
                notification: {
                  title: `Alert: ${symbol}`,
                  body: message,
                },
                data: {
                  type: "custom_alert",
                  symbol: symbol,
                  alertId: alert.id,
                  value: triggerValue.toString(),
                },
                apns: {
                  payload: {
                    aps: {
                      sound: "default",
                    },
                  },
                },
              };
              const response = await messaging
                .sendEachForMulticast(notification);
              if (response.failureCount > 0) {
                logger.warn(`Failed to send ${response.failureCount} ` +
                  `notifications for alert ${alert.id}`);
                response.responses.forEach((resp, idx) => {
                  if (!resp.success) {
                    logger.error(`Token ${tokens[idx]} failed: ` +
                      `${resp.error?.message}`);
                  }
                });
              } else {
                logger.info(`Notification sent to ${response.successCount} ` +
                  `devices for alert ${alert.id}`);
              }
            } else {
              logger.warn(`No FCM tokens found for user ${alert.userId}`);
            }
          }

          // Update lastTriggered
          await alert.ref.update({
            lastTriggered: Timestamp.now(),
          });
        }
      }
    } catch (e) {
      logger.error(`Error processing symbol ${symbol}`, e);
    }
  }
});
