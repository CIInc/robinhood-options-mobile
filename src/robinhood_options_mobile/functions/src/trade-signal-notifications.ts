/**
 * Trade Signal Notifications Firebase Functions
 *
 * Sends push notifications to users when trade signals are created or updated
 * in the agentic_trading collection. Notifications are sent when signals change
 * to BUY or SELL based on user preferences.
 */

import * as logger from "firebase-functions/logger";
import {
  onDocumentCreated,
  onDocumentUpdated,
} from "firebase-functions/v2/firestore";
import { getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";

const db = getFirestore();
const messaging = getMessaging();

/**
 * Interface for trade signal document data
 */
interface TradeSignal {
  symbol: string;
  signal: string; // BUY, SELL, or HOLD
  interval?: string; // 1d, 1h, 30m, 15m
  timestamp: number;
  confidence?: number;
  smaFast?: number;
  smaSlow?: number;
  rsi?: number;
  macd?: number;
  volume?: number;
  price?: number;
}

/**
 * Interface for user notification settings
 */
interface NotificationSettings {
  enabled: boolean;
  signalTypes: string[];
  symbols: string[];
  intervals: string[];
  includeHold: boolean;
  minConfidence?: number;
}

/**
 * Check if signal matches user preferences
 * @param {TradeSignal} signal The trade signal to check
 * @param {NotificationSettings} settings The user's notification settings
 * @return {boolean} True if user should be notified
 */
function shouldNotifyUser(
  signal: TradeSignal,
  settings: NotificationSettings
): boolean {
  // Check if notifications are enabled
  if (!settings.enabled) {
    return false;
  }

  // Check signal type (BUY, SELL, HOLD)
  if (!settings.includeHold && signal.signal === "HOLD") {
    return false;
  }

  if (
    settings.signalTypes.length > 0 &&
    !settings.signalTypes.includes(signal.signal)
  ) {
    return false;
  }

  // Check symbol filter
  if (
    settings.symbols.length > 0 &&
    !settings.symbols.includes(signal.symbol)
  ) {
    return false;
  }

  // Check interval filter
  const signalInterval = signal.interval || "1d";
  if (
    settings.intervals.length > 0 &&
    !settings.intervals.includes(signalInterval)
  ) {
    return false;
  }

  // Check confidence threshold
  if (
    settings.minConfidence !== undefined &&
    signal.confidence !== undefined &&
    signal.confidence < settings.minConfidence
  ) {
    return false;
  }

  return true;
}

/**
 * Get formatted interval label
 * @param {string} interval The interval code
 * @return {string} The formatted label
 */
function getIntervalLabel(interval?: string): string {
  if (!interval || interval === "1d") return "Daily";
  if (interval === "1h") return "Hourly";
  if (interval === "30m") return "30-min";
  if (interval === "15m") return "15-min";
  return interval;
}

/**
 * Send notification to a user about a trade signal
 * @param {string} userId The user ID to notify
 * @param {TradeSignal} signal The trade signal data
 * @param {boolean} isNew True if signal is newly created vs updated
 */
async function sendTradeSignalNotification(
  userId: string,
  signal: TradeSignal,
  isNew: boolean
): Promise<void> {
  try {
    // Fetch user's FCM tokens
    const userDoc = await db.collection("user").doc(userId).get();
    if (!userDoc.exists) {
      logger.warn("User not found for notification", { userId });
      return;
    }

    const userData = userDoc.data();
    const devices: Array<{ fcmToken?: string | null }> =
      userData?.devices || [];
    const fcmTokens: string[] = devices
      .map((device) => device.fcmToken)
      .filter((token): token is string => token != null && token !== "");

    if (fcmTokens.length === 0) {
      logger.info("No FCM tokens found for user", { userId });
      return;
    }

    // Prepare notification
    const intervalLabel = getIntervalLabel(signal.interval);
    const action = signal.signal;
    const title = `${action} Signal: ${signal.symbol}`;
    const priceStr = signal.price ?
      ` at $${signal.price.toFixed(2)}` :
      "";
    const body = isNew ?
      `New ${intervalLabel.toLowerCase()} ${action.toLowerCase()} ` +
      `signal for ${signal.symbol}${priceStr}` :
      `${intervalLabel} signal updated to ${action} for ` +
      `${signal.symbol}${priceStr}`;

    // Add confidence to body if available
    const bodyWithConfidence = signal.confidence !== undefined ?
      `${body} (${(signal.confidence * 100).toFixed(0)}% confidence)` :
      body;

    // Send notification to all user devices
    const response = await messaging.sendEachForMulticast({
      tokens: fcmTokens,
      notification: {
        title: title,
        body: bodyWithConfidence,
      },
      data: {
        type: "trade_signal",
        symbol: signal.symbol,
        signal: signal.signal,
        interval: signal.interval || "1d",
        price: signal.price?.toString() || "",
        confidence: signal.confidence?.toString() || "",
        timestamp: signal.timestamp.toString(),
      },
      android: {
        priority: "high",
        notification: {
          channelId: "trade_signals",
          priority: "high",
          sound: "default",
          clickAction: "FLUTTER_NOTIFICATION_CLICK",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
            category: "TRADE_SIGNAL",
          },
        },
      },
    });

    logger.info("Trade signal notification sent", {
      userId,
      symbol: signal.symbol,
      signal: signal.signal,
      interval: signal.interval,
      successCount: response.successCount,
      failureCount: response.failureCount,
    });

    // Log any failures
    if (response.failureCount > 0) {
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          logger.error("Failed to send notification", {
            userId,
            token: fcmTokens[idx],
            error: resp.error,
          });
        }
      });
    }
  } catch (error) {
    logger.error("Error sending trade signal notification", {
      userId,
      symbol: signal.symbol,
      error,
    });
  }
}

/**
 * Notify all users who should receive notifications for this signal
 * @param {TradeSignal} signal The trade signal to notify about
 * @param {boolean} isNew True if signal is newly created vs updated
 */
async function notifyInterestedUsers(
  signal: TradeSignal,
  isNew: boolean
): Promise<void> {
  try {
    // Only notify for BUY or SELL signals (or HOLD if user enabled it)
    const isActionable = signal.signal === "BUY" ||
      signal.signal === "SELL" ||
      signal.signal === "HOLD";
    if (!isActionable) {
      logger.info("Signal not actionable - skipping notifications", {
        signal: signal.signal,
      });
      return;
    }

    // Fetch all users with notification settings enabled
    const usersSnapshot = await db.collection("user").get();

    const notificationPromises: Promise<void>[] = [];

    usersSnapshot.docs.forEach((userDoc) => {
      const userData = userDoc.data();
      const settings: NotificationSettings | undefined =
        userData?.tradeSignalNotificationSettings;

      // Skip users without notification settings
      if (!settings) {
        return;
      }

      // Check if user should be notified
      if (shouldNotifyUser(signal, settings)) {
        notificationPromises.push(
          sendTradeSignalNotification(userDoc.id, signal, isNew)
        );
      }
    });

    await Promise.all(notificationPromises);

    logger.info("Finished notifying users", {
      symbol: signal.symbol,
      signal: signal.signal,
      userCount: notificationPromises.length,
    });
  } catch (error) {
    logger.error("Error notifying interested users", {
      symbol: signal.symbol,
      error,
    });
  }
}

/**
 * Triggered when a new trade signal document is created
 */
export const onTradeSignalCreated = onDocumentCreated(
  "agentic_trading/{documentId}",
  async (event) => {
    try {
      const signalData = event.data?.data() as TradeSignal | undefined;

      if (!signalData) {
        logger.warn("No signal data found in created document", {
          documentId: event.params.documentId,
        });
        return;
      }

      logger.info("New trade signal created", {
        documentId: event.params.documentId,
        symbol: signalData.symbol,
        signal: signalData.signal,
        interval: signalData.interval,
      });

      await notifyInterestedUsers(signalData, true);
    } catch (error) {
      logger.error("Error in onTradeSignalCreated", {
        documentId: event.params.documentId,
        error,
      });
    }
  }
);

/**
 * Triggered when a trade signal document is updated
 */
export const onTradeSignalUpdated = onDocumentUpdated(
  "agentic_trading/{documentId}",
  async (event) => {
    try {
      const beforeData = event.data?.before.data() as TradeSignal | undefined;
      const afterData = event.data?.after.data() as TradeSignal | undefined;

      if (!beforeData || !afterData) {
        logger.warn("Missing before or after data in updated document", {
          documentId: event.params.documentId,
        });
        return;
      }

      // Only notify if signal changed to BUY or SELL
      // (or from BUY/SELL to different value)
      const signalChanged = beforeData.signal !== afterData.signal;
      const isNowActionableSignal =
        afterData.signal === "BUY" || afterData.signal === "SELL";

      if (!signalChanged || !isNowActionableSignal) {
        logger.info("Signal not changed to actionable signal - skipping", {
          documentId: event.params.documentId,
          before: beforeData.signal,
          after: afterData.signal,
        });
        return;
      }

      logger.info("Trade signal updated to actionable signal", {
        documentId: event.params.documentId,
        symbol: afterData.symbol,
        beforeSignal: beforeData.signal,
        afterSignal: afterData.signal,
        interval: afterData.interval,
      });

      await notifyInterestedUsers(afterData, false);
    } catch (error) {
      logger.error("Error in onTradeSignalUpdated", {
        documentId: event.params.documentId,
        error,
      });
    }
  }
);
