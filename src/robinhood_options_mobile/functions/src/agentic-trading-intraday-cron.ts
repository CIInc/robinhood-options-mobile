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
  {
    // Run every hour during market hours (9:30 AM - 4:00 PM ET)
    // Monday-Friday at 30 minutes past each hour
    schedule: "30 9-16 * * 1-5",
    timeZone: "America/New_York", // Eastern Time (handles EST/EDT)
    memory: "1GiB",
    timeoutSeconds: 540,
  },
  async () => {
    logger.info(
      "Intraday Agentic Trading Cron: Scanning all agentic_trading " +
      "chart documents for hourly signals"
    );
    try {
      const docRefs = await db.collection("agentic_trading").listDocuments();
      if (docRefs.length === 0) {
        logger.info("No agentic_trading documents found");
        return;
      }

      let processedCount = 0;
      let skippedCount = 0;
      let errorCount = 0;

      // Fetch config once
      let config = {};
      try {
        const configDoc = await db.doc("agentic_trading/config").get();
        if (configDoc.exists) {
          config = configDoc.data() || {};
        }
      } catch (e) {
        logger.error("Error fetching config", e);
      }

      const docsToProcess = docRefs.filter((doc) =>
        doc.id.startsWith("chart_") &&
        !doc.id.endsWith("_1h") &&
        !doc.id.endsWith("_15m")
      );

      const BATCH_SIZE = 10;
      for (let i = 0; i < docsToProcess.length; i += BATCH_SIZE) {
        const batch = docsToProcess.slice(i, i + BATCH_SIZE);
        await Promise.all(batch.map(async (doc) => {
          const symbol = doc.id.replace("chart_", "");
          if (!symbol) {
            logger.warn(`Invalid symbol extracted from document ID: ${doc.id}`);
            return;
          }

          logger.info(
            `Triggering intraday trade proposal for symbol: ${symbol}`
          );
          try {
            // Generate hourly signal
            const data = {
              symbol: symbol,
              interval: "1h",
              ...config,
              portfolioState: {},
            };
            const result = await performTradeProposal({ data } as any);
            if (result && result.status === "no_action") {
              skippedCount++;
            } else {
              processedCount++;
            }
          } catch (err) {
            errorCount++;
            logger.error(
              `Error triggering intraday trade proposal for ${symbol}:`,
              err
            );
            // Continue processing other symbols even if one fails
          }
        }));
      }

      logger.info(
        `Intraday Agentic Trading Cron completed: ${processedCount} ` +
        `processed, ${skippedCount} skipped, ${errorCount} errors`
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
  {
    // Run every 15 minutes during market hours (9:30 AM - 4:00 PM ET)
    // At 15, 30, 45, and 00 minutes past the hour
    schedule: "15,30,45,0 9-16 * * 1-5",
    timeZone: "America/New_York", // Eastern Time (handles EST/EDT)
    memory: "1GiB",
    timeoutSeconds: 540,
  },
  async () => {
    logger.info(
      "15-minute Agentic Trading Cron: Scanning for 15m signals"
    );
    try {
      const docRefs = await db.collection("agentic_trading").listDocuments();
      if (docRefs.length === 0) {
        logger.info("No agentic_trading documents found");
        return;
      }

      let processedCount = 0;
      let skippedCount = 0;
      let errorCount = 0;

      // Fetch config once
      let config = {};
      try {
        const configDoc = await db.doc("agentic_trading/config").get();
        if (configDoc.exists) {
          config = configDoc.data() || {};
        }
      } catch (e) {
        logger.error("Error fetching config", e);
      }

      const docsToProcess = docRefs.filter((doc) =>
        doc.id.startsWith("chart_") &&
        !doc.id.endsWith("_1h") &&
        !doc.id.endsWith("_15m")
      );

      const BATCH_SIZE = 25;
      for (let i = 0; i < docsToProcess.length; i += BATCH_SIZE) {
        const batch = docsToProcess.slice(i, i + BATCH_SIZE);
        await Promise.all(batch.map(async (doc) => {
          const symbol = doc.id.replace("chart_", "");
          if (!symbol) {
            logger.warn(`Invalid symbol extracted from document ID: ${doc.id}`);
            return;
          }

          logger.info(
            `Triggering 15m trade proposal for symbol: ${symbol}`
          );
          try {
            // Generate 15-minute signal
            const data = {
              symbol: symbol,
              interval: "15m",
              ...config,
              portfolioState: {},
            };
            const result = await performTradeProposal({ data } as any);
            if (result && result.status === "no_action") {
              skippedCount++;
            } else {
              processedCount++;
            }
          } catch (err) {
            errorCount++;
            logger.error(
              `Error triggering 15m trade proposal for ${symbol}:`,
              err
            );
            // Continue processing other symbols even if one fails
          }
        }));
      }

      logger.info(
        `15-minute Agentic Trading Cron completed: ${processedCount} ` +
        `processed, ${skippedCount} skipped, ${errorCount} errors`
      );
    } catch (err) {
      logger.error("Fatal error in 15m agentic trading cron job:", err);
      throw err; // Re-throw to mark the cron job as failed
    }
  }
);
