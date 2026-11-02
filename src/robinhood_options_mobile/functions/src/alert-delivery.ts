/**
 * Multi-Channel Alert Delivery, Priority Notification Channels &
 * Customization Helper
 *
 * Shared utilities for resolving Android/APNs notification priority channels,
 * custom alert sounds, quiet hours suppression, and external channel queuing
 * (Email, SMS, Webhook) across Trade Signals, Custom Alerts, and Options Flow.
 */

import * as logger from "firebase-functions/logger";
import { Firestore, FieldValue } from "firebase-admin/firestore";

/**
 * Extended notification settings stored at user/{uid}.
 */
export interface UserNotificationCustomizationSettings {
  enabled?: boolean;
  signalTypes?: string[];
  symbols?: string[];
  intervals?: string[];
  includeHold?: boolean;
  minConfidence?: number;
  deliveryChannels?: string[];
  emailAddress?: string | null;
  phoneNumber?: string | null;
  webhookUrl?: string | null;
  criticalOnlyExternalChannels?: boolean;
  priorityChannel?: "critical" | "high" | "standard" | "low" | string;
  alertSound?: string;
  vibrate?: boolean;
  signalSoundOverrides?: Record<string, string>;
  quietHoursEnabled?: boolean;
  quietHoursStartHour?: number;
  quietHoursEndHour?: number;
  bypassQuietHoursForCritical?: boolean;
  requiredIndicators?: string[];
  priceTriggerEnabled?: boolean;
  gexTriggerEnabled?: boolean;
  optionsFlowTriggerEnabled?: boolean;
}

/**
 * Per-alert customization overrides from CustomAlert or OptionFlowAlert.
 */
export interface AlertDeliveryOverride {
  priority?: string;
  sound?: string;
  channels?: string[];
}

/**
 * Resolved delivery configuration for FCM and multi-channel dispatch.
 */
export interface ResolvedAlertDelivery {
  channelId: string;
  priority: "critical" | "high" | "standard" | "low";
  fcmAndroidPriority: "high" | "normal";
  apnsInterruptionLevel: "critical" | "time-sensitive" | "active" | "passive";
  sound: string | undefined;
  vibrate: boolean;
  channels: string[];
  isCritical: boolean;
}

/**
 * Parameters for multi-channel dispatch (Email, SMS, Webhook).
 */
export interface MultiChannelDispatchParams {
  userId: string;
  category: "BUY" | "SELL" | "HOLD" | "GEX" | "FLOW" | "CUSTOM";
  symbol: string;
  title: string;
  body: string;
  confidence?: number;
  settings?: UserNotificationCustomizationSettings;
  resolved: ResolvedAlertDelivery;
  metadata?: Record<string, unknown>;
}

/**
 * Determine whether current UTC hour falls within configured quiet hours,
 * accounting for critical alert bypass.
 *
 * @param {UserNotificationCustomizationSettings|undefined} settings Settings
 * @param {string} priority Resolved alert priority
 * @param {Date} now Optional current Date for deterministic testing
 * @return {boolean} True if push/external notifications should be suppressed
 */
export function isWithinQuietHours(
  settings?: UserNotificationCustomizationSettings,
  priority = "high",
  now: Date = new Date()
): boolean {
  if (!settings?.quietHoursEnabled) {
    return false;
  }

  const bypassCritical = settings.bypassQuietHoursForCritical ?? true;
  if (bypassCritical && priority === "critical") {
    return false;
  }

  const startHour = settings.quietHoursStartHour ?? 22;
  const endHour = settings.quietHoursEndHour ?? 7;
  if (startHour === endHour) {
    return false;
  }

  const currentHour = now.getUTCHours();
  if (startHour < endHour) {
    return currentHour >= startHour && currentHour < endHour;
  }
  // Overnight window (e.g. 22:00 -> 07:00)
  return currentHour >= startHour || currentHour < endHour;
}

/**
 * Resolve Android notification channel ID, APNs interruption level, custom
 * sound, and active delivery channels from user settings and alert overrides.
 *
 * @param {string} category Signal/alert category
 * @param {UserNotificationCustomizationSettings|undefined} settings Settings
 * @param {AlertDeliveryOverride|undefined} override Per-alert overrides
 * @param {number|undefined} confidence Signal confidence (0..1)
 * @return {ResolvedAlertDelivery} Resolved delivery parameters
 */
export function resolveChannelAndSound(
  category: string,
  settings?: UserNotificationCustomizationSettings,
  override?: AlertDeliveryOverride,
  confidence?: number
): ResolvedAlertDelivery {
  const rawPriority = override?.priority ||
    settings?.priorityChannel ||
    "high";
  const normalizedPriority = (
    ["critical", "high", "standard", "low"].includes(rawPriority) ?
      rawPriority :
      "high"
  ) as "critical" | "high" | "standard" | "low";

  const isHighConfidence = confidence !== undefined && confidence >= 0.85;
  const isCritical = normalizedPriority === "critical" || isHighConfidence;
  const effectivePriority = isCritical ? "critical" : normalizedPriority;

  // Map to dedicated Android notification channel ID
  let channelId = "trade_signals";
  if (effectivePriority === "critical") {
    channelId = "critical_alerts";
  } else if (effectivePriority === "low") {
    channelId = "silent_digest";
  } else if (category === "FLOW") {
    channelId = "options_flow";
  } else if (category === "CUSTOM") {
    channelId = "custom_alerts";
  }

  // Resolve custom sound (per-alert -> per-category -> global default)
  const categoryOverride = settings?.signalSoundOverrides?.[category];
  const rawSound = override?.sound ||
    categoryOverride ||
    settings?.alertSound ||
    "default";

  if (rawSound === "silent") {
    channelId = "silent_digest";
  }

  const sound = rawSound === "silent" || effectivePriority === "low" ?
    undefined :
    rawSound;

  const vibrate = (settings?.vibrate ?? true) &&
    rawSound !== "silent" &&
    effectivePriority !== "low";

  const fcmAndroidPriority =
    effectivePriority === "critical" || effectivePriority === "high" ?
      "high" :
      "normal";

  let apnsInterruptionLevel:
    "critical" | "time-sensitive" | "active" | "passive" = "active";
  if (effectivePriority === "critical") {
    apnsInterruptionLevel = "critical";
  } else if (effectivePriority === "high") {
    apnsInterruptionLevel = "time-sensitive";
  } else if (effectivePriority === "low" || rawSound === "silent") {
    apnsInterruptionLevel = "passive";
  }

  const channels = override?.channels && override.channels.length > 0 ?
    override.channels :
    settings?.deliveryChannels && settings.deliveryChannels.length > 0 ?
      settings.deliveryChannels :
      ["push", "in_app"];

  return {
    channelId,
    priority: effectivePriority,
    fcmAndroidPriority,
    apnsInterruptionLevel,
    sound,
    vibrate,
    channels,
    isCritical,
  };
}

/**
 * Dispatch alert to configured external channels (Email, SMS, Webhook) via
 * Firestore queue collections (compatible with Firebase Trigger Email / Twilio
 * extensions and webhook workers).
 *
 * @param {Firestore} db Firestore instance
 * @param {MultiChannelDispatchParams} params Dispatch parameters
 * @return {Promise<string[]>} List of external channels queued
 */
export async function dispatchMultiChannelAlert(
  db: Firestore,
  params: MultiChannelDispatchParams
): Promise<string[]> {
  const {
    userId,
    category,
    symbol,
    title,
    body,
    confidence,
    settings,
    resolved,
    metadata,
  } = params;

  const deliveredExternal: string[] = [];
  const channels = resolved.channels;
  const criticalOnly = settings?.criticalOnlyExternalChannels ?? true;
  const qualifiesForExternal = !criticalOnly ||
    resolved.isCritical ||
    (confidence !== undefined && confidence >= 0.8);

  if (!qualifiesForExternal) {
    return deliveredExternal;
  }

  const writes: Promise<unknown>[] = [];

  if (channels.includes("email") && settings?.emailAddress?.trim()) {
    const email = settings.emailAddress.trim();
    deliveredExternal.push("email");
    writes.push(
      db.collection("mail_queue").add({
        userId,
        to: [email],
        category,
        symbol,
        priority: resolved.priority,
        message: {
          subject: `[RealizeAlpha ${resolved.priority.toUpperCase()}] ${title}`,
          text: `${title}\n\n${body}`,
        },
        metadata: metadata || {},
        createdAt: FieldValue.serverTimestamp(),
      })
    );
  }

  if (channels.includes("sms") && settings?.phoneNumber?.trim()) {
    const to = settings.phoneNumber.trim();
    deliveredExternal.push("sms");
    writes.push(
      db.collection("sms_queue").add({
        userId,
        to,
        category,
        symbol,
        priority: resolved.priority,
        body: `${title} - ${body.replace(/\n+/g, " | ")}`,
        metadata: metadata || {},
        createdAt: FieldValue.serverTimestamp(),
      })
    );
  }

  if (channels.includes("webhook") && settings?.webhookUrl?.trim()) {
    const url = settings.webhookUrl.trim();
    deliveredExternal.push("webhook");
    writes.push(
      db.collection("webhook_queue").add({
        userId,
        url,
        payload: {
          event: "alert_triggered",
          category,
          symbol,
          priority: resolved.priority,
          title,
          body,
          confidence: confidence ?? null,
          metadata: metadata || {},
          timestamp: Date.now(),
        },
        createdAt: FieldValue.serverTimestamp(),
      })
    );
  }

  if (writes.length > 0) {
    try {
      await Promise.all(writes);
      logger.info("Queued external multi-channel notifications", {
        userId,
        symbol,
        category,
        channels: deliveredExternal,
      });
    } catch (error) {
      logger.error("Failed to queue external channel notifications", {
        userId,
        symbol,
        error,
      });
    }
  }

  return deliveredExternal;
}
