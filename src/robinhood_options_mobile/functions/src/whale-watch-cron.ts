import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { fetchFromYahoo } from "./yahoo-proxy";
import {
  WhaleWatchTransaction,
  InstitutionalAccumulation,
} from "./whale-watch-models";
import { rankInstitutionalActivity } from "./whale-watch-utils";

// Ensure Firebase Admin is initialized
if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();

/**
 * Fetches data with Firestore caching in the 'yahoo_data' collection.
 * Matches the logic in the mobile client's YahooService.
 * @param {string} url The URL to fetch data from.
 * @param {string} cacheKey The unique key to identify the cached document.
 * @param {number} ttlMs Time To Live in milliseconds. Default is 7 days.
 * @return {Promise<any>} The fetched or cached JSON data.
 */
async function fetchCachedYahooData(
  url: string,
  cacheKey: string,
  ttlMs: number = 7 * 24 * 60 * 60 * 1000
): Promise<any> {
  const docRef = db.collection("yahoo_data").doc(cacheKey);

  try {
    const docSnapshot = await docRef.get();
    if (docSnapshot.exists) {
      const data = docSnapshot.data();
      if (data?.lastUpdated && data.data) {
        const lastUpdated = (
          data.lastUpdated as admin.firestore.Timestamp
        ).toDate();
        if (Date.now() - lastUpdated.getTime() < ttlMs) {
          return data.data;
        }
      }
    }
  } catch (error) {
    logger.warn(`Error reading cache for ${cacheKey}:`, error);
  }

  try {
    let response = await fetchFromYahoo(url);
    if (response.status === 401 || response.status === 403) {
      response = await fetchFromYahoo(url);
    }
    if (response.status !== 200) {
      throw new Error(`Yahoo returned HTTP ${response.status}`);
    }
    const responseJson = JSON.parse(response.body);
    if (responseJson) {
      await docRef.set({
        data: responseJson,
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      });
      return responseJson;
    }
  } catch (error) {
    logger.error(`Error fetching/caching data for ${cacheKey}:`, error);
  }
  return null;
}

/**
 * Fetches insider transactions for a specific symbol from Yahoo Finance API.
 * Uses Firestore 'yahoo_data' collection for caching.
 * @param {string} symbol The ticker symbol to fetch data for.
 * @return {Promise<WhaleWatchTransaction[]>} List of transactions.
 */
async function fetchInsiderTransactions(
  symbol: string
): Promise<WhaleWatchTransaction[]> {
  try {
    const url = `https://query2.finance.yahoo.com/v10/finance/quoteSummary/${symbol}?modules=insiderTransactions`;
    const cacheKey = `insiderTransactions_${symbol}`;
    const data = await fetchCachedYahooData(url, cacheKey);
    const transactions =
      data?.quoteSummary?.result?.[0]?.insiderTransactions?.transactions || [];

    return transactions.map((t: any) => {
      const text = (t.transactionText || "").toLowerCase();
      const isBuy = text.includes("purchase") || text.includes("buy");
      const isSale = text.includes("sale");
      const isOptionExercise =
        text.includes("option") || text.includes("exercise");

      return {
        symbol,
        filerName: t.filerName || "Unknown",
        filerRelation: t.filerRelation || "Unknown",
        transactionText: t.transactionText || "",
        shares: t.shares?.raw || 0,
        value: t.value?.raw || 0,
        date: t.startDate?.fmt || new Date().toISOString(),
        ownership: t.ownership || "",
        isBuy,
        isSale,
        isOptionExercise,
      };
    });
  } catch (error) {
    logger.error(`Error processing insider transactions for ${symbol}:`, error);
    return [];
  }
}

/**
 * Fetches institutional ownership for a specific symbol from Yahoo Finance API.
 * Uses Firestore 'yahoo_data' collection for caching.
 * @param {string} symbol The ticker symbol to fetch data for.
 * @return {Promise<InstitutionalAccumulation[]>} List of accumulations.
 */
async function fetchInstitutionalOwnership(
  symbol: string
): Promise<InstitutionalAccumulation[]> {
  try {
    const url = `https://query2.finance.yahoo.com/v10/finance/quoteSummary/${symbol}?modules=institutionOwnership`;
    const cacheKey = `institutionOwnership_${symbol}`;
    const data = await fetchCachedYahooData(url, cacheKey);
    const ownership =
      data?.quoteSummary?.result?.[0]?.institutionOwnership?.ownershipList ||
      [];

    return ownership.map((o: any) => ({
      symbol,
      institutionName: o.organization || "Unknown",
      sharesHeld: o.position?.raw || 0,
      changeInShares: o.positionChange?.raw || 0,
      percentChange: o.pctChange?.raw || 0,
      positionValue: o.value?.raw || 0,
      reportDate: o.reportDate?.fmt || new Date().toISOString(),
    }));
  } catch (error) {
    const msg = `Error fetching institutional ownership for ${symbol}:`;
    logger.error(msg, error);
    return [];
  }
}

/**
 * Scheduled task to aggregate market-wide "Whale" activity.
 * Runs daily to collect major moves by insiders and institutions.
 */
export const aggregateWhaleWatch = onSchedule(
  { schedule: "0 8 * * *" }, // Run daily at 8:00 AM
  async (event) => {
    logger.info("Starting aggregateWhaleWatch", { event });

    // 1. Fetch dynamic list of most popular/trending symbols
    // We fetch this from our own 'instrument' cache and Yahoo's trending lists
    let dynamicSymbols: string[] = [];
    try {
      const trendingUrl = "https://query2.finance.yahoo.com/v1/finance/trending/US";
      // 1 hour TTL
      const trendingData = await fetchCachedYahooData(
        trendingUrl,
        "trending_US",
        3600000
      );
      const trendingTickers =
        (trendingData?.finance?.result?.[0]?.quotes?.map((q: any) =>
          String(q.symbol)
        ) as string[]) || [];
      dynamicSymbols = [...new Set(trendingTickers)];
    } catch (error) {
      logger.warn(
        "Failed to fetch dynamic symbols, falling back to static list",
        error
      );
    }

    // Combine with a list of high-impact symbols to monitor (e.g., S&P 100)
    const staticSymbols = [
      "AAPL",
      "MSFT",
      "GOOGL",
      "AMZN",
      "META",
      "TSLA",
      "NVDA",
      "BRK-B",
      "JPM",
      "V",
      "AMD",
      "NFLX",
      "PLTR",
      "SQ",
      "COIN",
      "MARA",
      "RIOT",
      "TSM",
      "ARM",
      "AVGO",
      "COST",
      "WMT",
      "DIS",
      "BA",
      "GS",
      "MS",
      "SNOW",
      "U",
      "AI",
    ];

    // Merge and deduplicate, prioritizing dynamic symbols
    const combinedSymbols = [...new Set([...dynamicSymbols, ...staticSymbols])];
    const symbolsToMonitor = combinedSymbols.slice(0, 100);

    const allTransactions: WhaleWatchTransaction[] = [];
    const allAccumulations: InstitutionalAccumulation[] = [];

    // 2. Fetch data for each symbol
    // We process in small batches to avoid hitting rate limits or timeouts
    // Batch size reduced and delay increased to mitigate 429 errors from Yahoo
    const batchSize = 3;
    for (let i = 0; i < symbolsToMonitor.length; i += batchSize) {
      const batch = symbolsToMonitor.slice(i, i + batchSize);
      const tasks = batch.map(async (symbol) => {
        const [transactions, ownership] = await Promise.all([
          fetchInsiderTransactions(symbol),
          fetchInstitutionalOwnership(symbol),
        ]);
        allTransactions.push(...transactions);
        allAccumulations.push(...ownership);
      });
      await Promise.all(tasks);
      // Increased delay between batches with slight jitter (1500-2500ms)
      const delay = 1500 + Math.random() * 1000;
      await new Promise((resolve) => setTimeout(resolve, delay));
    }

    // 3. Aggregate "Market-Wide" Sentiment
    const largeTransactions = allTransactions
      .filter((t) => (t.isBuy || t.isSale) && t.value > 100000) // $100k+ moves
      .sort((a, b) => b.value - a.value);

    const buyTotal = allTransactions
      .filter((t) => t.isBuy)
      .reduce((sum, t) => sum + t.value, 0);
    const sellTotal = allTransactions
      .filter((t) => t.isSale)
      .reduce((sum, t) => sum + t.value, 0);
    const buyCount = allTransactions.filter((t) => t.isBuy).length;
    const sellCount = allTransactions.filter((t) => t.isSale).length;

    // 4. Compare current institutional holdings with the previous snapshot.
    const holdingsRef = db.doc(
      "market_intelligence/whale_watch_institutional_holdings"
    );
    let previousHoldings: Record<string, number> = {};
    try {
      const holdingsSnapshot = await holdingsRef.get();
      previousHoldings = holdingsSnapshot.data()?.holdings || {};
    } catch (error) {
      logger.warn("Failed to read institutional holdings snapshot", error);
    }
    const institutionalRanking = rankInstitutionalActivity(
      allAccumulations,
      previousHoldings
    );
    const topAccumulated = institutionalRanking.topSymbols;

    // 5. Save to Firestore
    const aggregateData = {
      buyTotal,
      sellTotal,
      buyCount,
      sellCount,
      topAccumulatedSymbols: topAccumulated,
      institutionalRankingMode: institutionalRanking.mode,
      recentLargeTransactions: largeTransactions.slice(0, 50),
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    };

    try {
      const docPath = "market_intelligence/whale_watch_aggregate";
      const batch = db.batch();
      batch.set(db.doc(docPath), aggregateData);
      batch.set(holdingsRef, {
        holdings: institutionalRanking.currentHoldings,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
      await batch.commit();
      logger.info("Successfully updated Whale Watch aggregate data", {
        topSymbol: topAccumulated[0]?.symbol,
        institutionalRankingMode: institutionalRanking.mode,
        buyTotal,
      });
    } catch (error) {
      logger.error("Failed to save Whale Watch aggregate:", error);
    }
  }
);
