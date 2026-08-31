import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();

export interface NewsArticle {
  id: string;
  title: string;
  summary: string;
  source: string;
  url: string;
  publishedAt: string;
  sentimentScore: number; // 0 to 100 (50 = neutral)
  sentimentLabel: "Bullish" | "Neutral" | "Bearish";
  impact: "High" | "Medium" | "Low";
  symbols: string[];
}

export interface NewsIntelligence {
  symbol: string;
  overallSentiment: number; // 0-100
  sentimentLabel:
  | "Very Bullish"
  | "Bullish"
  | "Neutral"
  | "Bearish"
  | "Very Bearish";
  headlineSummary: string;
  keyTakeaways: string[];
  bullishCatalysts: string[];
  bearishCatalysts: string[];
  impactRating: "High" | "Medium" | "Low";
  sentimentScoreChange24h: number;
  articles: NewsArticle[];
  updatedAt: string;
}

const BULLISH_KEYWORDS = [
  "beat", "beats", "surpassed", "record", "growth", "upgrade", "upgraded",
  "outperform", "buy", "bullish", "profit", "profitable", "revenue jump",
  "guidance raise", "raised guidance", "partnership", "expansion",
  "dividend increase", "buyback", "fda approval", "approved", "breakthrough",
  "rally", "surges", "soars", "demand surge", "tailwind", "all-time high",
  "strong earnings", "strong quarter",
];

const BEARISH_KEYWORDS = [
  "miss", "misses", "missed", "drop", "drops", "slump", "downgrade",
  "downgraded", "underperform", "sell", "bearish", "loss", "loss widens",
  "revenue fall", "guidance cut", "lowered guidance", "cut guidance",
  "lawsuit", "sued", "investigation", "sec probe", "probe", "regulatory",
  "headwind", "tariff", "inflation", "supply chain delay", "recession",
  "plunges", "tumbles", "debt", "default", "dilution",
];

const HIGH_IMPACT_KEYWORDS = [
  "earnings", "revenue", "guidance", "fda", "merger", "acquisition", "buyout",
  "investigation", "probe", "lawsuit", "antitrust", "dividend", "restructure",
  "ceo",
];

/**
 * Score a single headline/summary text for sentiment and impact.
 * @param {string} text - Title or summary of article.
 * @return {{ score: number, label: string, impact: string }}
 */
export function scoreArticleText(text: string): {
  score: number;
  label: "Bullish" | "Neutral" | "Bearish";
  impact: "High" | "Medium" | "Low";
} {
  const lower = text.toLowerCase();
  let bullCount = 0;
  let bearCount = 0;
  let isHighImpact = false;

  for (const word of BULLISH_KEYWORDS) {
    if (lower.includes(word)) bullCount++;
  }
  for (const word of BEARISH_KEYWORDS) {
    if (lower.includes(word)) bearCount++;
  }
  for (const word of HIGH_IMPACT_KEYWORDS) {
    if (lower.includes(word)) {
      isHighImpact = true;
      break;
    }
  }

  let score = 50;
  if (bullCount > bearCount) {
    score = Math.min(100, 55 + (bullCount - bearCount) * 12);
  } else if (bearCount > bullCount) {
    score = Math.max(0, 45 - (bearCount - bullCount) * 12);
  }

  let label: "Bullish" | "Neutral" | "Bearish" = "Neutral";
  if (score >= 60) label = "Bullish";
  else if (score <= 40) label = "Bearish";

  let impact: "High" | "Medium" | "Low" = "Low";
  if (isHighImpact || Math.abs(score - 50) >= 25) {
    impact = "High";
  } else if (bullCount > 0 || bearCount > 0 || Math.abs(score - 50) >= 10) {
    impact = "Medium";
  }

  return { score, label, impact };
}

/**
 * Analyzes news items for a given symbol and returns NewsIntelligence.
 * @param {any[]} rawArticles - Raw news articles.
 * @param {string} symbol - Ticker symbol.
 * @return {NewsIntelligence} Analyzed intelligence payload.
 */
export function analyzeNewsArticles(
  rawArticles: any[],
  symbol: string
): NewsIntelligence {
  const articles: NewsArticle[] = [];
  const bullishCatalysts: string[] = [];
  const bearishCatalysts: string[] = [];
  const takeaways: string[] = [];

  let totalScore = 0;
  let highImpactCount = 0;

  for (let i = 0; i < rawArticles.length; i++) {
    const raw = rawArticles[i];
    const title = raw.title || raw.headline || "Market Update";
    const summary = raw.summary || raw.description || raw.preview_text || "";
    const source = raw.source || raw.publisher || "Financial News";
    const url = raw.url || raw.link || "";
    const publishedAt =
      raw.published_at ||
      raw.publishedAt ||
      raw.datetime ||
      new Date().toISOString();
    const id = raw.id || `${symbol}-news-${i}-${Date.now()}`;

    const textToEvaluate = `${title} ${summary}`;
    const { score, label, impact } = scoreArticleText(textToEvaluate);

    if (impact === "High") highImpactCount++;
    totalScore += score;

    if (label === "Bullish" && bullishCatalysts.length < 4) {
      bullishCatalysts.push(title);
    } else if (label === "Bearish" && bearishCatalysts.length < 4) {
      bearishCatalysts.push(title);
    }

    articles.push({
      id: String(id),
      title,
      summary,
      source,
      url,
      publishedAt,
      sentimentScore: score,
      sentimentLabel: label,
      impact,
      symbols: raw.symbols || [symbol],
    });
  }

  const overallSentiment =
    articles.length > 0 ? Math.round(totalScore / articles.length) : 50;

  let sentimentLabel:
    | "Very Bullish"
    | "Bullish"
    | "Neutral"
    | "Bearish"
    | "Very Bearish" = "Neutral";
  if (overallSentiment >= 75) sentimentLabel = "Very Bullish";
  else if (overallSentiment >= 60) sentimentLabel = "Bullish";
  else if (overallSentiment <= 25) sentimentLabel = "Very Bearish";
  else if (overallSentiment <= 40) sentimentLabel = "Bearish";

  let impactRating: "High" | "Medium" | "Low" = "Low";
  if (highImpactCount >= 2 || Math.abs(overallSentiment - 50) >= 20) {
    impactRating = "High";
  } else if (highImpactCount >= 1 || articles.length >= 3) {
    impactRating = "Medium";
  }

  // Generate headline summary
  let headlineSummary = "";
  if (articles.length === 0) {
    headlineSummary = `No recent news catalysts reported for ${symbol}. ` +
      "Market sentiment remains baseline neutral.";
    takeaways.push("Trading volume and technical factors are primary drivers.");
  } else {
    headlineSummary = `${symbol} news sentiment is ` +
      `${sentimentLabel.toLowerCase()} (${overallSentiment}/100) ` +
      `driven by ${articles.length} recent news events.`;

    if (bullishCatalysts.length > 0) {
      takeaways.push(`Key positive driver: ${bullishCatalysts[0]}`);
    }
    if (bearishCatalysts.length > 0) {
      takeaways.push(`Key risk factor: ${bearishCatalysts[0]}`);
    }
    if (articles.length === 0) {
      takeaways.push("No recent catalysts; trading on technicals.");
    }
  }

  return {
    symbol: symbol.toUpperCase(),
    overallSentiment,
    sentimentLabel,
    headlineSummary,
    keyTakeaways: takeaways,
    bullishCatalysts,
    bearishCatalysts,
    impactRating,
    sentimentScoreChange24h: 0,
    articles,
    updatedAt: new Date().toISOString(),
  };
}

/**
 * Callable Firebase Function to retrieve news intelligence for a symbol.
 */
export const getNewsIntelligence = onCall({ cors: true }, async (request) => {
  const data = request.data || {};
  const symbol = (data.symbol || "").toUpperCase();
  const providedArticles = data.articles || [];

  if (!symbol) {
    throw new HttpsError("invalid-argument", "Symbol must be provided.");
  }

  logger.info(`getNewsIntelligence requested for ${symbol}`, {
    articlesCount: providedArticles.length,
  });

  try {
    // If articles passed directly, analyze them
    if (Array.isArray(providedArticles) && providedArticles.length > 0) {
      return analyzeNewsArticles(providedArticles, symbol);
    }

    // Check cached news intelligence in Firestore if recent (< 15 min)
    const cachedDoc = await db.collection("instrument_news").doc(symbol).get();
    if (cachedDoc.exists && data.refresh !== true) {
      const cachedData = cachedDoc.data() as NewsIntelligence;
      const updatedAtMs = new Date(cachedData.updatedAt || 0).getTime();
      if (Date.now() - updatedAtMs < 15 * 60 * 1000) {
        return cachedData;
      }
    }

    // Fallback: analyze whatever news items exist or baseline
    const intelligence = analyzeNewsArticles([], symbol);
    await db
      .collection("instrument_news")
      .doc(symbol)
      .set(intelligence, { merge: true });
    return intelligence;
  } catch (error: any) {
    logger.error(`Error in getNewsIntelligence for ${symbol}:`, error);
    throw new HttpsError(
      "internal",
      `Failed to get news intelligence: ${error.message}`
    );
  }
});

/**
 * Callable Firebase Function for multiple watchlist symbols.
 */
export const getWatchlistNewsIntelligence = onCall(
  { cors: true },
  async (request) => {
    const data = request.data || {};
    const symbols = (data.symbols || []) as string[];

    if (!Array.isArray(symbols) || symbols.length === 0) {
      throw new HttpsError(
        "invalid-argument",
        "Symbols array must be provided."
      );
    }

    logger.info(
      `getWatchlistNewsIntelligence for ${symbols.length} symbols`
    );

    const results: Record<string, NewsIntelligence> = {};

    try {
      const limitedSymbols = symbols.slice(0, 25).map((s) => s.toUpperCase());
      const snapshots = await Promise.all(
        limitedSymbols.map((s) =>
          db.collection("instrument_news").doc(s).get()
        )
      );

      for (let i = 0; i < limitedSymbols.length; i++) {
        const sym = limitedSymbols[i];
        const snap = snapshots[i];
        if (snap.exists) {
          results[sym] = snap.data() as NewsIntelligence;
        } else {
          results[sym] = analyzeNewsArticles([], sym);
        }
      }

      return results;
    } catch (error: any) {
      logger.error("Error in getWatchlistNewsIntelligence:", error);
      throw new HttpsError(
        "internal",
        `Failed to get watchlist news: ${error.message}`
      );
    }
  }
);
