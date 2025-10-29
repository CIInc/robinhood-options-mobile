import { onSchedule } from "firebase-functions/v2/scheduler";
import { getFirestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { performTradeProposal } from "./agentic-trading";

const db = getFirestore();

export const agenticTradingCron = onSchedule(
  // "every 5 minutes",
  // "every day 09:30",
  "every mon,tue,wed,thu,fri 09:30",
  async () => {
    logger.info(
      "Agentic Trading Cron: Scanning all agentic_trading chart documents"
    );
    const snapshot = await db.collection("agentic_trading").get();
    for (const doc of snapshot.docs) {
      if (doc.id.startsWith("chart_")) {
        const symbol = doc.id.replace("chart_", "");
        logger.info(
          `Triggering initiateTradeProposal for symbol: ${symbol}`
        );
        // You may want to load config/portfolioState
        // from Firestore or use defaults
        const configDoc = await db.doc("agentic_trading/config").get();
        const config = configDoc.exists ? configDoc.data() : {};
        // For now, portfolioState is empty
        const data = {
          symbol,
          ...config,
          portfolioState: {},
        };
        // Call the function logic directly (not as HTTPS callable)
        try {
          // initiateTradeProposal is an onCall function,
          // so it expects a CallableRequest.
          // We need to pass the data in the 'data' property
          // of the request object.
          // The second argument is the context, which is empty for cron jobs.
          await performTradeProposal({ data } as any);
        } catch (err) {
          logger.error(
            `Error triggering trade proposal for ${symbol}:`,
            err
          );
        }
      }
    }
  }
);
