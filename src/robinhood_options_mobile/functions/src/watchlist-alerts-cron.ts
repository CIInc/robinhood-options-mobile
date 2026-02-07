import { onSchedule } from "firebase-functions/v2/scheduler";
import { onRequest } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { logger } from "firebase-functions";
import { getMarketData } from "./market-data";

const db = getFirestore();
const messaging = getMessaging();

/**
 * Result summary for alert monitoring run.
 */
export interface WatchlistAlertsCronResult {
  processedCount: number;
  triggeredCount: number;
  notificationCount: number;
  errorCount: number;
  timestamp: string;
}

/**
 * Interface for alert data
 */
interface WatchlistAlert {
  type: "above" | "below"; // price above/below threshold
  threshold: number;
  active: boolean;
  createdAt: any;
  lastTriggered?: number; // timestamp to prevent duplicate notifications
}

/**
 * Fetch all FCM tokens for a user from their Firestore document.
 * @param {string} userId The user ID to fetch tokens for.
 * @return {Promise<string[]>} Array of FCM tokens for the user.
 */
async function getUserFCMTokens(userId: string): Promise<string[]> {
  try {
    const userDoc = await db.collection("users").doc(userId).get();
    const userData = userDoc.data() as any;
    const fcmTokens = userData?.fcmTokens || [];
    return Array.isArray(fcmTokens) ? fcmTokens : [];
  } catch (e) {
    logger.warn(`Failed to fetch FCM tokens for user ${userId}`, e);
    return [];
  }
}

/**
 * Send notification to group members when alert is triggered.
 * @param {string} groupId The group ID.
 * @param {string} watchlistId The watchlist ID.
 * @param {string} symbol The stock symbol.
 * @param {string} alertType The alert type ("above" or "below").
 * @param {number} threshold The alert threshold.
 * @param {number} currentPrice The current price of the symbol.
 * @return {Promise<number>} Number of successful notifications sent.
 */
async function sendAlertNotification(
  groupId: string,
  watchlistId: string,
  symbol: string,
  alertType: string,
  threshold: number,
  currentPrice: number
): Promise<number> {
  try {
    // Fetch group document to get members
    const groupDoc = await db
      .collection("investor_groups")
      .doc(groupId)
      .get();

    if (!groupDoc.exists) {
      logger.warn(`Group ${groupId} not found`);
      return 0;
    }

    const groupData = groupDoc.data() as any;
    const members = groupData?.members || [];

    if (!Array.isArray(members) || members.length === 0) {
      logger.info(`No members in group ${groupId}`);
      return 0;
    }

    // Collect FCM tokens from all members
    const allTokens: string[] = [];
    for (const memberId of members) {
      const tokens = await getUserFCMTokens(memberId);
      allTokens.push(...tokens);
    }

    if (allTokens.length === 0) {
      logger.info("No FCM tokens found for group members");
      return 0;
    }

    // Create notification message
    const title = `${symbol} Alert Triggered`;
    const currentPriceStr = currentPrice.toFixed(2);
    const thresholdStr = threshold.toFixed(2);
    const messageBody = alertType === "above" ?
      `${symbol} moved above $${thresholdStr} (now $${currentPriceStr})` :
      `${symbol} moved below $${thresholdStr} (now $${currentPriceStr})`;

    const message = {
      notification: {
        title,
        body: messageBody,
      },
      data: {
        groupId,
        watchlistId,
        symbol,
        alertType,
        threshold: threshold.toString(),
        currentPrice: currentPrice.toString(),
      },
      webpush: {
        fcmOptions: {
          link: `robinhoodoptionsmobile://group/${groupId}/watchlist/${watchlistId}`,
        },
      },
    };

    // Send to all tokens at once
    const response = await messaging.sendEachForMulticast(
      allTokens as any,
      message as any
    );

    const successCount = response.successCount;
    logger.info(
      `✅ Sent alert for ${symbol}. ` +
      `Success: ${successCount}/${allTokens.length}`
    );

    return successCount;
  } catch (e) {
    logger.error(
      `Failed to send notification for ${symbol} alert in ` +
      `group ${groupId}`,
      e
    );
    return 0;
  }
}

/**
 * Check if price has crossed the alert threshold.
 * @param {string} alertType The alert type ("above" or "below").
 * @param {number} threshold The alert threshold.
 * @param {number} currentPrice The current price of the symbol.
 * @return {boolean} True if alert should trigger, false otherwise.
 */
function hasAlertTriggered(
  alertType: string,
  threshold: number,
  currentPrice: number
): boolean {
  if (alertType === "above") {
    return currentPrice >= threshold;
  } else if (alertType === "below") {
    return currentPrice <= threshold;
  }
  return false;
}

/**
 * Core logic that scans all watchlist alerts and checks if they trigger.
 * @return {Promise<WatchlistAlertsCronResult>} Summary of alert monitoring run.
 */
export async function runWatchlistAlertsCron():
  Promise<WatchlistAlertsCronResult> {
  logger.info(
    "Watchlist Alerts Cron: Scanning all watchlists " +
    "for active alerts"
  );

  let processedCount = 0;
  let triggeredCount = 0;
  let notificationCount = 0;
  let errorCount = 0;

  try {
    // Get all investor groups
    const groupsSnapshot = await db
      .collection("investor_groups")
      .get();

    for (const groupDoc of groupsSnapshot.docs) {
      const groupId = groupDoc.id;

      try {
        // Get all watchlists in the group
        const watchlistsSnapshot = await db
          .collection("investor_groups")
          .doc(groupId)
          .collection("watchlists")
          .get();

        for (const watchlistDoc of watchlistsSnapshot.docs) {
          const watchlistId = watchlistDoc.id;

          try {
            // Get all symbols in the watchlist
            const symbolsSnapshot = await watchlistDoc.ref
              .collection("symbols")
              .get();

            for (const symbolDoc of symbolsSnapshot.docs) {
              const symbol = symbolDoc.id;

              try {
                // Get all alerts for this symbol
                const alertsSnapshot = await symbolDoc.ref
                  .collection("alerts")
                  .where("active", "==", true)
                  .get();

                if (alertsSnapshot.empty) {
                  continue;
                }

                // Fetch current price for this symbol (only once per symbol)
                let currentPrice: number | null = null;
                try {
                  const marketData = await getMarketData(symbol, 20, 50, "1d");
                  currentPrice = marketData.currentPrice;

                  if (!currentPrice) {
                    logger.warn(
                      `No price data for symbol ${symbol}`
                    );
                    continue;
                  }
                } catch (e) {
                  logger.error(`Failed to fetch price for ${symbol}`, e);
                  errorCount++;
                  continue;
                }

                // Check each alert
                for (const alertDoc of alertsSnapshot.docs) {
                  try {
                    const alertData = alertDoc.data() as WatchlistAlert;
                    const { type, threshold, lastTriggered } = alertData;

                    // Check if alert should trigger
                    if (!hasAlertTriggered(type, threshold, currentPrice)) {
                      continue;
                    }

                    // Prevent duplicate notifications within 1 hour
                    const oneHourAgo = Date.now() - 3600000;
                    if (lastTriggered && lastTriggered > oneHourAgo) {
                      logger.info(
                        "⏭️ Skipping duplicate alert for" +
                        ` ${symbol} (triggered recently)`
                      );
                      continue;
                    }

                    processedCount++;

                    // Send notification to group members
                    const notificationsSent = await sendAlertNotification(
                      groupId,
                      watchlistId,
                      symbol,
                      type,
                      threshold,
                      currentPrice
                    );

                    // Update alert with last triggered timestamp
                    await alertDoc.ref.update({
                      lastTriggered: FieldValue.serverTimestamp(),
                    });

                    if (notificationsSent > 0) {
                      triggeredCount++;
                      notificationCount += notificationsSent;
                      logger.info(
                        `✅ Alert triggered: ${symbol} ${type} ` +
                        `$${threshold} (now: $${currentPrice})`
                      );
                    }
                  } catch (e) {
                    logger.error(`Error processing alert ${alertDoc.id}`, e);
                    errorCount++;
                  }
                }
              } catch (e) {
                logger.error(
                  `Error processing symbol ${symbol} ` +
                  `in watchlist ${watchlistId}`,
                  e
                );
                errorCount++;
              }
            }
          } catch (e) {
            logger.error(
              `Error processing watchlist ${watchlistId} ` +
              `in group ${groupId}`,
              e
            );
            errorCount++;
          }
        }
      } catch (e) {
        logger.error(`Error processing group ${groupId}`, e);
        errorCount++;
      }
    }
  } catch (e) {
    logger.error("Error scanning watchlist alerts", e);
    errorCount++;
  }

  const result: WatchlistAlertsCronResult = {
    processedCount,
    triggeredCount,
    notificationCount,
    errorCount,
    timestamp: new Date().toISOString(),
  };

  logger.info("📊 Watchlist Alerts Cron Summary:", result);
  return result;
}

/**
 * Scheduled function to check watchlist alerts every hour
 */
export const watchlistAlertsCron = onSchedule(
  // "every 1 hours",
  {
    // Run every hour during market hours (9:30 AM - 4:00 PM ET)
    // Monday-Friday at 30 minutes past each hour
    schedule: "30 9-16 * * 1-5",
    timeZone: "America/New_York", // Eastern Time (handles EST/EDT)
  },
  async () => {
    await runWatchlistAlertsCron();
  }
);

/**
 * Callable endpoint for manual alert checking (for testing/debugging)
 */
export const checkWatchlistAlerts = onRequest(
  async (req, res) => {
    try {
      const result = await runWatchlistAlertsCron();
      res.json(result);
    } catch (e) {
      logger.error("Error in checkWatchlistAlerts endpoint", e);
      res.status(500).json({ error: "Failed to check alerts" });
    }
  }
);
