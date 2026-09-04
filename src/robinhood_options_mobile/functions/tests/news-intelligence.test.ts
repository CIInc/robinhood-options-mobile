import { describe, it, expect } from "@jest/globals";
import {
  scoreArticleText,
  analyzeNewsArticles,
} from "../src/news-intelligence";

describe("News Intelligence Analyzer", () => {
  it("scores bullish breaking news correctly", () => {
    const text =
      "NVDA beats Q2 earnings estimates with record AI revenue, " +
      "raises guidance";
    const result = scoreArticleText(text);

    expect(result.score).toBeGreaterThanOrEqual(60);
    expect(result.label).toBe("Bullish");
    expect(result.impact).toBe("High");
  });

  it("scores bearish news headlines with appropriate impact", () => {
    const text =
      "TSLA drops as delivery numbers miss expectations amid regulatory probe";
    const result = scoreArticleText(text);

    expect(result.score).toBeLessThanOrEqual(40);
    expect(result.label).toBe("Bearish");
    expect(result.impact).toBe("High");
  });

  it("analyzes multi-article news feed for symbol intelligence", () => {
    const rawArticles = [
      {
        title: "Apple reports record iPhone revenue and announces buyback",
        summary: "Q3 earnings surpassed analyst projections.",
        source: "Bloomberg",
        published_at: new Date().toISOString(),
      },
      {
        title: "Apple expands AI partnership with OpenAI",
        summary: "New features coming to Siri and iOS.",
        source: "Reuters",
        published_at: new Date().toISOString(),
      },
    ];

    const intelligence = analyzeNewsArticles(rawArticles, "AAPL");

    expect(intelligence.symbol).toBe("AAPL");
    expect(intelligence.overallSentiment).toBeGreaterThanOrEqual(60);
    expect(intelligence.sentimentLabel).toMatch(/Bullish/);
    expect(intelligence.bullishCatalysts.length).toBeGreaterThan(0);
    expect(intelligence.articles.length).toBe(2);
    expect(intelligence.eventImpactPrediction.direction).toBe("Bullish");
    expect(intelligence.eventImpactPrediction.expectedMovePercent)
      .toBeGreaterThan(0);
    expect(intelligence.eventImpactPrediction.drivers).toHaveLength(2);
  });

  it("returns a low-confidence neutral baseline without news", () => {
    const intelligence = analyzeNewsArticles([], "AAPL");

    expect(intelligence.eventImpactPrediction).toEqual({
      direction: "Neutral",
      expectedMovePercent: 0,
      confidence: 15,
      horizon: "1-2 weeks",
      drivers: [],
    });
  });
});
