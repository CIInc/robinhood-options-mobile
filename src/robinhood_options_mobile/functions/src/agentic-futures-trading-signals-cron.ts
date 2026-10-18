import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions";
import { getFirestore } from "firebase-admin/firestore";
import { performFuturesSignal } from "./agentic-futures-trading";

const db = getFirestore();

interface FuturesWatchItem {
  contractId: string;
  symbol: string;
  interval?: string;
  config?: Record<string, unknown>;
}

export const futuresSignalsCron = onSchedule(
  {
    schedule: "*/15 * * * 1-5",
    timeZone: "America/New_York",
    secrets: ["TWELVE_DATA_API_KEY"],
    memory: "1GiB",
    timeoutSeconds: 540,
  },
  async () => {
    try {
      const watchDoc = await db.doc("signals/futures_watchlist").get();
      if (!watchDoc.exists) {
        logger.info("No signals/futures_watchlist found, skipping cron");
        return;
      }

      const data = watchDoc.data();
      const contracts = (data?.contracts as FuturesWatchItem[]) || [];
      if (!Array.isArray(contracts) || contracts.length === 0) {
        logger.info("futures_watchlist has no contracts");
        return;
      }

      logger.info(`Futures Signals Cron: ${contracts.length} contracts`);

      for (const item of contracts) {
        if (!item.contractId || !item.symbol) {
          continue;
        }
        await performFuturesSignal({
          data: {
            symbol: item.symbol,
            contractId: item.contractId,
            interval: item.interval || "1h",
            portfolioState: {},
            config: {
              ...(item.config || {}),
              skipRiskGuard: true,
            },
          },
        });
      }
    } catch (err) {
      logger.error("Futures Signals Cron failed", err);
      throw err;
    }
  }
);
