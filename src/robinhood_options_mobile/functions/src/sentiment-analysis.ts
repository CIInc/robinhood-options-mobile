import { onCall } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

// Ensure Firebase Admin is initialized
if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();

interface SentimentData {
  symbol?: string;
  score: number;
  magnitude: number;
  source: string;
  summary: string;
  timestamp: string; // ISO string
  keywords: string[];
}

interface SentimentFeedItem {
  title: string;
  sourceName: string;
  url: string;
  sentimentScore: number; // 0-100
  publishedAt: string; // ISO string
  relatedSymbols: string[];
}

const MARKET_INDICES = ["SPY", "QQQ", "IWM", "DIA"];
const POPULAR_SYMBOLS = [
  "NVDA", "TSLA", "AAPL", "AMD", "MSFT",
  "AMZN", "GOOGL", "META", "NFLX", "COIN",
  "MSTR", "GME", "AMC", "PLTR", "SOFI",
];

export const getSentimentAnalysis = onCall(async (request) => {
  logger.info("getSentimentAnalysis called", { data: request.data });

  try {
    const [marketSentiment, trendingSentiment, feedItems] = await Promise.all([
      calculateMarketSentiment(),
      calculateTrendingSentiment(),
      generateSentimentFeed(),
    ]);

    return {
      market: marketSentiment,
      trending: trendingSentiment,
      feed: feedItems,
    };
  } catch (error) {
    logger.error("Error in getSentimentAnalysis", error);
    throw new Error(`Failed to calculate sentiment: ${error}`);
  }
});

/**
 * Calculates overall market sentiment score based on weighted index signals.
 * @return {Promise<SentimentData>} The calculated market sentiment data.
 */
async function calculateMarketSentiment(): Promise<SentimentData> {
  const weights: { [key: string]: number } = {
    "SPY": 0.35,
    "QQQ": 0.35,
    "DIA": 0.15,
    "IWM": 0.15,
  };

  let weightedScoreSum = 0;
  let totalWeight = 0;
  const reasons: string[] = [];

  // Fetch signals for market indices
  const snapshots = await Promise.all(
    MARKET_INDICES.map((s) => db.doc(`agentic_trading/signals_${s}`).get())
  );

  for (let i = 0; i < snapshots.length; i++) {
    const snap = snapshots[i];
    const symbol = MARKET_INDICES[i];

    if (snap.exists) {
      const data = snap.data();
      if (data && data.multiIndicatorResult) {
        const score = data.multiIndicatorResult.signalStrength || 50;
        const weight = weights[symbol] || 0.25;

        weightedScoreSum += score * weight;
        totalWeight += weight;

        if (data.reason) {
          // Simplify reason for summary (e.g. "SPY: Bullish Cross")
          const shortReason = data.reason.split(".")[0];
          reasons.push(`${symbol}: ${shortReason}`);
        }
      }
    }
  }

  // Default to Neutral (50) if no data
  const averageScore = totalWeight > 0 ? weightedScoreSum / totalWeight : 50;

  // Determine summary based on score
  let sentimentType = "Neutral";
  if (averageScore >= 60) sentimentType = "Bullish";
  if (averageScore >= 75) sentimentType = "Very Bullish";
  if (averageScore <= 40) sentimentType = "Bearish";
  if (averageScore <= 25) sentimentType = "Very Bearish";

  let summary = `Market sentiment is ${sentimentType}.`;

  if (reasons.length > 0) {
    // Combine top reasons
    summary += " Key drivers:\n" + reasons.slice(0, 4).join("\n") + "";
  } else {
    summary += " Awaiting sufficient signal data from indices.";
  }

  return {
    score: averageScore,
    // Reflects component coverage
    magnitude: totalWeight > 0 ? totalWeight : 0.5,
    source: "Alpha Agent",
    summary: summary,
    timestamp: new Date().toISOString(),
    keywords: ["Market", "Indices", ...MARKET_INDICES],
  };
}

/**
 * Identifies trending symbols based on signal strength deviation.
 * @return {Promise<SentimentData[]>} List of trending sentiment data.
 */
async function calculateTrendingSentiment(): Promise<SentimentData[]> {
  const sentimentList: SentimentData[] = [];

  // Fetch signals for popular symbols
  // We limit batch concurrency if list grows, but 15 is fine.
  const snapshots = await Promise.all(
    POPULAR_SYMBOLS.map((s) =>
      db.doc(`agentic_trading/signals_${s}`).get())
  );

  for (const snap of snapshots) {
    if (snap.exists) {
      const data = snap.data();
      if (data && data.multiIndicatorResult) {
        const score = data.multiIndicatorResult.signalStrength || 50;
        // Only include if slightly divergent from neutral to be interesting
        if (score > 55 || score < 45) {
          const detail = data.reason ?
            data.reason.split(".")[0] :
            "Technical divergence detected";

          sentimentList.push({
            symbol: data.symbol,
            score: score,
            magnitude: 0.8,
            source: "Alpha Agent",
            summary: detail,
            timestamp: data.timestamp ?
              new Date(data.timestamp).toISOString() :
              new Date().toISOString(),
            keywords: [data.symbol],
          });
        }
      }
    }
  }

  // Sort by "extremeness" (distance from 50)
  sentimentList.sort((a, b) => Math.abs(b.score - 50) - Math.abs(a.score - 50));

  return sentimentList.slice(0, 10);
}

/**
 * Generates a feed of sentiment-related items from strong signals.
 * @return {Promise<SentimentFeedItem[]>} List of sentiment feed items.
 */
async function generateSentimentFeed(): Promise<SentimentFeedItem[]> {
  const feedItems: SentimentFeedItem[] = [];

  // 1. Get Signals from Popular Symbols
  const snapshots = await Promise.all(
    POPULAR_SYMBOLS.map((s) =>
      db.doc(`agentic_trading/signals_${s}`).get())
  );

  for (const snap of snapshots) {
    if (snap.exists) {
      const data = snap.data();
      if (data && data.multiIndicatorResult) {
        const score = data.multiIndicatorResult.signalStrength || 50;

        // Only create feed items for strong signals
        if (score >= 65 || score <= 35) {
          const sentimentStr = score >= 50 ? "Bullish" : "Bearish";
          const intensity = (score >= 80 || score <= 20) ? "Strong " : "";

          // Construct a dynamic title based on available data
          let title = `${intensity}${sentimentStr} Signal for ${data.symbol}`;
          if (data.reason) {
            // Take first sentence of reason
            const mainReason = data.reason.split(".")[0];
            title = `${data.symbol}: ${mainReason}`;
          }

          feedItems.push({
            title: title,
            sourceName: "Alpha Agent",
            url: "", // Internal navigation could go here
            sentimentScore: score,
            publishedAt: data.timestamp ?
              new Date(data.timestamp).toISOString() :
              new Date().toISOString(),
            relatedSymbols: [data.symbol],
          });
        }
      }
    }
  }

  // Sort by date descending
  feedItems.sort((a, b) => new Date(b.publishedAt).getTime() -
    new Date(a.publishedAt).getTime());

  return feedItems;
}
