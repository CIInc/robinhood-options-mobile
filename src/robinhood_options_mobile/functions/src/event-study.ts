import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { getMarketData } from "./market-data";

export interface EventStudyPoint {
  offset: number;
  date: string;
  assetReturn: number;
  benchmarkReturn: number;
  abnormalReturn: number;
}

export interface RollingStatistic {
  date: string;
  volatility: number;
  beta: number;
  correlation: number;
  sampleSize: number;
}

export interface EventStudyResult {
  symbol: string;
  benchmark: string;
  eventType: string;
  eventDate: string;
  tradingEventDate: string;
  preWindow: number;
  postWindow: number;
  rollingWindow: number;
  sampleSize: number;
  eventDayAssetReturn: number;
  eventDayBenchmarkReturn: number;
  eventDayAbnormalReturn: number;
  cumulativeAssetReturn: number;
  cumulativeAbnormalReturn: number;
  points: EventStudyPoint[];
  rollingStats: RollingStatistic[];
}

interface PricePoint {
  timestamp: number;
  close: number;
}

/** Converts the market-data response into valid dated price points.
 * @param {any} data Market-data response.
 * @return {PricePoint[]} Valid dated price points.
 */
function toPricePoints(data: any): PricePoint[] {
  const timestamps = Array.isArray(data?.timestamps) ? data.timestamps : [];
  const closes = Array.isArray(data?.closes) ? data.closes : [];
  return timestamps.map((timestamp: unknown, index: number) => ({
    timestamp: Number(timestamp),
    close: Number(closes[index]),
  })).filter((point: PricePoint) =>
    Number.isFinite(point.timestamp) && Number.isFinite(point.close) &&
    point.close > 0,
  );
}

/** Returns the percentage change from a baseline price.
 * @param {number} base Baseline price.
 * @param {number} value Ending price.
 * @return {number} Percentage change as a decimal.
 */
function returnFrom(base: number, value: number): number {
  return base === 0 ? 0 : value / base - 1;
}

/** Calculates rolling annualized risk statistics from aligned daily closes.
 * @param {PricePoint[]} asset Asset price points.
 * @param {PricePoint[]} benchmark Benchmark price points.
 * @param {number} window Number of daily returns in each rolling sample.
 * @return {RollingStatistic[]} Rolling risk statistics.
 */
function calculateRollingStats(
  asset: PricePoint[],
  benchmark: PricePoint[],
  window: number,
): RollingStatistic[] {
  const benchmarkByTimestamp = new Map(
    benchmark.map((point) => [point.timestamp, point.close]),
  );
  const pairedReturns: Array<{
    timestamp: number;
    assetReturn: number;
    benchmarkReturn: number;
  }> = [];
  for (let index = 1; index < asset.length; index++) {
    const previousBenchmark = benchmarkByTimestamp.get(
      asset[index - 1].timestamp,
    );
    const currentBenchmark = benchmarkByTimestamp.get(asset[index].timestamp);
    if (previousBenchmark == null || currentBenchmark == null ||
      asset[index - 1].close === 0 || previousBenchmark === 0) {
      continue;
    }
    pairedReturns.push({
      timestamp: asset[index].timestamp,
      assetReturn: asset[index].close / asset[index - 1].close - 1,
      benchmarkReturn: currentBenchmark / previousBenchmark - 1,
    });
  }

  const stats: RollingStatistic[] = [];
  for (let end = window - 1; end < pairedReturns.length; end++) {
    const sample = pairedReturns.slice(end - window + 1, end + 1);
    const assetReturns = sample.map((point) => point.assetReturn);
    const benchmarkReturns = sample.map((point) => point.benchmarkReturn);
    const assetMean = assetReturns.reduce((sum, value) => sum + value, 0) /
      assetReturns.length;
    const benchmarkMean = benchmarkReturns.reduce(
      (sum, value) => sum + value, 0,
    ) / benchmarkReturns.length;
    let covariance = 0;
    let assetVariance = 0;
    let benchmarkVariance = 0;
    for (let index = 0; index < sample.length; index++) {
      const assetDiff = assetReturns[index] - assetMean;
      const benchmarkDiff = benchmarkReturns[index] - benchmarkMean;
      covariance += assetDiff * benchmarkDiff;
      assetVariance += assetDiff * assetDiff;
      benchmarkVariance += benchmarkDiff * benchmarkDiff;
    }
    const denominator = Math.max(1, sample.length - 1);
    covariance /= denominator;
    assetVariance /= denominator;
    benchmarkVariance /= denominator;
    const benchmarkVolatility = Math.sqrt(benchmarkVariance);
    const assetVolatility = Math.sqrt(assetVariance);
    stats.push({
      date: new Date(pairedReturns[end].timestamp * 1000)
        .toISOString().split("T")[0],
      volatility: assetVolatility * Math.sqrt(252),
      beta: benchmarkVariance === 0 ? 0 : covariance / benchmarkVariance,
      correlation: assetVolatility === 0 || benchmarkVolatility === 0 ?
        0 : covariance / (assetVolatility * benchmarkVolatility),
      sampleSize: sample.length,
    });
  }
  return stats;
}

/** Calculates asset, benchmark, and abnormal returns around an event.
 * @param {string} symbol Asset symbol.
 * @param {string} benchmark Benchmark symbol.
 * @param {string} eventType Event classification.
 * @param {string} eventDate Requested event date.
 * @param {number} preWindow Trading days before the event.
 * @param {number} postWindow Trading days after the event.
 * @param {number} rollingWindow Daily returns in each rolling sample.
 * @param {any} assetData Asset market data.
 * @param {any} benchmarkData Benchmark market data.
 * @return {EventStudyResult} Event-study result.
 */
export function calculateEventStudy(
  symbol: string,
  benchmark: string,
  eventType: string,
  eventDate: string,
  preWindow: number,
  postWindow: number,
  rollingWindow: number,
  assetData: any,
  benchmarkData: any,
): EventStudyResult {
  const asset = toPricePoints(assetData);
  const benchmarkPrices = toPricePoints(benchmarkData);
  if (asset.length === 0 || benchmarkPrices.length === 0) {
    throw new Error("Historical prices are unavailable for this event.");
  }

  const requestedTimestamp =
    new Date(`${eventDate}T00:00:00Z`).getTime() / 1000;
  let eventIndex = asset.findIndex(
    (point) => point.timestamp >= requestedTimestamp,
  );
  if (eventIndex < 0) eventIndex = asset.length - 1;
  const eventTimestamp = asset[eventIndex].timestamp;
  const benchmarkEventIndex = benchmarkPrices.reduce(
    (best, point, index) => Math.abs(point.timestamp - eventTimestamp) <
      Math.abs(benchmarkPrices[best].timestamp - eventTimestamp) ? index : best,
    0,
  );
  const firstIndex = Math.max(0, eventIndex - preWindow);
  const lastIndex = Math.min(asset.length - 1, eventIndex + postWindow);
  const assetBase = asset[firstIndex].close;
  const benchmarkBaseIndex = Math.min(
    benchmarkPrices.length - 1,
    Math.max(0, benchmarkEventIndex + firstIndex - eventIndex),
  );
  const benchmarkBase = benchmarkPrices[benchmarkBaseIndex].close;
  const points: EventStudyPoint[] = [];

  for (let index = firstIndex; index <= lastIndex; index++) {
    const offset = index - eventIndex;
    const benchmarkIndex = Math.min(
      benchmarkPrices.length - 1,
      Math.max(0, benchmarkEventIndex + offset),
    );
    const assetReturn = returnFrom(assetBase, asset[index].close);
    const benchmarkReturn = returnFrom(
      benchmarkBase,
      benchmarkPrices[benchmarkIndex].close,
    );
    points.push({
      offset,
      date: new Date(asset[index].timestamp * 1000)
        .toISOString().split("T")[0],
      assetReturn,
      benchmarkReturn,
      abnormalReturn: assetReturn - benchmarkReturn,
    });
  }

  const eventPoint = points.find((point) => point.offset === 0) ?? points[0];
  const finalPoint = points[points.length - 1];
  const priorPoint = points.find((point) => point.offset === -1);
  return {
    symbol,
    benchmark,
    eventType,
    eventDate,
    tradingEventDate: eventPoint.date,
    preWindow,
    postWindow,
    sampleSize: points.length,
    eventDayAssetReturn: priorPoint == null ? eventPoint.assetReturn :
      eventPoint.assetReturn - priorPoint.assetReturn,
    eventDayBenchmarkReturn: priorPoint == null ? eventPoint.benchmarkReturn :
      eventPoint.benchmarkReturn - priorPoint.benchmarkReturn,
    eventDayAbnormalReturn: priorPoint == null ? eventPoint.abnormalReturn :
      eventPoint.abnormalReturn - priorPoint.abnormalReturn,
    cumulativeAssetReturn: finalPoint.assetReturn,
    cumulativeAbnormalReturn: finalPoint.abnormalReturn,
    points,
    rollingWindow,
    rollingStats: calculateRollingStats(asset, benchmarkPrices, rollingWindow),
  };
}

export const analyzeEventStudy = onCall({
  secrets: ["TWELVE_DATA_API_KEY"],
  timeoutSeconds: 120,
}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be logged in.");
  }
  const data = request.data as Record<string, unknown>;
  const symbol = String(data.symbol ?? "").trim().toUpperCase();
  const benchmark = String(data.benchmark ?? "SPY").trim().toUpperCase();
  const eventType = String(data.eventType ?? "Other");
  const eventDate = String(data.eventDate ?? "");
  const preWindow = Number(data.preWindow ?? 10);
  const postWindow = Number(data.postWindow ?? 10);
  const rollingWindow = Number(data.rollingWindow ?? 30);
  if (!symbol || !/^\d{4}-\d{2}-\d{2}$/.test(eventDate) ||
    !Number.isInteger(preWindow) || !Number.isInteger(postWindow) ||
    !Number.isInteger(rollingWindow) || preWindow < 1 || postWindow < 1 ||
    rollingWindow < 5 || rollingWindow > 120 || preWindow > 120 ||
    postWindow > 120) {
    throw new HttpsError(
      "invalid-argument",
      "Provide a symbol, event date, and windows from 1 to 120 trading days.",
    );
  }

  const assetData = await getMarketData(symbol, 50, 200, "1d", "10y");
  const benchmarkData = await getMarketData(benchmark, 50, 200, "1d", "10y");
  try {
    const result = calculateEventStudy(
      symbol, benchmark, eventType, eventDate, preWindow, postWindow,
      rollingWindow,
      assetData, benchmarkData,
    );
    logger.info("Event study completed", { symbol, eventType, eventDate });
    return result;
  } catch (error) {
    throw new HttpsError("failed-precondition", (error as Error).message);
  }
});
