/**
 * Copy Trading Firebase Functions
 * 
 * Handles automated copy trading for investor groups.
 * Listens to new orders from group members and automatically
 * copies them to other members who have copy trading enabled.
 */

import * as logger from "firebase-functions/logger";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";

const db = getFirestore();
const messaging = getMessaging();

/**
 * Interface for copy trade settings stored in investor groups
 */
interface CopyTradeSettings {
  enabled: boolean;
  targetUserId?: string;
  autoExecute: boolean;
  maxQuantity?: number;
  maxAmount?: number;
  overridePrice?: boolean;
}

/**
 * Interface for investor group document
 */
interface InvestorGroup {
  id: string;
  name: string;
  members: string[];
  memberCopyTradeSettings?: {
    [userId: string]: CopyTradeSettings;
  };
}

/**
 * Processes new instrument orders for copy trading
 * 
 * Triggered when a new instrument order is created in any user's collection.
 * Checks if the user belongs to any investor groups and if other members
 * have copy trading enabled for this user.
 */
export const onInstrumentOrderCreated = onDocumentCreated(
  "user/{userId}/instrumentOrder/{orderId}",
  async (event) => {
    try {
      const userId = event.params.userId;
      const orderId = event.params.orderId;
      const orderData = event.data?.data();

      if (!orderData) {
        logger.warn("No order data found", { userId, orderId });
        return;
      }

      logger.info("Processing instrument order for copy trading", {
        userId,
        orderId,
        state: orderData.state,
      });

      // Only process filled orders
      if (orderData.state !== "filled") {
        logger.info("Order not filled, skipping copy trade", {
          userId,
          orderId,
          state: orderData.state,
        });
        return;
      }

      // Find investor groups where this user is a member
      const groupsSnapshot = await db
        .collection("investor_groups")
        .where("members", "array-contains", userId)
        .get();

      if (groupsSnapshot.empty) {
        logger.info("User not in any investor groups", { userId });
        return;
      }

      // Process each group
      for (const groupDoc of groupsSnapshot.docs) {
        const group = groupDoc.data() as InvestorGroup;
        
        if (!group.memberCopyTradeSettings) {
          continue;
        }

        // Find members who are copying from this user
        for (const [memberId, settings] of Object.entries(
          group.memberCopyTradeSettings
        )) {
          if (
            settings.enabled &&
            settings.autoExecute &&
            settings.targetUserId === userId
          ) {
            logger.info("Found copy trade target", {
              sourceUser: userId,
              targetUser: memberId,
              groupId: group.id,
            });

            // Calculate adjusted quantity based on limits
            let quantity = orderData.quantity || 0;
            const price = orderData.price || 0;

            if (settings.maxQuantity && quantity > settings.maxQuantity) {
              quantity = settings.maxQuantity;
            }

            if (settings.maxAmount) {
              const totalAmount = quantity * price;
              if (totalAmount > settings.maxAmount) {
                quantity = settings.maxAmount / price;
              }
            }

            // Create a copy trade record
            await createCopyTradeRecord({
              sourceUserId: userId,
              targetUserId: memberId,
              groupId: group.id,
              orderType: "instrument",
              originalOrderId: orderId,
              symbol: orderData.instrumentObj?.symbol || "Unknown",
              side: orderData.side,
              originalQuantity: orderData.quantity,
              copiedQuantity: quantity,
              price: price,
              timestamp: FieldValue.serverTimestamp(),
              executed: false, // Would be true after actual order placement
            });

            logger.info("Copy trade record created", {
              sourceUser: userId,
              targetUser: memberId,
              symbol: orderData.instrumentObj?.symbol,
            });

            // Get source user name for notification
            const sourceUserDoc = await db.collection("user").doc(userId).get();
            const sourceUserName = sourceUserDoc.data()?.name || "A trader";

            // Send notification to target user
            await sendCopyTradeNotification(
              memberId,
              sourceUserName,
              orderData.instrumentObj?.symbol || "Unknown",
              orderData.side,
              quantity,
              "instrument"
            );
          }
        }
      }
    } catch (error) {
      logger.error("Error in onInstrumentOrderCreated", error);
    }
  }
);

/**
 * Processes new option orders for copy trading
 * 
 * Triggered when a new option order is created in any user's collection.
 */
export const onOptionOrderCreated = onDocumentCreated(
  "user/{userId}/optionOrder/{orderId}",
  async (event) => {
    try {
      const userId = event.params.userId;
      const orderId = event.params.orderId;
      const orderData = event.data?.data();

      if (!orderData) {
        logger.warn("No order data found", { userId, orderId });
        return;
      }

      logger.info("Processing option order for copy trading", {
        userId,
        orderId,
        state: orderData.state,
      });

      // Only process filled orders
      if (orderData.state !== "filled") {
        logger.info("Order not filled, skipping copy trade", {
          userId,
          orderId,
          state: orderData.state,
        });
        return;
      }

      // Find investor groups where this user is a member
      const groupsSnapshot = await db
        .collection("investor_groups")
        .where("members", "array-contains", userId)
        .get();

      if (groupsSnapshot.empty) {
        logger.info("User not in any investor groups", { userId });
        return;
      }

      // Process each group
      for (const groupDoc of groupsSnapshot.docs) {
        const group = groupDoc.data() as InvestorGroup;
        
        if (!group.memberCopyTradeSettings) {
          continue;
        }

        // Find members who are copying from this user
        for (const [memberId, settings] of Object.entries(
          group.memberCopyTradeSettings
        )) {
          if (
            settings.enabled &&
            settings.autoExecute &&
            settings.targetUserId === userId
          ) {
            logger.info("Found copy trade target", {
              sourceUser: userId,
              targetUser: memberId,
              groupId: group.id,
            });

            // Calculate adjusted quantity based on limits
            let quantity = orderData.quantity || 0;
            const price = orderData.price || 0;

            if (settings.maxQuantity && quantity > settings.maxQuantity) {
              quantity = settings.maxQuantity;
            }

            if (settings.maxAmount) {
              const totalAmount = quantity * price * 100; // Options are per 100 shares
              if (totalAmount > settings.maxAmount) {
                quantity = settings.maxAmount / (price * 100);
              }
            }

            // Create a copy trade record
            await createCopyTradeRecord({
              sourceUserId: userId,
              targetUserId: memberId,
              groupId: group.id,
              orderType: "option",
              originalOrderId: orderId,
              symbol: orderData.chainSymbol || "Unknown",
              side: orderData.direction,
              originalQuantity: orderData.quantity,
              copiedQuantity: quantity,
              price: price,
              strategy: orderData.strategy,
              timestamp: FieldValue.serverTimestamp(),
              executed: false, // Would be true after actual order placement
            });

            logger.info("Copy trade record created", {
              sourceUser: userId,
              targetUser: memberId,
              symbol: orderData.chainSymbol,
            });

            // Get source user name for notification
            const sourceUserDoc = await db.collection("user").doc(userId).get();
            const sourceUserName = sourceUserDoc.data()?.name || "A trader";

            // Send notification to target user
            await sendCopyTradeNotification(
              memberId,
              sourceUserName,
              orderData.chainSymbol || "Unknown",
              orderData.direction,
              quantity,
              "option"
            );
          }
        }
      }
    } catch (error) {
      logger.error("Error in onOptionOrderCreated", error);
    }
  }
);

/**
 * Sends a notification to a user about a copy trade
 * 
 * @param userId User ID to notify
 * @param sourceUserName Name of the user whose trade was copied
 * @param symbol Trading symbol
 * @param side Buy/sell side
 * @param quantity Quantity of the trade
 * @param orderType Type of order (instrument or option)
 */
async function sendCopyTradeNotification(
  userId: string,
  sourceUserName: string,
  symbol: string,
  side: string,
  quantity: number,
  orderType: string
): Promise<void> {
  try {
    // Fetch user's FCM tokens from devices
    const userDoc = await db.collection("user").doc(userId).get();
    if (!userDoc.exists) {
      logger.warn("User not found for notification", { userId });
      return;
    }

    const userData = userDoc.data();
    const devices = userData?.devices || [];
    const fcmTokens: string[] = devices
      .map((device: any) => device.fcmToken)
      .filter((token: string | null | undefined) => token != null && token !== "");

    if (fcmTokens.length === 0) {
      logger.info("No FCM tokens found for user", { userId });
      return;
    }

    // Prepare notification
    const title = "Copy Trade Available";
    const body = `${sourceUserName} ${side} ${quantity.toFixed(0)} ${orderType === "option" ? "contracts" : "shares"} of ${symbol}`;
    
    // Send notification to all user devices
    const response = await messaging.sendEachForMulticast({
      tokens: fcmTokens,
      notification: {
        title: title,
        body: body,
      },
      data: {
        type: "copy_trade",
        symbol: symbol,
        side: side,
        quantity: quantity.toString(),
        orderType: orderType,
      },
      android: {
        priority: "high",
        notification: {
          channelId: "copy_trades",
          priority: "high",
          sound: "default",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    });

    logger.info("Copy trade notification sent", {
      userId,
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
    logger.error("Error sending copy trade notification", {
      userId,
      error,
    });
  }
}

/**
 * Creates a copy trade record in Firestore
 * 
 * @param data Copy trade data
 */
async function createCopyTradeRecord(data: any): Promise<void> {
  await db.collection("copy_trades").add(data);
}

/**
 * Note on Order Execution:
 * 
 * This backend implementation creates copy trade records but does NOT execute
 * orders directly because:
 * 
 * 1. Security: Backend doesn't have direct access to user brokerage credentials
 * 2. User Control: Users must authorize trades through their devices
 * 3. Risk Management: Orders should be validated on the client with current market data
 * 
 * Order execution happens on the client side (copy_trade_button_widget.dart) where:
 * - User authentication is properly handled
 * - Orders are placed via the IBrokerageService
 * - Users can review and confirm before execution
 * - Real-time market data is available
 * 
 * This backend's role is to:
 * - Monitor trades from users being copied
 * - Create audit records in copy_trades collection
 * - Provide data for copy trade history and analytics
 * - Enable future notification system for pending copy trades
 */
