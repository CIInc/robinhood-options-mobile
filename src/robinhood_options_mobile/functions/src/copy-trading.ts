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
  copyPercentage?: number;
  maxQuantity?: number;
  maxAmount?: number;
  maxDailyAmount?: number;
  overridePrice?: boolean;
  symbolWhitelist?: string[];
  symbolBlacklist?: string[];
  sectorWhitelist?: string[];
  minMarketCap?: number;
  maxMarketCap?: number;
  startTime?: string;
  endTime?: string;
  copyStopLoss?: boolean;
  copyTakeProfit?: boolean;
  copyTrailingStop?: boolean;
  stopLossAdjustment?: number;
  takeProfitAdjustment?: number;
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
 * Interface for a copy trade record stored in Firestore
 */
interface CopyTradeRecord {
  sourceUserId: string;
  targetUserId: string;
  groupId: string;
  orderType: "instrument" | "option";
  type?: string; // limit, market, stop, etc.
  trigger?: string; // stop, etc.
  originalOrderId: string;
  symbol: string;
  side: string;
  originalQuantity: number;
  copiedQuantity: number;
  price: number;
  stopPrice?: number;
  strategy?: string;
  legs?: {
    expirationDate?: string;
    strikePrice?: number;
    optionType?: string;
    side?: string;
    positionEffect?: string;
    ratioQuantity?: number;
  }[];
  timestamp: FieldValue; // server timestamp placeholder
  executed: boolean;
  status?: "pending_approval" | "approved" | "rejected" | "executed";
}

/**
 * Interface for fundamentals
 */
interface Fundamentals {
  sector?: string;
  market_cap?: number;
}

/**
 * Interface for instrument
 */
interface Instrument {
  symbol: string;
  fundamentalsObj?: Fundamentals;
}

/**
 * Checks if current time is within the specified range
 * @param {string} startTime - Start time in HH:mm format
 * @param {string} endTime - End time in HH:mm format
 * @return {boolean} True if current time is within range
 */
function isTimeInRange(startTime: string, endTime: string): boolean {
  // Convert current time to EST/EDT as market hours are in ET
  const now = new Date();
  const utc = now.getTime() + now.getTimezoneOffset() * 60000;
  // EDT (UTC-4) - simplified, ideally use a library for timezone
  const etOffset = -4;
  const etDate = new Date(utc + 3600000 * etOffset);

  const currentMinutes = etDate.getHours() * 60 + etDate.getMinutes();

  const [startHour, startMinute] = startTime.split(":").map(Number);
  const startMinutes = startHour * 60 + startMinute;

  const [endHour, endMinute] = endTime.split(":").map(Number);
  const endMinutes = endHour * 60 + endMinute;

  return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
}

/**
 * Checks if a trade should be copied based on settings
 * @param {CopyTradeSettings} settings - Copy trade settings
 * @param {string} symbol - Symbol of the trade
 * @param {string} [sector] - Sector of the symbol
 * @param {number} [marketCap] - Market cap of the symbol
 * @return {boolean} True if trade should be copied
 */
function shouldCopyTrade(
  settings: CopyTradeSettings,
  symbol: string,
  sector?: string,
  marketCap?: number
): boolean {
  if (!settings.enabled) return false;

  // Symbol Whitelist
  if (
    settings.symbolWhitelist &&
    settings.symbolWhitelist.length > 0 &&
    !settings.symbolWhitelist.includes(symbol)
  ) {
    return false;
  }

  // Symbol Blacklist
  if (settings.symbolBlacklist && settings.symbolBlacklist.includes(symbol)) {
    return false;
  }

  // Sector Whitelist
  if (
    sector &&
    settings.sectorWhitelist &&
    settings.sectorWhitelist.length > 0 &&
    !settings.sectorWhitelist.includes(sector)
  ) {
    return false;
  }

  // Market Cap
  if (marketCap) {
    if (settings.minMarketCap && marketCap < settings.minMarketCap) {
      return false;
    }
    if (settings.maxMarketCap && marketCap > settings.maxMarketCap) {
      return false;
    }
  }

  // Time Filters
  if (settings.startTime && settings.endTime) {
    if (!isTimeInRange(settings.startTime, settings.endTime)) {
      return false;
    }
  }

  return true;
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

      logger.info(
        "Processing instrument order",
        {
          userId,
          orderId,
          state: orderData.state,
        }
      );

      // Determine if this is an exit order (Stop Loss or Take Profit)
      const isStopLoss = orderData.trigger === "stop";
      const isTakeProfit =
        orderData.type === "limit" &&
        orderData.side === "sell"; // Simplified assumption
      const isExitOrder = isStopLoss || isTakeProfit;

      // Only process filled orders, unless it's a confirmed exit order
      if (orderData.state !== "filled") {
        if (
          !isExitOrder ||
          (orderData.state !== "confirmed" &&
            orderData.state !== "queued")
        ) {
          logger.info(
            "Skipping copy trade: Order not filled/confirmed exit",
            {
              userId,
              orderId,
              state: orderData.state,
              trigger: orderData.trigger,
              type: orderData.type,
              side: orderData.side,
            }
          );
          return;
        }
      }

      // Fetch instrument details to get symbol, sector, and market cap
      let symbol = "Unknown";
      let sector: string | undefined;
      let marketCap: number | undefined;

      const instrumentId = orderData.instrument_id;
      if (instrumentId) {
        try {
          const instrumentDoc = await db
            .collection("instrument")
            .doc(instrumentId)
            .get();

          if (instrumentDoc.exists) {
            const instrumentData = instrumentDoc.data() as Instrument;
            symbol = instrumentData.symbol || "Unknown";
            sector = instrumentData.fundamentalsObj?.sector;
            marketCap = instrumentData.fundamentalsObj?.market_cap;

            logger.info("Fetched instrument details", {
              instrumentId,
              symbol,
              sector,
              marketCap,
            });
          } else {
            logger.warn("Instrument document not found", { instrumentId });
          }
        } catch (error) {
          logger.error("Error fetching instrument details", {
            instrumentId,
            error,
          });
        }
      } else {
        logger.warn("No instrument_id in order data", { orderId });
        // Fallback to existing symbol if available
        if (orderData.instrumentObj?.symbol) {
          symbol = orderData.instrumentObj.symbol;
        }
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
          if (settings.enabled && settings.targetUserId === userId) {
            // Use fetched symbol, sector, and marketCap
            if (!shouldCopyTrade(settings, symbol, sector, marketCap)) {
              logger.info("Trade filtered out by settings", {
                userId,
                targetUser: memberId,
                symbol,
              });
              continue;
            }

            // Check if we should copy this type of order
            if (isStopLoss && !settings.copyStopLoss) {
              logger.info("Stop loss copying disabled", {
                userId,
                targetUser: memberId,
              });
              continue;
            }
            if (
              isTakeProfit &&
              !settings.copyTakeProfit &&
              orderData.state !==
              "filled"
            ) {
              logger.info("Take profit copying disabled", {
                userId,
                targetUser: memberId,
              });
              continue;
            }

            // Trailing Stop Check (Heuristic: stop trigger without fixed stop
            // price or explicit type)
            // Note: Adjust logic based on actual Robinhood API response for
            // trailing stops
            const isTrailingStop =
              orderData.type === "market" &&
              orderData.trigger === "stop" &&
              !orderData.stop_price;
            if (isTrailingStop && !settings.copyTrailingStop) {
              logger.info("Trailing stop copying disabled", {
                userId,
                targetUser: memberId,
              });
              continue;
            }

            logger.info("Found copy trade target", {
              sourceUser: userId,
              targetUser: memberId,
              groupId: group.id,
              autoExecute: settings.autoExecute,
            });

            // Calculate adjusted quantity based on limits
            let quantity = orderData.quantity || 0;
            let price = orderData.price || 0;
            let stopPrice = orderData.stop_price;

            if (isStopLoss && settings.stopLossAdjustment && stopPrice) {
              stopPrice = stopPrice * (1 + settings.stopLossAdjustment / 100);
            }

            if (isTakeProfit && settings.takeProfitAdjustment && price) {
              price = price * (1 + settings.takeProfitAdjustment / 100);
            }

            if (settings.copyPercentage) {
              quantity = quantity * (settings.copyPercentage / 100);
              // Round to 4 decimal places for instruments (fractional shares)
              quantity = Math.round(quantity * 10000) / 10000;
            }

            if (settings.maxQuantity && quantity > settings.maxQuantity) {
              quantity = settings.maxQuantity;
            }

            if (settings.maxAmount) {
              const totalAmount = quantity * price;
              if (totalAmount > settings.maxAmount) {
                quantity = settings.maxAmount / price;
              }
            }

            if (settings.autoExecute) {
              // Create a copy trade record (auto-execute)
              await createCopyTradeRecord({
                sourceUserId: userId,
                targetUserId: memberId,
                groupId: group.id,
                orderType: "instrument",
                type: orderData.type,
                trigger: orderData.trigger,
                originalOrderId: orderId,
                symbol: orderData.instrumentObj?.symbol || "Unknown",
                side: orderData.side,
                originalQuantity: orderData.quantity,
                copiedQuantity: quantity,
                price: price,
                stopPrice: stopPrice,
                timestamp: FieldValue.serverTimestamp(),
                executed: false, // Would be true after actual order placement
                status: "approved",
              });

              logger.info(
                "Copy trade record created (auto-execute)",
                {
                  sourceUser: userId,
                  targetUser: memberId,
                  symbol: orderData.instrumentObj?.symbol,
                }
              );
            } else {
              // Create a copy trade record (manual approval)
              await createCopyTradeRecord({
                sourceUserId: userId,
                targetUserId: memberId,
                groupId: group.id,
                orderType: "instrument",
                type: orderData.type,
                trigger: orderData.trigger,
                originalOrderId: orderId,
                symbol: orderData.instrumentObj?.symbol || "Unknown",
                side: orderData.side,
                originalQuantity: orderData.quantity,
                copiedQuantity: quantity,
                price: price,
                stopPrice: stopPrice,
                timestamp: FieldValue.serverTimestamp(),
                executed: false,
                status: "pending_approval",
              });

              logger.info(
                "Copy trade record created (pending approval)",
                {
                  sourceUser: userId,
                  targetUser: memberId,
                  symbol: orderData.instrumentObj?.symbol,
                }
              );
            }

            // Get source user name for notification
            const sourceUserDoc = await db.collection("user").doc(userId).get();
            const sourceUserName = sourceUserDoc.data()?.name || "A trader";

            // Send notification to target user
            await sendCopyTradeNotification(
              memberId,
              sourceUserName,
              symbol,
              orderData.side,
              quantity,
              "instrument",
              settings.autoExecute
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

      logger.info(
        "Processing option order",
        {
          userId,
          orderId,
          state: orderData.state,
        }
      );

      // Determine if this is an exit order (Stop Loss or Take Profit)
      const isStopLoss = orderData.trigger === "stop";
      const isSell =
        orderData.legs &&
        orderData.legs.length > 0 &&
        orderData.legs[0].side === "sell";
      const isTakeProfit = orderData.type === "limit" && isSell;
      const isExitOrder = isStopLoss || isTakeProfit;

      // Only process filled orders, unless it's a confirmed exit order
      if (orderData.state !== "filled") {
        if (
          !isExitOrder ||
          (orderData.state !== "confirmed" &&
            orderData.state !== "queued")
        ) {
          logger.info(
            "Skipping copy trade: Order not filled/confirmed exit",
            {
              userId,
              orderId,
              state: orderData.state,
              trigger: orderData.trigger,
              type: orderData.type,
            }
          );
          return;
        }
      }

      // Fetch instrument details to get sector and market cap
      const symbol = orderData.chain_symbol || "Unknown";
      let sector: string | undefined;
      let marketCap: number | undefined;

      if (symbol !== "Unknown") {
        try {
          const instrumentQuery = await db
            .collection("instrument")
            .where("symbol", "==", symbol)
            .limit(1)
            .get();

          if (!instrumentQuery.empty) {
            const instrumentData = instrumentQuery.docs[0].data() as Instrument;
            sector = instrumentData.fundamentalsObj?.sector;
            marketCap = instrumentData.fundamentalsObj?.market_cap;

            logger.info("Fetched instrument details for option", {
              symbol,
              sector,
              marketCap,
            });
          } else {
            logger.warn("Instrument not found for symbol", { symbol });
          }
        } catch (error) {
          logger.error("Error fetching instrument details", {
            symbol,
            error,
          });
        }
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
          if (settings.enabled && settings.targetUserId === userId) {
            // Use fetched symbol, sector, and marketCap
            if (!shouldCopyTrade(settings, symbol, sector, marketCap)) {
              logger.info("Trade filtered out by settings", {
                userId,
                targetUser: memberId,
                symbol,
              });
              continue;
            }

            // Check if we should copy this type of order
            if (isStopLoss && !settings.copyStopLoss) {
              logger.info("Stop loss copying disabled", {
                userId,
                targetUser: memberId,
              });
              continue;
            }
            if (
              isTakeProfit &&
              !settings.copyTakeProfit &&
              orderData.state !==
              "filled"
            ) {
              logger.info("Take profit copying disabled", {
                userId,
                targetUser: memberId,
              });
              continue;
            }

            // Trailing Stop Check (Heuristic: stop trigger without fixed stop
            // price or explicit type)
            // Note: Adjust logic based on actual Robinhood API response for
            // trailing stops
            const isTrailingStop =
              orderData.type === "market" &&
              orderData.trigger === "stop" &&
              !orderData.stop_price;
            if (isTrailingStop && !settings.copyTrailingStop) {
              logger.info("Trailing stop copying disabled", {
                userId,
                targetUser: memberId,
              });
              continue;
            }

            logger.info("Found copy trade target", {
              sourceUser: userId,
              targetUser: memberId,
              groupId: group.id,
              autoExecute: settings.autoExecute,
            });

            // Calculate adjusted quantity based on limits
            let quantity = orderData.quantity || 0;
            let price = orderData.price || 0;
            let stopPrice = orderData.stop_price;

            if (isStopLoss && settings.stopLossAdjustment && stopPrice) {
              stopPrice = stopPrice * (1 + settings.stopLossAdjustment / 100);
            }

            if (isTakeProfit && settings.takeProfitAdjustment && price) {
              price = price * (1 + settings.takeProfitAdjustment / 100);
            }

            if (settings.copyPercentage) {
              quantity = quantity * (settings.copyPercentage / 100);
              // Options must be integers, floor to be safe
              quantity = Math.floor(quantity);
              // Ensure at least 1 contract if copying
              if (quantity < 1) quantity = 1;
            }

            if (settings.maxQuantity && quantity > settings.maxQuantity) {
              quantity = settings.maxQuantity;
            }

            if (settings.maxAmount) {
              const totalAmount =
                quantity * price * 100; // Options are per 100 shares
              if (totalAmount > settings.maxAmount) {
                quantity = settings.maxAmount / (price * 100);
              }
            }

            if (settings.autoExecute) {
              // Create a copy trade record (auto-execute)
              await createCopyTradeRecord({
                sourceUserId: userId,
                targetUserId: memberId,
                groupId: group.id,
                orderType: "option",
                type: orderData.type,
                trigger: orderData.trigger,
                originalOrderId: orderId,
                symbol: symbol,
                side: orderData.direction,
                originalQuantity: orderData.quantity,
                copiedQuantity: quantity,
                price: price,
                stopPrice: stopPrice,
                strategy: orderData.strategy,
                legs: (orderData.legs || []).map((leg: any) => ({
                  expirationDate: leg.expiration_date,
                  strikePrice: leg.strike_price,
                  optionType: leg.option_type,
                  side: leg.side,
                  positionEffect: leg.position_effect,
                  ratioQuantity: leg.ratio_quantity,
                })),
                timestamp: FieldValue.serverTimestamp(),
                executed: false, // Would be true after actual order placement
                status: "approved",
              });

              logger.info(
                "Copy trade record created (auto-execute)",
                {
                  sourceUser: userId,
                  targetUser: memberId,
                  symbol: orderData.chainSymbol,
                }
              );
            } else {
              // Create a copy trade record (manual approval)
              await createCopyTradeRecord({
                sourceUserId: userId,
                targetUserId: memberId,
                groupId: group.id,
                orderType: "option",
                type: orderData.type,
                trigger: orderData.trigger,
                originalOrderId: orderId,
                symbol: symbol,
                side: orderData.direction,
                originalQuantity: orderData.quantity,
                copiedQuantity: quantity,
                price: price,
                stopPrice: stopPrice,
                strategy: orderData.strategy,
                legs: (orderData.legs || []).map((leg: any) => ({
                  expirationDate: leg.expiration_date,
                  strikePrice: leg.strike_price,
                  optionType: leg.option_type,
                  side: leg.side,
                  positionEffect: leg.position_effect,
                  ratioQuantity: leg.ratio_quantity,
                })),
                timestamp: FieldValue.serverTimestamp(),
                executed: false,
                status: "pending_approval",
              });

              logger.info(
                "Copy trade record created (pending approval)",
                {
                  sourceUser: userId,
                  targetUser: memberId,
                  symbol: orderData.chainSymbol,
                }
              );
            }

            // Get source user name for notification
            const sourceUserDoc = await db.collection("user").doc(userId).get();
            const sourceUserName = sourceUserDoc.data()?.name || "A trader";

            // Send notification to target user
            await sendCopyTradeNotification(
              memberId,
              sourceUserName,
              symbol,
              orderData.direction,
              quantity,
              "option",
              settings.autoExecute
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
 * @param {string} userId User ID to notify
 * @param {string} sourceUserName Name of the user whose trade was copied
 * @param {string} symbol Trading symbol
 * @param {string} side Buy/sell side
 * @param {number} quantity Quantity of the trade
 * @param {string} orderType Type of order (instrument or option)
 * @param {boolean} autoExecute Whether the trade was auto-executed or
 *   requires approval
 */
async function sendCopyTradeNotification(
  userId: string,
  sourceUserName: string,
  symbol: string,
  side: string,
  quantity: number,
  orderType: string,
  autoExecute = true
): Promise<void> {
  try {
    // Fetch user's FCM tokens from devices
    const userDoc = await db.collection("user").doc(userId).get();
    if (!userDoc.exists) {
      logger.warn("User not found for notification", { userId });
      return;
    }

    const userData = userDoc.data();
    // Devices expected as array of objects with optional fcmToken
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
    const title = autoExecute ? "Copy Trade Executed" : "Copy Trade Request";
    const body =
      `${sourceUserName} ${side} ${quantity.toFixed(0)} ` +
      `${orderType === "option" ? "contracts" : "shares"} of ${symbol}`;

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
        action: autoExecute ? "executed" : "request",
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

    logger.info(
      "Copy trade notification sent",
      {
        userId,
        successCount: response.successCount,
        failureCount: response.failureCount,
      }
    );

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
 * @param {CopyTradeRecord} data Copy trade data
 */
async function createCopyTradeRecord(data: CopyTradeRecord): Promise<void> {
  await db.collection("copy_trades").add(data);
}

/**
 * Note on Order Execution:
 *
 * This backend implementation creates copy trade records but
 * does NOT execute orders directly because:
 *
 * 1. Security: Backend doesn't have direct access to user brokerage credentials
 * 2. User Control: Users must authorize trades through their devices
 * 3. Risk Management: Orders should be validated on the client with current
 *    market data
 *
 * Order execution happens on the client side
 * (copy_trade_button_widget.dart) where:
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
