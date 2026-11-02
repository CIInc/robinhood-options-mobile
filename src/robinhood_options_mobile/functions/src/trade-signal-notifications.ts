/**
 * Trade Signal Notifications Firebase Functions
 *
 * Sends push notifications to users when trade signals are created or updated
 * in the signals collection. Notifications are sent when signals change
 * to BUY or SELL based on user preferences.
 */

import { initializeApp, getApps } from "firebase-admin/app";
import * as logger from "firebase-functions/logger";
import {
  onDocumentCreated,
  onDocumentUpdated,
} from "firebase-functions/v2/firestore";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import {
  UserNotificationCustomizationSettings,
  isWithinQuietHours,
  resolveChannelAndSound,
  dispatchMultiChannelAlert,
} from "./alert-delivery";

if (getApps().length === 0) {
  initializeApp();
}

const db = getFirestore();
const messaging = getMessaging();

// Same symbol, interval and action is not re-notified within this window.
const SIGNAL_COOLDOWN_MS = 60 * 60 * 1000;
// Max pushes per user per window; extra signals are still saved in-app.
const PUSH_WINDOW_MS = 15 * 60 * 1000;
const MAX_PUSHES_PER_WINDOW = 5;

type PushSlot = "send" | "cooldown" | "capped";

interface PushReservation {
  slot: PushSlot;
  previousLastSentAt?: number;
}

/**
 * Undo a reservation after a push that reached no device, so a failed send
 * doesn't suppress the next signal for the cooldown period.
 * @param {string} userId The user ID
 * @param {TradeSignal} signal The trade signal
 * @param {PushReservation} reservation What reservePushSlot returned
 */
async function releasePushSlot(
  userId: string,
  signal: TradeSignal,
  reservation: PushReservation
): Promise<void> {
  const stateCol = db.collection("user").doc(userId)
    .collection("signal_notification_state");
  const signalRef = stateCol.doc(pushStateKey(signal));
  const windowRef = stateCol.doc("_window");
  await db.runTransaction(async (tx) => {
    const windowSnap = await tx.get(windowRef);
    if (reservation.previousLastSentAt === undefined) {
      tx.delete(signalRef);
    } else {
      tx.set(signalRef, { lastSentAt: reservation.previousLastSentAt });
    }
    const count = (windowSnap.data()?.count as number | undefined) ?? 0;
    if (windowSnap.exists && count > 0) {
      tx.update(windowRef, { count: count - 1 });
    }
  });
}

/**
 * Firestore document key for a signal's cooldown state.
 * @param {TradeSignal} signal The trade signal
 * @return {string} The document id
 */
function pushStateKey(signal: TradeSignal): string {
  return `${signal.symbol}_${signal.interval || "1d"}_${signal.signal}`
    .replace(/\//g, "_");
}

/**
 * Decide whether a signal may buzz the user, recording the attempt atomically
 * so concurrent signal triggers share one counter.
 * @param {string} userId The user ID
 * @param {TradeSignal} signal The trade signal
 * @return {Promise<PushReservation>} send, cooldown (skip entirely) or capped
 */
async function reservePushSlot(
  userId: string,
  signal: TradeSignal
): Promise<PushReservation> {
  const stateCol = db.collection("user").doc(userId)
    .collection("signal_notification_state");
  const signalRef = stateCol.doc(pushStateKey(signal));
  const windowRef = stateCol.doc("_window");

  return db.runTransaction(async (tx): Promise<PushReservation> => {
    const [signalSnap, windowSnap] = await Promise.all([
      tx.get(signalRef),
      tx.get(windowRef),
    ]);
    const now = Date.now();

    const lastSentAt = signalSnap.data()?.lastSentAt as number | undefined;
    if (lastSentAt && now - lastSentAt < SIGNAL_COOLDOWN_MS) {
      return { slot: "cooldown" };
    }

    let windowStart = windowSnap.data()?.windowStart as number | undefined;
    let count = (windowSnap.data()?.count as number | undefined) ?? 0;
    if (!windowStart || now - windowStart >= PUSH_WINDOW_MS) {
      windowStart = now;
      count = 0;
    }

    tx.set(signalRef, { lastSentAt: now });
    if (count >= MAX_PUSHES_PER_WINDOW) {
      tx.set(windowRef, { windowStart, count });
      return { slot: "capped", previousLastSentAt: lastSentAt };
    }
    tx.set(windowRef, { windowStart, count: count + 1 });
    return { slot: "send", previousLastSentAt: lastSentAt };
  });
}

/**
 * Interface for indicator result
 */
interface IndicatorResult {
  value: number | null;
  signal: string;
  reason: string;
  metadata?: Record<string, any>;
}

/**
 * Interface for multi-indicator result
 */
interface MultiIndicatorResult {
  allGreen: boolean;
  indicators: {
    priceMovement: IndicatorResult;
    momentum: IndicatorResult;
    marketDirection: IndicatorResult;
    volume: IndicatorResult;
    macd: IndicatorResult;
    bollingerBands: IndicatorResult;
    stochastic: IndicatorResult;
    atr: IndicatorResult;
    obv: IndicatorResult;
    vwap: IndicatorResult;
    adx: IndicatorResult;
    williamsR: IndicatorResult;
    [key: string]: IndicatorResult | undefined;
  };
  customIndicators?: Record<string, IndicatorResult>;
  overallSignal: string;
  reason: string;
  signalStrength: number;
}

/**
 * Interface for trade signal document data
 */
interface TradeSignal {
  timestamp: number;
  symbol: string;
  interval?: string; // 1d, 1h, 30m, 15m
  signal: string; // BUY, SELL, or HOLD
  reason?: string;
  multiIndicatorResult?: MultiIndicatorResult;
  optimization?: {
    confidenceScore: number;
    refinedSignal: string;
    reasoning: string;
    [key: string]: any;
  };
  currentPrice?: number;
  pricesLength?: number;
  volumesLength?: number;
  config?: Record<string, any>;
  portfolioState?: Record<string, any>;
  proposal?: Record<string, any>;
  assessment?: Record<string, any>;

  // Legacy or flattened fields
  confidence?: number;
  smaFast?: number;
  smaSlow?: number;
  rsi?: number;
  macd?: number;
  volume?: number;
  price?: number;
  indicators?: any;
}

/**
 * Interface for user notification settings
 */
export interface NotificationSettings
  extends UserNotificationCustomizationSettings {
  enabled: boolean;
  signalTypes: string[];
  symbols: string[];
  intervals: string[];
  includeHold: boolean;
  minConfidence?: number;
}

/**
 * Get confidence score from signal
 * @param {TradeSignal} signal The trade signal
 * @return {number|undefined} The confidence score (0-1) or undefined
 */
export function getSignalConfidence(signal: TradeSignal): number | undefined {
  if (signal.confidence !== undefined) {
    return signal.confidence;
  }
  if (signal.multiIndicatorResult?.signalStrength !== undefined) {
    // signalStrength is 0-100, convert to 0-1
    return signal.multiIndicatorResult.signalStrength / 100;
  }
  return undefined;
}

/**
 * Check if signal matches user preferences
 * @param {TradeSignal} signal The trade signal to check
 * @param {NotificationSettings} settings The user's notification settings
 * @return {boolean} True if user should be notified
 */
export function shouldNotifyUser(
  signal: TradeSignal,
  settings: NotificationSettings
): boolean {
  // Check if notifications are enabled
  if (!settings.enabled) {
    return false;
  }

  // Check category trigger toggles (Price/Technical vs GEX)
  const indicatorsMap = signal.multiIndicatorResult?.indicators ||
    signal.indicators || {};
  const customIndicatorsMap =
    signal.multiIndicatorResult?.customIndicators || {};
  const isGexDominant = Boolean(
    indicatorsMap.gex?.signal === signal.signal &&
    (signal.reason?.toUpperCase().includes("GEX") ||
      signal.reason?.toUpperCase().includes("GAMMA"))
  );

  if (isGexDominant && settings.gexTriggerEnabled === false) {
    return false;
  }
  if (!isGexDominant && settings.priceTriggerEnabled === false) {
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
  const confidence = getSignalConfidence(signal);
  if (
    settings.minConfidence !== undefined &&
    confidence !== undefined &&
    confidence < settings.minConfidence
  ) {
    return false;
  }

  // Check granular required indicator triggers (if any configured)
  if (settings.requiredIndicators && settings.requiredIndicators.length > 0) {
    const matchesRequiredIndicator = settings.requiredIndicators.some(
      (indKey) => {
        const ind = indicatorsMap[indKey] || customIndicatorsMap[indKey];
        return ind && ind.signal === signal.signal;
      }
    );
    if (!matchesRequiredIndicator) {
      return false;
    }
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
 */
async function sendTradeSignalNotification(
  userId: string,
  signal: TradeSignal
): Promise<void> {
  try {
    // Fetch user's FCM tokens
    const userDoc = await db.collection("user").doc(userId).get();
    if (!userDoc.exists) {
      logger.warn("User not found for notification", { userId });
      return;
    }

    const userData = userDoc.data();
    const userSettings: NotificationSettings | undefined =
      userData?.tradeSignalNotificationSettings;
    const devices: Array<{ fcmToken?: string | null }> =
      userData?.devices || [];
    const fcmTokens: string[] = devices
      .map((device) => device.fcmToken)
      .filter((token): token is string => token != null && token !== "");

    const confidence = getSignalConfidence(signal);
    const categoryKey = (signal.signal === "BUY" || signal.signal === "SELL") ?
      signal.signal :
      "HOLD";
    const resolvedDelivery = resolveChannelAndSound(
      categoryKey,
      userSettings,
      undefined,
      confidence
    );
    const quietHoursSuppressed = isWithinQuietHours(
      userSettings,
      resolvedDelivery.priority
    );
    const shouldSendPush = resolvedDelivery.channels.includes("push") &&
      fcmTokens.length > 0 &&
      !quietHoursSuppressed;

    if (
      fcmTokens.length === 0 &&
      !resolvedDelivery.channels.includes("in_app") &&
      !resolvedDelivery.channels.includes("email") &&
      !resolvedDelivery.channels.includes("sms") &&
      !resolvedDelivery.channels.includes("webhook")
    ) {
      logger.info("No active delivery channels or FCM tokens found for user", {
        userId,
      });
      return;
    }

    const reservation = await reservePushSlot(userId, signal);
    const pushSlot = reservation.slot;
    if (pushSlot === "cooldown") {
      logger.info("Signal notification skipped - cooldown active", {
        userId,
        symbol: signal.symbol,
        signal: signal.signal,
        interval: signal.interval,
      });
      return;
    }

    // Prepare notification
    const intervalLabel = getIntervalLabel(signal.interval);
    const action = signal.signal;
    const emoji = action === "BUY" ? "🟢" : (action === "SELL" ? "🔴" : "🟡");

    // Improved Title: "🟢 BUY AAPL: $150.00 (New)"
    // If updated, show "🟢 BUY AAPL (Updated)"
    const price = signal.price || signal.currentPrice;
    const priceStr = price ? `$${price.toFixed(2)}` : "N/A";

    const title = `${emoji} ${action} ${signal.symbol} @ ${priceStr}`;

    // Use emoji for high confidence
    const confEmoji = (confidence && confidence > 0.8) ? "🔥 " : "";
    const confidenceStr = confidence !== undefined ?
      `${confEmoji}${(confidence * 100).toFixed(0)}% Conf.` : "";

    let rsi = signal.rsi;
    let macd = signal.macd;
    let smaFast = signal.smaFast;
    let smaSlow = signal.smaSlow;

    // Fallback to indicators object if top-level fields are missing
    // Check multiIndicatorResult first, then legacy indicators field
    const indicatorsObj = signal.multiIndicatorResult?.indicators ||
      signal.indicators;

    if (indicatorsObj) {
      if (rsi === undefined && indicatorsObj?.momentum) {
        rsi = indicatorsObj.momentum.value ?? undefined;
      }
      if (macd === undefined && indicatorsObj?.macd) {
        macd = indicatorsObj.macd.value ?? undefined;
      }

      // Extract SMAs from priceMovement metadata if available
      if (smaFast === undefined && smaSlow === undefined &&
        indicatorsObj?.priceMovement?.metadata) {
        const meta = indicatorsObj.priceMovement.metadata;
        if (meta.ma10 !== undefined) smaFast = meta.ma10;
        if (meta.ma20 !== undefined) smaSlow = meta.ma20;
      }
    }

    let indicatorsText = "";
    if (rsi !== undefined) {
      // Add visual indicator for OSI levels
      const rsiEmo = rsi > 70 ? "🥵" : (rsi < 30 ? "🥶" : "📊");
      indicatorsText += `${rsiEmo} RSI: ${rsi.toFixed(0)}`;
    }
    if (macd !== undefined) {
      if (indicatorsText) indicatorsText += " • "; // separator
      // Display MACD with 4 decimal precision to show small movements
      const macdDisplay = Math.abs(macd) < 0.01 ?
        `MACD: ${macd.toFixed(4)}` : `MACD: ${macd.toFixed(2)}`;
      indicatorsText += `📉 ${macdDisplay}`;
    }
    if (smaFast !== undefined && smaSlow !== undefined) {
      if (indicatorsText) indicatorsText += " • ";
      const trend = smaFast > smaSlow ? "↗️" : "↘️";
      indicatorsText +=
        `${trend} SMA: ${smaFast.toFixed(2)}/${smaSlow.toFixed(2)}`;
    }

    // Interval label: "Daily", "1h", "15m"
    // Combine into: "Daily • 85% Conf."
    const metaLine = `${intervalLabel} • ${confidenceStr}`;

    let body = metaLine;
    if (indicatorsText) {
      body += `\n${indicatorsText}`;
    }
    if (signal.reason) {
      // Truncate reason if too long
      const reasonShort = signal.reason.length > 60 ?
        signal.reason.substring(0, 57) + "..." : signal.reason;
      body += `\n💡 ${reasonShort}`;
    }

    const bodyWithConfidence = body;

    // Generate chart URL (using Finviz
    // as a reliable source for simple static charts)
    // t=SYMBOL, ty=c (candle), ta=0 (no advanced TA), p=d (daily), s=l (large)
    const imageUrl = `https://charts2.finviz.com/chart.ashx?t=${signal.symbol}&ty=c&ta=0&p=d&s=l`;

    // Send notification to all user devices (unless the push cap was hit,
    // quiet hours are active, or push channel is disabled)
    const response = (pushSlot === "capped" || !shouldSendPush) ? null :
      await messaging.sendEachForMulticast({
        tokens: fcmTokens,
        notification: {
          title: title,
          body: bodyWithConfidence,
          imageUrl: imageUrl,
        },
        data: {
          type: "trade_signal",
          symbol: signal.symbol,
          signal: signal.signal,
          interval: signal.interval || "1d",
          price: price?.toString() || "",
          confidence: confidence?.toString() || "",
          timestamp: signal.timestamp.toString(),
          imageUrl: imageUrl,
          channelId: resolvedDelivery.channelId,
          priority: resolvedDelivery.priority,
          sound: resolvedDelivery.sound || "silent",
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
          priority: resolvedDelivery.fcmAndroidPriority,
          notification: {
            channelId: resolvedDelivery.channelId,
            priority: resolvedDelivery.priority === "critical" ?
              "max" :
              resolvedDelivery.priority === "low" ?
                "low" :
                "high",
            ...(resolvedDelivery.sound ?
              { sound: resolvedDelivery.sound } :
              {}),
            clickAction: "FLUTTER_NOTIFICATION_CLICK",
            imageUrl: imageUrl,
          },
        },
        apns: {
          payload: {
            aps: {
              ...(resolvedDelivery.sound ?
                { sound: resolvedDelivery.sound } :
                {}),
              "badge": 1,
              "category": "TRADE_SIGNAL",
              "interruption-level": resolvedDelivery.apnsInterruptionLevel,
              "mutable-content": 1,
            },
          },
          fcmOptions: {
            imageUrl: imageUrl,
          },
        },
      }).catch(async (error) => {
        await releasePushSlot(userId, signal, reservation);
        throw error;
      });

    // No device got it, so the next signal may try again.
    if (response && response.successCount === 0) {
      await releasePushSlot(userId, signal, reservation);
    }

    // Dispatch external channels (Email, SMS, Webhook) if not in quiet hours
    const deliveredExternal = quietHoursSuppressed ? [] :
      await dispatchMultiChannelAlert(db, {
        userId,
        category: categoryKey as "BUY" | "SELL" | "HOLD",
        symbol: signal.symbol,
        title,
        body: bodyWithConfidence,
        confidence,
        settings: userSettings,
        resolved: resolvedDelivery,
        metadata: {
          interval: signal.interval || "1d",
          price: price || null,
        },
      });

    // Store notification in Firestore history if in_app channel is enabled
    if (resolvedDelivery.channels.includes("in_app")) {
      await db.collection("user")
        .doc(userId)
        .collection("signal_notifications")
        .add({
          symbol: signal.symbol,
          signal: signal.signal,
          interval: signal.interval || "1d",
          price: price || null,
          confidence: confidence || null,
          timestamp: FieldValue.serverTimestamp(),
          title: title,
          body: bodyWithConfidence,
          read: false,
          priority: resolvedDelivery.priority,
          channelId: resolvedDelivery.channelId,
          deliveredChannels: [
            ...(response && response.successCount > 0 ? ["push"] : []),
            "in_app",
            ...deliveredExternal,
          ],
          indicators: {
            rsi: rsi || null,
            macd: macd || null,
            smaFast: smaFast || null,
            smaSlow: smaSlow || null,
          },
          data: {
            type: "trade_signal",
            symbol: signal.symbol,
            signal: signal.signal,
            interval: signal.interval || "1d",
          },
        });
    }

    logger.info("Trade signal notification sent and stored", {
      userId,
      symbol: signal.symbol,
      signal: signal.signal,
      interval: signal.interval,
      pushSuppressed: response === null,
      successCount: response?.successCount,
      failureCount: response?.failureCount,
    });

    // Log any failures
    if (response && response.failureCount > 0) {
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
 */
async function notifyInterestedUsers(
  signal: TradeSignal
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
          sendTradeSignalNotification(userDoc.id, signal)
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
  "signals/{documentId}",
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

      await notifyInterestedUsers(signalData);
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
  "signals/{documentId}",
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

      await notifyInterestedUsers(afterData);
    } catch (error) {
      logger.error("Error in onTradeSignalUpdated", {
        documentId: event.params.documentId,
        error,
      });
    }
  }
);
