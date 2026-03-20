import { onSchedule } from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import { fetchOptionsFlowForSymbols } from "./options-flow-utils";
import { getMessaging } from "firebase-admin/messaging";

// Ensure Firebase Admin is initialized
if (admin.apps.length === 0) {
  admin.initializeApp();
}

export const optionsFlowCron = onSchedule(
  {
    schedule: "every 15 minutes",
    secrets: ["TWELVE_DATA_API_KEY"],
  },
  async (event) => {
    logger.info("Running optionsFlowCron", { event });

    try {
      // 1. Fetch all active alerts
      const alertsSnapshot = await admin.firestore()
        .collection("options_flow_alerts")
        .where("isActive", "==", true)
        .get();

      if (alertsSnapshot.empty) {
        logger.info("No active alerts found.");
        return;
      }

      const alerts = alertsSnapshot.docs.map((doc) => ({
        id: doc.id,
        ...doc.data(),
      }));

      // 2. Get unique symbols from alerts to minimize API calls
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const symbols = [...new Set(alerts.map((a: any) => a.symbol))];
      logger.info(
        `Fetching flow for ${symbols.length} symbols: ${symbols.join(", ")}`
      );

      // 3. Fetch options flow data
      const flowItems = await fetchOptionsFlowForSymbols(symbols);
      logger.info(`Fetched ${flowItems.length} flow items.`);

      // 4. Match alerts and send notifications
      const messaging = getMessaging();
      const notifications: Promise<unknown>[] = [];

      const getDaysToExpiration = (expirationDate: string): number | null => {
        const exp = new Date(expirationDate);
        if (Number.isNaN(exp.getTime())) return null;
        const today = new Date();
        const start = new Date(today.getFullYear(), today.getMonth(),
          today.getDate());
        const end = new Date(exp.getFullYear(), exp.getMonth(), exp.getDate());
        return Math.round((end.getTime() - start.getTime()) / 86400000);
      };

      const matchesExpirationRange = (
        range: string | undefined,
        expirationDate: string
      ): boolean => {
        if (!range || range === "any") return true;
        const days = getDaysToExpiration(expirationDate);
        if (days === null) return true;
        if (range === "0-7") return days >= -1 && days <= 7;
        if (range === "8-30") return days > 7 && days <= 30;
        if (range === "30+") return days > 30;
        return true;
      };

      const matchesFlags = (
        alertFlags: string[] | undefined,
        itemFlags: string[]
      ): boolean => {
        if (!alertFlags || alertFlags.length === 0) return true;
        return alertFlags.some((flag) => itemFlags.includes(flag));
      };

      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      for (const alert of alerts as any[]) {
        // Filter flow items for this alert's symbol
        const symbolItems = flowItems.filter(
          (item) => item.symbol === alert.symbol
        );

        for (const item of symbolItems) {
          // Check conditions
          const minPremium =
            alert.minPremium ?? alert.targetPremium ?? 50000;
          const minVolume = alert.minVolume ?? null;
          const matchesPremium = item.premium >= minPremium;
          const matchesVolume = !minVolume || item.volume >= minVolume;
          const matchesSentiment = alert.sentiment === "any" ||
            item.sentiment === alert.sentiment;
          const matchesExpiration = matchesExpirationRange(
            alert.expirationRange,
            item.expirationDate
          );
          const matchesFlagFilter = matchesFlags(alert.flags, item.flags);

          // Only notify for recent items (e.g., last 15 minutes)
          // to avoid duplicates. In a real production system, we'd track
          // 'lastNotifiedAt' or similar on the alert or store processed
          // item IDs. For now, we'll use a time window.
          const itemTime = new Date(item.time).getTime();
          const fifteenMinutesAgo = Date.now() - 15 * 60 * 1000;
          const isRecent = itemTime > fifteenMinutesAgo;

          if (
            matchesPremium &&
            matchesVolume &&
            matchesSentiment &&
            matchesExpiration &&
            matchesFlagFilter &&
            isRecent
          ) {
            // Fetch user's FCM tokens
            const userDoc = await admin.firestore()
              .collection("user")
              .doc(alert.uid)
              .get();
            const userData = userDoc.data();
            const devices: Array<{ fcmToken?: string | null }> =
              userData?.devices || [];
            const fcmTokens: string[] = devices
              .map((device) => device.fcmToken)
              .filter((token): token is string =>
                token != null && token !== "");

            if (fcmTokens.length > 0) {
              const premiumLabel = `$${(item.premium / 1000).toFixed(1)}k`;
              const expLabel = item.expirationDate.split("T")[0];
              const flagLabel = item.flags?.length ?
                ` Flags: ${item.flags.slice(0, 3).join(", ")}` :
                "";

              const title = `Options Flow Alert: ${item.symbol}`;
              const body = `${item.sentiment.toUpperCase()} ` +
                `${item.type} ${premiumLabel} exp ${expLabel}.` +
                flagLabel;

              const notificationData = {
                type: "options_flow_alert",
                symbol: item.symbol,
                sentiment: item.sentiment,
                premium: item.premium.toString(),
                volume: item.volume.toString(),
                expirationDate: item.expirationDate,
                flowType: item.flowType,
                flags: JSON.stringify(item.flags || []),
              };

              notifications.push(
                messaging.sendEachForMulticast({
                  tokens: fcmTokens,
                  notification: {
                    title,
                    body,
                  },
                  data: notificationData,
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
                        category: "OPTIONS_FLOW_ALERT",
                      },
                    },
                  },
                })
              );

              await admin.firestore()
                .collection("user")
                .doc(alert.uid)
                .collection("flow_notifications")
                .add({
                  symbol: item.symbol,
                  sentiment: item.sentiment,
                  premium: item.premium,
                  volume: item.volume,
                  expirationDate: item.expirationDate,
                  type: item.type,
                  flowType: item.flowType,
                  flags: item.flags || [],
                  title,
                  body,
                  read: false,
                  timestamp: admin.firestore.FieldValue.serverTimestamp(),
                  data: notificationData,
                });

              logger.info(
                `Queued notification for alert ${alert.id} on ${item.symbol}`
              );

              // Break after first match per alert to avoid spamming
              // for the same symbol in one run
              break;
            }
          }
        }
      }

      await Promise.all(notifications);
      logger.info(`Sent ${notifications.length} notifications.`);
    } catch (error) {
      logger.error("Error in optionsFlowCron", error);
    }
  });
