import { onSchedule } from "firebase-functions/v2/scheduler";
import { getFirestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { performTradeProposal } from "./agentic-trading";

const db = getFirestore();

export const agenticTradingCron = onSchedule(
  // "every 5 minutes",
  // "every day 09:30",
  // "every 3 hours on mon,tue,wed,thu,fri",
  // "every mon,tue,wed,thu,fri 09:30",
  "every mon,tue,wed,thu,fri 16:00",
  async () => {
    logger.info(
      "Agentic Trading Cron: Scanning all agentic_trading chart documents"
    );
    try {
      const snapshot = await db.collection("agentic_trading").get();
      if (snapshot.empty) {
        logger.info("No agentic_trading documents found");
        return;
      }

      let processedCount = 0;
      let errorCount = 0;

      for (const doc of snapshot.docs) {
        if (doc.id.startsWith("chart_")) {
          const symbol = doc.id.replace("chart_", "");
          if (!symbol) {
            logger.warn(`Invalid symbol extracted from document ID: ${doc.id}`);
            continue;
          }

          logger.info(
            `Triggering initiateTradeProposal for symbol: ${symbol}`
          );
          // You may want to load config/portfolioState
          // from Firestore or use defaults
          try {
            const configDoc = await db.doc("agentic_trading/config").get();
            const config = configDoc.exists ? configDoc.data() : {};
            // For now, portfolioState is empty
            const data = {
              symbol,
              ...config,
              portfolioState: {},
            };
            // Call the function logic directly (not as HTTPS callable)
            await performTradeProposal({ data } as any);
            processedCount++;
          } catch (err) {
            errorCount++;
            logger.error(
              `Error triggering trade proposal for ${symbol}:`,
              err
            );
            // Continue processing other symbols even if one fails
          }
        }
      }

      logger.info(
        `Agentic Trading Cron completed: ${processedCount} processed, ` +
        `${errorCount} errors`
      );
    } catch (err) {
      logger.error("Fatal error in agentic trading cron job:", err);
      throw err; // Re-throw to mark the cron job as failed
    }
  }
);
