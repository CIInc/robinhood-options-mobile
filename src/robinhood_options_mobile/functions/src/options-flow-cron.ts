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
  { schedule: "every 15 minutes" },
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
      const notifications: Promise<string>[] = [];

      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      for (const alert of alerts as any[]) {
        // Filter flow items for this alert's symbol
        const symbolItems = flowItems.filter(
          (item) => item.symbol === alert.symbol
        );

        for (const item of symbolItems) {
          // Check conditions
          const matchesPremium = item.premium >= (alert.targetPremium || 50000);
          const matchesSentiment = alert.sentiment === "any" ||
            item.sentiment === alert.sentiment;

          // Only notify for recent items (e.g., last 15 minutes)
          // to avoid duplicates. In a real production system, we'd track
          // 'lastNotifiedAt' or similar on the alert or store processed
          // item IDs. For now, we'll use a time window.
          const itemTime = new Date(item.time).getTime();
          const fifteenMinutesAgo = Date.now() - 15 * 60 * 1000;
          const isRecent = itemTime > fifteenMinutesAgo;

          if (matchesPremium && matchesSentiment && isRecent) {
            // Fetch user's FCM tokens
            const userDoc = await admin.firestore()
              .collection("user")
              .doc(alert.uid)
              .get();
            // Assuming single token for simplicity, or array
            const fcmToken = userDoc.data()?.fcmToken;

            if (fcmToken) {
              const title = `Unusual Options Activity: ${item.symbol}`;
              const body = `${item.sentiment.toUpperCase()} flow detected! ` +
                `$${(item.premium / 1000).toFixed(1)}k premium on ` +
                `${item.type}s expiring ${item.expirationDate.split("T")[0]}`;

              notifications.push(
                messaging.send({
                  token: fcmToken,
                  notification: {
                    title,
                    body,
                  },
                  data: {
                    type: "options_flow_alert",
                    symbol: item.symbol,
                  },
                })
              );

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
