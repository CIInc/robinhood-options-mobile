import { onSchedule } from "firebase-functions/v2/scheduler";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import { getMarketData } from "./market-data";

const db = getFirestore();

/**
 * Daily snapshot of paper trading equity for all users.
 * Runs at 4:30 PM ET (after market close).
 */
export const updatePaperHistoricalsCron = onSchedule({
  schedule: "30 16 * * *",
  timeZone: "America/New_York",
  memory: "512MiB",
  timeoutSeconds: 300,
}, async () => {
  logger.info("Starting updatePaperHistoricalsCron...");

  const snapshot = await db.collectionGroup("paper_account").get();

  if (snapshot.empty) {
    logger.info("No paper accounts found.");
    return;
  }

  logger.info(`Found ${snapshot.docs.length} paper account documents.`);

  const uniqueSymbols = new Set<string>();
  for (const doc of snapshot.docs) {
    const data = doc.data();
    if (data.positions) {
      for (const pos of data.positions) {
        if (pos.instrumentObj?.symbol) {
          uniqueSymbols.add(pos.instrumentObj.symbol);
        }
      }
    }
  }

  logger.info(`Fetching market data for ${uniqueSymbols.size} unique symbols.`);

  // Pre-fetch market prices for all unique symbols to be efficient
  const symbolPrices: Record<string, number> = {};
  for (const symbol of uniqueSymbols) {
    try {
      // Small periods as we only need currentPrice
      const marketData = await getMarketData(symbol, 5, 10, "1d");
      if (marketData.currentPrice) {
        symbolPrices[symbol] = marketData.currentPrice;
      }
    } catch (err) {
      logger.warn(`Failed to fetch price for ${symbol}`, err);
    }
  }

  let processedCount = 0;
  const now = new Date();
  const dateStr = now.toISOString().split("T")[0];

  for (const doc of snapshot.docs) {
    // Expected path: user/{userId}/paper_account/main
    const userId = doc.ref.parent.parent?.id;
    if (!userId || doc.id !== "main") continue;

    try {
      const data = doc.data();
      const cashBalance = data.cashBalance || 0;
      const initialCapital = data.initialCapital || 100000.0;
      let positionsValue = 0;

      if (data.positions) {
        for (const pos of data.positions) {
          const symbol = pos.instrumentObj?.symbol;
          const price = symbolPrices[symbol] || pos.average_buy_price || 0;
          positionsValue += (pos.quantity || 0) * price;
        }
      }

      if (data.optionPositions) {
        for (const pos of data.optionPositions) {
          // Fallback chain for price: adjustedMarkPrice -> average_open_price
          const mktData = pos.optionInstrument?.optionMarketData;
          const price = mktData?.adjustedMarkPrice ||
            pos.average_open_price || 0;
          positionsValue += (pos.quantity || 0) * price * 100;
        }
      }

      const totalEquity = cashBalance + positionsValue;

      // Try to get previous snapshot to calculate net_return and open_equity
      const historyCol = db.collection("user").doc(userId)
        .collection("paper_equity_history");
      const prevSnap = await historyCol.orderBy("begins_at", "desc")
        .limit(1).get();

      let openEquity = totalEquity;
      let netReturn = 0;

      if (!prevSnap.empty) {
        const prevData = prevSnap.docs[0].data();
        openEquity = prevData.close_equity || totalEquity;
        netReturn = totalEquity - openEquity;
      }

      // Save daily snapshot
      await historyCol.doc(dateStr).set({
        close_equity: totalEquity,
        open_equity: openEquity,
        adjusted_close_equity: totalEquity,
        adjusted_open_equity: openEquity,
        begins_at: FieldValue.serverTimestamp(),
        net_return: netReturn,
        total_return: totalEquity - initialCapital,
        total_return_percentage: (totalEquity - initialCapital) /
          initialCapital,
        session: "regular",
      });

      processedCount++;
    } catch (err) {
      logger.error(`Error processing paper account for user ${userId}`, err);
    }
  }

  logger.info(`Successfully processed ${processedCount} paper accounts.`);
});
