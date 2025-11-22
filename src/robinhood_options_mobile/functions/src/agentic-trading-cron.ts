import { onSchedule } from "firebase-functions/v2/scheduler";
import { onRequest } from "firebase-functions/v2/https";
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
 * Core logic that scans all agentic_trading chart documents and
 * triggers trade proposals. Can be invoked by the scheduled function
 * or ad-hoc via the callable endpoint.
 */
export async function runAgenticTradingCron() {
  logger.info(
    "Agentic Trading Cron: Scanning all agentic_trading chart documents"
  );
  const snapshot = await db.collection("agentic_trading").get();
  if (snapshot.empty) {
    logger.info("No agentic_trading documents found");
    return {
      processedCount: 0,
      errorCount: 0,
      timestamp: new Date().toISOString(),
    };
  }

  let processedCount = 0;
  let errorCount = 0;

  for (const doc of snapshot.docs) {
    if (!doc.id.startsWith("chart_") ||
      doc.id.endsWith("_15m") || doc.id.endsWith("_1h")) continue;
    const symbol = doc.id.replace("chart_", "");
    if (!symbol) {
      logger.warn(`Invalid symbol extracted from document ID: ${doc.id}`);
      continue;
    }

    logger.info(
      `Triggering initiateTradeProposal for symbol: ${symbol}`
    );
    try {
      const configDoc = await db.doc("agentic_trading/config").get();
      const config = configDoc.exists ? configDoc.data() : {};
      const data = {
        symbol,
        interval: "1d",
        ...config,
        portfolioState: {},
      };
      interface PerformTradeProposalRequest {
        data: {
          symbol: string;
          interval: string;
          portfolioState: Record<string, unknown>;
          [key: string]: unknown;
        };
      }
      await performTradeProposal({ data } as PerformTradeProposalRequest);
      processedCount++;
    } catch (err) {
      errorCount++;
      logger.error(`Error triggering trade proposal for ${symbol}:`, err);
    }
  }

  const summary: AgenticTradingCronResult = {
    processedCount,
    errorCount,
    timestamp: new Date().toISOString(),
  };
  logger.info(
    `Agentic Trading Cron completed: ${summary.processedCount} processed, ` +
    `${summary.errorCount} errors`
  );
  return summary;
}

// Scheduled trigger (EOD). Adjust schedule as needed.
export const agenticTradingCron = onSchedule(
  "every mon,tue,wed,thu,fri 16:00",
  async () => {
    try {
      await runAgenticTradingCron();
    } catch (err) {
      logger.error("Fatal error in agentic trading cron job:", err);
      throw err; // Mark cron job as failed
    }
  }
);

// Callable function to trigger the cron logic ad-hoc
// (e.g., from dashboard or admin tooling).
// Optional: add auth/role checks before execution.
export const agenticTradingCronInvoke = onRequest(async (request, response) => {
  // logger.info(request.query, { structuredData: true });
  // Example simple auth gating (adjust to project standards):
  // if (!request.auth || request.auth.token.admin !== true) {
  //   throw new HttpsError('permission-denied', 'Admin privileges required');
  // }
  try {
    const result = await runAgenticTradingCron();
    // Send JSON response instead of returning the result
    // to satisfy onRequest signature (void | Promise<void>)
    response.json(result);
  } catch (err) {
    logger.error("Ad-hoc cron invocation failed", err);
    response.status(500).json({ error: "Ad-hoc cron invocation failed" });
  }
});
