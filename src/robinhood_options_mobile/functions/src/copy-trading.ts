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

const db = getFirestore();

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
          }
        }
      }
    } catch (error) {
      logger.error("Error in onOptionOrderCreated", error);
    }
  }
);

/**
 * Creates a copy trade record in Firestore
 * 
 * @param data Copy trade data
 */
async function createCopyTradeRecord(data: any): Promise<void> {
  await db.collection("copy_trades").add(data);
}

/**
 * Note: Actual order execution would require:
 * 1. Brokerage API credentials for the target user
 * 2. Proper authentication and authorization
 * 3. Risk management and validation
 * 4. Error handling and retry logic
 * 5. Notification system for users
 * 
 * This implementation creates copy trade records that can be:
 * - Reviewed by users before execution (manual confirmation)
 * - Processed by a separate service that handles order placement
 * - Used for audit and compliance purposes
 */
