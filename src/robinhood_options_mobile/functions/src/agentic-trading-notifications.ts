/**
 * Agentic Trading Notifications
 *
 * Sends push notifications for agentic trading events:
 * - Trade execution (BUY)
 * - Take Profit exits
 * - Stop Loss exits
 * - Emergency stop activation
 * - Daily summary
 */

import * as logger from "firebase-functions/logger";
import { onCall } from "firebase-functions/v2/https";
import { getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";

const db = getFirestore();
const messaging = getMessaging();

/**
 * Interface for notification request
 */
interface NotificationRequest {
  userId: string;
  type:
  | "buy"
  | "take_profit"
  | "stop_loss"
  | "emergency_stop"
  | "daily_summary";
  symbol?: string;
  quantity?: number;
  price?: number;
  profitLoss?: number;
  dailyStats?: {
    totalTrades: number;
    wins: number;
    losses: number;
    totalPnL: number;
  };
}

/**
 * Callable function to send agentic trading notifications
 *
 * Called from the Flutter app when trade events occur
 */
export const sendAgenticTradeNotification = onCall(async (request) => {
  try {
    const data = request.data as NotificationRequest;
    const userId = data.userId;

    // Validate required fields
    if (!userId || !data.type) {
      throw new Error("Missing required fields: userId and type");
    }

    logger.info("Sending agentic trade notification", {
      userId,
      type: data.type,
      symbol: data.symbol,
    });

    // Get user's notification preferences
    const userDoc = await db.collection("user").doc(userId).get();
    if (!userDoc.exists) {
      throw new Error(`User ${userId} not found`);
    }

    const userData = userDoc.data();
    const config = (userData?.agenticTradingConfig || {}) as
      AgenticTradingConfigPrefs;

    // Check if notifications are enabled for this type
    const notificationEnabled = checkNotificationPreference(
      config,
      data.type
    );
    if (!notificationEnabled) {
      logger.info("Notification disabled for this event type", {
        userId,
        type: data.type,
      });
      return {
        success: true,
        message: "Notification disabled by user preference",
      };
    }

    // Get user's FCM tokens from devices field on user document
    const devices = (userData?.devices as Array<Record<string, unknown>>) || [];
    const fcmTokens = devices
      .map((d) => (d?.fcmToken as string | undefined) || null)
      .filter((t): t is string => t != null);

    if (fcmTokens.length === 0) {
      logger.info("No valid FCM tokens on user.devices", { userId });
      return { success: false, message: "No valid FCM tokens" };
    }

    // Build notification content based on type
    const { title, body } = buildNotificationContent(data);

    // Send notification to all user devices
    const response = await messaging.sendEachForMulticast({
      tokens: fcmTokens,
      notification: {
        title: title,
        body: body,
      },
      data: {
        type: "agentic_trade",
        eventType: data.type,
        symbol: data.symbol || "",
        quantity: data.quantity?.toString() || "",
        price: data.price?.toString() || "",
        profitLoss: data.profitLoss?.toString() || "",
      },
      android: {
        priority: "high",
        notification: {
          channelId: "agentic_trades",
          priority: "high",
          sound: "default",
          color: getNotificationColor(data.type),
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
            category: "AGENTIC_TRADE",
          },
        },
      },
    });

    logger.info("Agentic trade notification sent", {
      userId,
      type: data.type,
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

    return {
      success: true,
      successCount: response.successCount,
      failureCount: response.failureCount,
    };
  } catch (error) {
    logger.error("Error sending agentic trade notification", { error });
    throw error;
  }
});

/**
 * Check if notifications are enabled for a given event type.
 *
 * @param {AgenticTradingConfigPrefs} config - User notification preferences.
 * @param {string} type - The notification event type.
 * @return {boolean} True if notifications should be sent.
 */
function checkNotificationPreference(
  config: AgenticTradingConfigPrefs,
  type: string
): boolean {
  switch (type) {
  case "buy":
    return config.notifyOnBuy !== false;
  case "take_profit":
    return config.notifyOnTakeProfit !== false;
  case "stop_loss":
    return config.notifyOnStopLoss !== false;
  case "emergency_stop":
    return config.notifyOnEmergencyStop !== false;
  case "daily_summary":
    return config.notifyDailySummary === true;
  default:
    return true;
  }
}

/**
 * Minimal interface for notification preferences pulled from Firestore.
 */
interface AgenticTradingConfigPrefs {
  notifyOnBuy?: boolean;
  notifyOnTakeProfit?: boolean;
  notifyOnStopLoss?: boolean;
  notifyOnEmergencyStop?: boolean;
  notifyDailySummary?: boolean;
}

/**
 * Build notification title and body based on event type.
 *
 * @param {NotificationRequest} data - The incoming notification request data.
 * @return {{title: string, body: string}} Notification content.
 */
function buildNotificationContent(data: NotificationRequest): {
  title: string;
  body: string;
} {
  const { type, symbol, quantity, price, profitLoss, dailyStats } = data;

  switch (type) {
  case "buy": {
    const total = (quantity || 0) * (price || 0);
    const body =
      "Bought " +
      `${quantity} ` +
      "shares of " +
      `${symbol} ` +
      "at $" +
      `${price?.toFixed(2)} ` +
      `($${total.toFixed(2)})`;
    return {
      title: "🤖 Auto-Trade Executed",
      body,
    };
  }

  case "take_profit": {
    const sign = profitLoss && profitLoss > 0 ? "+" : "";
    let percentStr = "";
    if (price && quantity && profitLoss !== undefined) {
      const totalExit = price * quantity;
      const totalEntry = totalExit - profitLoss;
      if (totalEntry !== 0) {
        const percent = (profitLoss / totalEntry) * 100;
        percentStr = ` (${sign}${percent.toFixed(2)}%)`;
      }
    }
    const body =
      "Sold " +
      `${quantity} ` +
      "shares of " +
      `${symbol} ` +
      "at $" +
      `${price?.toFixed(2)} ` +
      "for " +
      `${sign}$${profitLoss?.toFixed(2)} ` +
      "profit" +
      percentStr;
    return {
      title: "💰 Take Profit Hit!",
      body,
    };
  }

  case "stop_loss": {
    let percentStr = "";
    if (price && quantity && profitLoss !== undefined) {
      const totalExit = price * quantity;
      const totalEntry = totalExit - profitLoss;
      if (totalEntry !== 0) {
        const percent = (profitLoss / totalEntry) * 100;
        percentStr = ` (${percent.toFixed(2)}%)`;
      }
    }
    const body =
      "Sold " +
      `${quantity} ` +
      "shares of " +
      `${symbol} ` +
      "at $" +
      `${price?.toFixed(2)} ` +
      "to limit loss: $" +
      `${Math.abs(profitLoss || 0).toFixed(2)}` +
      percentStr;
    return {
      title: "🛑 Stop Loss Triggered",
      body,
    };
  }

  case "emergency_stop": {
    return {
      title: "⚠️ Emergency Stop Activated",
      body:
        "Auto-trading has been halted. Review your positions and resume " +
        "when ready.",
    };
  }

  case "daily_summary": {
    if (dailyStats) {
      const { totalTrades, wins, losses, totalPnL } = dailyStats;
      const winRate =
        totalTrades > 0 ? ((wins / totalTrades) * 100).toFixed(0) : "0";
      const body =
        `${totalTrades} trades | ✅ ${wins} / ❌ ${losses} (` +
        `${winRate}% win) | ` +
        `${totalPnL >= 0 ? "📈 +" : "📉 "}$${totalPnL.toFixed(2)}`;
      return {
        title: "📊 Daily Auto-Trade Summary",
        body,
      };
    }
    return {
      title: "📊 Daily Auto-Trade Summary",
      body: "Your daily trading summary is ready to view.",
    };
  }

  default:
    return {
      title: "🤖 Agentic Trade Update",
      body: "An auto-trading event occurred.",
    };
  }
}

/**
 * Get notification color based on event type (Android only).
 *
 * @param {string} type - The notification event type.
 * @return {string} Hex color string.
 */
function getNotificationColor(type: string): string {
  switch (type) {
  case "buy":
    return "#2196F3"; // Blue
  case "take_profit":
    return "#4CAF50"; // Green
  case "stop_loss":
    return "#F44336"; // Red
  case "emergency_stop":
    return "#FF9800"; // Orange
  case "daily_summary":
    return "#9C27B0"; // Purple
  default:
    return "#2196F3"; // Blue
  }
}
