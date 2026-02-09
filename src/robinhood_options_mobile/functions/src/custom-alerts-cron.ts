import { onSchedule } from "firebase-functions/v2/scheduler";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { logger } from "firebase-functions";
import { getMarketData } from "./market-data";
import { computeSMA, computeRSI } from "./technical-indicators";

const db = getFirestore();
const messaging = getMessaging();

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

      const currentVolume = volumes.length > 0 ?
        volumes[volumes.length - 1] : 0;
      // Calculate basic volatility (daily range percentage)
      // (High - Low) / Open? Or just absolute change from yesterday?
      // Let's use % change from previous close for "percent_change" condition
      const prevClose = closes.length > 1 ?
        closes[closes.length - 2] : currentPrice;
      const percentChange = ((currentPrice - prevClose) / prevClose) * 100;

      for (const alert of alertsBySymbol[symbol]) {
        let triggered = false;
        let triggerValue = 0;
        let message = "";

        // Check cooldown (default 60 mins)
        const lastTriggered = alert.lastTriggered instanceof Timestamp ?
          alert.lastTriggered.toMillis() :
          alert.lastTriggered; // if number
        const cooldownMs = (alert.cooldownMinutes || 60) * 60 * 1000;
        if (lastTriggered && (Date.now() - lastTriggered) < cooldownMs) {
          continue;
        }

        switch (alert.type) {
        case "price":
          if (alert.condition === "above" && currentPrice > alert.value) {
            triggered = true;
            triggerValue = currentPrice;
            message = `Price for ${symbol} is $${currentPrice.toFixed(2)} ` +
              `(Target: > $${alert.value})`;
          } else if (alert.condition === "below" &&
            currentPrice < alert.value) {
            triggered = true;
            triggerValue = currentPrice;
            message = `Price for ${symbol} is $${currentPrice.toFixed(2)} ` +
              `(Target: < $${alert.value})`;
          }
          break;

        case "volume":
          // Check usage for Volume Spike
          if (alert.condition === "spike" || alert.condition === "above") {
            if (currentVolume > alert.value) {
              triggered = true;
              triggerValue = currentVolume;
              message = `Volume for ${symbol} spiked to ` +
                `${currentVolume.toLocaleString()} ` +
                `(Target: > ${alert.value.toLocaleString()})`;
            }
          }
          break;

        case "volatility":
          // Using percent change as a proxy for volatility/movement for now
          if (alert.condition === "percent_change") {
            if (Math.abs(percentChange) > alert.value) {
              triggered = true;
              triggerValue = percentChange;
              message = `${symbol} moved ${percentChange.toFixed(2)}% ` +
                `(Target: > ${alert.value}%)`;
            }
          }
          break;

        case "moving_average": {
          if (!alert.period) break;
          const sma = computeSMA(closes, alert.period);
          if (sma !== null) {
            if (alert.condition === "above" && sma > alert.value) {
              triggered = true;
              triggerValue = sma;
              message = `SMA(${alert.period}) for ${symbol} is ` +
                `${sma.toFixed(2)} (Target: > ${alert.value})`;
            } else if (alert.condition === "below" && sma < alert.value) {
              triggered = true;
              triggerValue = sma;
              message = `SMA(${alert.period}) for ${symbol} is ` +
                `${sma.toFixed(2)} (Target: < ${alert.value})`;
            }
          }
          break;
        }

        case "rsi": {
          if (!alert.period) break;
          const rsi = computeRSI(closes, alert.period);
          if (rsi !== null) {
            if (alert.condition === "above" && rsi > alert.value) {
              triggered = true;
              triggerValue = rsi;
              message = `RSI(${alert.period}) for ${symbol} is ` +
                `${rsi.toFixed(2)} (Target: > ${alert.value})`;
            } else if (alert.condition === "below" && rsi < alert.value) {
              triggered = true;
              triggerValue = rsi;
              message = `RSI(${alert.period}) for ${symbol} is ` +
                `${rsi.toFixed(2)} (Target: < ${alert.value})`;
            }
          }
          break;
        }
        }

        if (triggered) {
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
