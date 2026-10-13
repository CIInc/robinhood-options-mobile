import { onSchedule } from "firebase-functions/v2/scheduler";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { getFirestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { performTradeProposal } from "./agentic-trading";

const db = getFirestore();

/**
 * Result summary for a cron run.
 */
export interface AgenticTradingCronResult {
  processedCount: number;
  errorCount: number;
  timestamp: string;
}

/**
 * Core logic that scans all charts documents and
 * triggers trade proposals. Can be invoked by the scheduled function
 * or ad-hoc via the callable endpoint.
 */
export async function runAgenticTradingCron() {
  logger.info(
    "Agentic Trading Cron: Scanning all chart documents in charts collection"
  );
  const docRefs = await db.collection("charts").listDocuments();
  if (docRefs.length === 0) {
    logger.warn("⚠️ No chart documents found in Firestore charts collection!");
    return {
      processedCount: 0,
      errorCount: 0,
      timestamp: new Date().toISOString(),
    };
  }

  logger.info(
    `📊 Found ${docRefs.length} documents in ` +
    "charts collection"
  );

  let processedCount = 0;
  let errorCount = 0;
  let skippedCount = 0;


  // Filter docs first
  const docsToProcess = docRefs.filter((doc) => {
    // Skip intraday charts (only process daily charts)
    if (doc.id.endsWith("_15m") ||
      doc.id.endsWith("_1h") ||
      doc.id.endsWith("_30m")) {
      // logger.info(`⏭️ Skipping intraday chart: ${doc.id}`);
      // skippedCount++;
      return false;
    }
    return true;
  });

  logger.info(`Processing ${docsToProcess.length} documents after filtering.`);

  const delay = (ms: number) =>
    new Promise((resolve) => setTimeout(resolve, ms));

  // Process in batches
  const BATCH_SIZE = 5;
  for (let i = 0; i < docsToProcess.length; i += BATCH_SIZE) {
    const batch = docsToProcess.slice(i, i + BATCH_SIZE);

    // Add delay between batches to throttle API requests
    if (i > 0) {
      await delay(2000);
    }

    await Promise.all(batch.map(async (doc) => {
      const symbol = doc.id.replace("chart_", "");
      if (!symbol) {
        logger.warn(`Invalid symbol extracted from document ID: ${doc.id}`);
        return;
      }

      try {
        const data = {
          symbol,
          interval: "1d",
          portfolioState: {},
          skipRiskGuard: true,
          gexCacheOnly: false,
          marketDataCacheOnly: true,
        };
        interface PerformTradeProposalRequest {
          data: {
            symbol: string;
            interval: string;
            portfolioState: Record<string, unknown>;
            [key: string]: unknown;
          };
        }
        const result = await performTradeProposal(
          { data } as PerformTradeProposalRequest
        );
        if (result && result.status === "error") {
          errorCount++;
        } else if (result && result.status === "no_action") {
          skippedCount++;
        } else {
          processedCount++;
        }
      } catch (err) {
        errorCount++;
        logger.error(`Error triggering trade proposal for ${symbol}:`, err);
      }
    }));
  }

  const summary: AgenticTradingCronResult = {
    processedCount,
    errorCount,
    timestamp: new Date().toISOString(),
  };
  logger.info(
    "✅ Agentic Trading Cron completed: " +
    `${summary.processedCount} processed, ` +
    `${skippedCount} skipped (intraday), ` +
    `${summary.errorCount} errors`
  );
  return summary;
}

// Scheduled trigger (EOD). Runs at 4:00 PM Eastern Time (EST/EDT)
// Note: Uses America/New_York timezone to handle DST automatically
export const agenticTradingCron = onSchedule(
  {
    schedule: "0 16 * * 1-5", // Every weekday at 4:00 PM
    timeZone: "America/New_York", // Eastern Time (handles EST/EDT)
    secrets: ["TWELVE_DATA_API_KEY", "GEMINI_API_KEY"],
    memory: "1GiB", // Increase memory for processing multiple symbols
    timeoutSeconds: 540, // 9 minutes timeout
  },
  async () => {
    try {
      logger.info("🕐 EOD Cron triggered at 4:00 PM ET");
      await runAgenticTradingCron();
      logger.info("✅ EOD Cron completed successfully");
    } catch (err) {
      logger.error("❌ Fatal error in agentic trading cron job:", err);
      throw err; // Mark cron job as failed
    }
  }
);

// Callable function to trigger the cron logic ad-hoc
// (e.g., from dashboard or admin tooling).
// Enforces authentication and admin role check to prevent unauthorized
// execution.
export const agenticTradingCronInvoke = onCall(
  {
    secrets: ["TWELVE_DATA_API_KEY", "GEMINI_API_KEY"],
    memory: "1GiB",
    timeoutSeconds: 540, // 9 minutes
  },
  async (request) => {
    // SECURITY: Require authentication
    if (!request.auth || !request.auth.uid) {
      throw new HttpsError(
        "unauthenticated",
        "Authentication is required to trigger ad-hoc cron invocation."
      );
    }
    // SECURITY: Require admin role
    if (request.auth.token?.role !== "admin") {
      throw new HttpsError(
        "permission-denied",
        "Admin privileges are required to trigger ad-hoc cron invocation."
      );
    }

    try {
      return await runAgenticTradingCron();
    } catch (err) {
      logger.error("Ad-hoc cron invocation failed", err);
      throw new HttpsError(
        "internal",
        "Ad-hoc cron invocation failed."
      );
    }
  }
);
