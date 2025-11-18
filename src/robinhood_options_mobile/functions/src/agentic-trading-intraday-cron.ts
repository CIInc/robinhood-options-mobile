import { onSchedule } from "firebase-functions/v2/scheduler";
import { getFirestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { performTradeProposal } from "./agentic-trading";

const db = getFirestore();

/**
 * Intraday Agentic Trading Cron Job
 * Runs during market hours to generate intraday trade signals
 * Scans all symbols with chart_ documents and generates 1h signals
 */
export const agenticTradingIntradayCron = onSchedule(
  // Run every hour during market hours (9:30 AM - 4:00 PM ET)
  // Monday-Friday at 30 minutes past each hour
  "30 9-16 * * mon-fri",
  async () => {
    logger.info(
      "Intraday Agentic Trading Cron: Scanning all agentic_trading " +
      "chart documents for hourly signals"
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
            `Triggering intraday trade proposal for symbol: ${symbol}`
          );
          try {
            const configDoc = await db.doc("agentic_trading/config").get();
            const config = configDoc.exists ? configDoc.data() : {};

            // Generate hourly signal
            const data = {
              symbol: symbol,
              interval: "1h",
              ...config,
              portfolioState: {},
            };
            await performTradeProposal({ data } as any);
            processedCount++;
          } catch (err) {
            errorCount++;
            logger.error(
              `Error triggering intraday trade proposal for ${symbol}:`,
              err
            );
            // Continue processing other symbols even if one fails
          }
        }
      }

      logger.info(
        `Intraday Agentic Trading Cron completed: ${processedCount} ` +
        `processed, ${errorCount} errors`
      );
    } catch (err) {
      logger.error("Fatal error in intraday agentic trading cron job:", err);
      throw err; // Re-throw to mark the cron job as failed
    }
  }
);

/**
 * 15-minute Intraday Agentic Trading Cron Job
 * Runs more frequently during market hours for shorter-term signals
 */
export const agenticTrading15mCron = onSchedule(
  // Run every 15 minutes during market hours (9:30 AM - 4:00 PM ET)
  // At 15, 30, 45, and 00 minutes past the hour
  "15,30,45,0 9-16 * * mon-fri",
  async () => {
    logger.info(
      "15-minute Agentic Trading Cron: Scanning for 15m signals"
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
            `Triggering 15m trade proposal for symbol: ${symbol}`
          );
          try {
            const configDoc = await db.doc("agentic_trading/config").get();
            const config = configDoc.exists ? configDoc.data() : {};

            // Generate 15-minute signal
            const data = {
              symbol: symbol,
              interval: "15m",
              ...config,
              portfolioState: {},
            };
            await performTradeProposal({ data } as any);
            processedCount++;
          } catch (err) {
            errorCount++;
            logger.error(
              `Error triggering 15m trade proposal for ${symbol}:`,
              err
            );
            // Continue processing other symbols even if one fails
          }
        }
      }

      logger.info(
        `15-minute Agentic Trading Cron completed: ${processedCount} ` +
        `processed, ${errorCount} errors`
      );
    } catch (err) {
      logger.error("Fatal error in 15m agentic trading cron job:", err);
      throw err; // Re-throw to mark the cron job as failed
    }
  }
);
