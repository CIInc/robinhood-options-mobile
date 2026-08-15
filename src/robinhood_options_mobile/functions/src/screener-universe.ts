import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { ALL_STOCKS } from "./stock-list";
import { fetchWithRetry } from "./utils";

type NumericMap = Record<string, unknown>;

export type ScreenerUniverseRecord = {
  symbol: string;
  name: string;
  exchange: string;
  sector: string;
  industry: string;
  marketCap?: number;
  peRatio?: number;
  pbRatio?: number;
  dividendYield?: number;
  averageVolume?: number;
  high52Weeks?: number;
  low52Weeks?: number;
  price?: number;
};

let dbInstance: FirebaseFirestore.Firestore | null = null;
const db = (): FirebaseFirestore.Firestore =>
  (dbInstance ??= getFirestore());
const TWELVE_DATA_URL = "https://api.twelvedata.com";
const MAX_SYMBOLS_PER_REQUEST = 500;
const ENRICHMENT_CONCURRENCY = 5;

/**
 * Returns the first finite numeric value in a list of provider fields.
 * @param {...unknown} values Candidate values.
 * @return {number|undefined} First finite number.
 */
function numberValue(...values: unknown[]): number | undefined {
  for (const value of values) {
    const number = typeof value === "number" ? value : Number(value);
    if (Number.isFinite(number)) return number;
  }
  return undefined;
}

/**
 * Safely treats an unknown provider value as a string-keyed object.
 * @param {unknown} value Provider value.
 * @return {NumericMap} Safe object representation.
 */
function objectValue(value: unknown): NumericMap {
  return value && typeof value === "object" ? value as NumericMap : {};
}

/**
 * Normalizes Twelve Data profile/statistics/quote payloads for Firestore.
 * @param {string} symbol Requested symbol.
 * @param {NumericMap} profile Twelve Data profile response.
 * @param {NumericMap} statistics Twelve Data statistics response.
 * @param {NumericMap} quote Twelve Data quote response.
 * @return {ScreenerUniverseRecord|null} Normalized record, if valid.
 */
export function normalizeScreenerRecord(
  symbol: string,
  profile: NumericMap,
  statistics: NumericMap,
  quote: NumericMap,
): ScreenerUniverseRecord | null {
  const normalizedSymbol = String(profile.symbol ?? quote.symbol ?? symbol)
    .trim().toUpperCase();
  if (!normalizedSymbol) return null;

  const valuation = objectValue(statistics.valuation_ratios);
  const dividends = objectValue(statistics.dividends_and_splits);
  const fiftyTwoWeek = objectValue(statistics.fifty_two_week);
  const record: ScreenerUniverseRecord = {
    symbol: normalizedSymbol,
    name: String(profile.name ?? quote.name ?? normalizedSymbol),
    exchange: String(profile.exchange ?? quote.exchange ?? ""),
    sector: String(profile.sector ?? ""),
    industry: String(profile.industry ?? ""),
  };

  const fields: Array<[keyof ScreenerUniverseRecord, number | undefined]> = [
    ["marketCap", numberValue(
      statistics.market_capitalization,
      statistics.market_cap,
    )],
    ["peRatio", numberValue(
      valuation.trailing_pe,
      valuation.pe_ratio,
      statistics.trailing_pe,
    )],
    ["pbRatio", numberValue(
      valuation.price_to_book,
      valuation.pb_ratio,
    )],
    ["dividendYield", numberValue(
      dividends.trailing_annual_dividend_yield,
      dividends.forward_annual_dividend_yield,
      statistics.dividend_yield,
    )],
    ["averageVolume", numberValue(
      statistics.average_volume,
      statistics.average_volume_30_days,
      quote.average_volume,
    )],
    ["high52Weeks", numberValue(
      fiftyTwoWeek.high,
      statistics.fifty_two_week_high,
      quote.fifty_two_week_high,
    )],
    ["low52Weeks", numberValue(
      fiftyTwoWeek.low,
      statistics.fifty_two_week_low,
      quote.fifty_two_week_low,
    )],
    ["price", numberValue(quote.close, quote.price)],
  ];
  for (const [key, value] of fields) {
    if (value !== undefined) {
      (record as unknown as Record<string, unknown>)[key] = value;
    }
  }
  return record;
}

/**
 * Fetches and validates one Twelve Data endpoint response.
 * @param {string} endpoint Twelve Data endpoint name.
 * @param {string} symbol Requested symbol.
 * @param {string} apiKey Twelve Data API key.
 * @return {Promise<NumericMap>} Provider response.
 */
async function fetchEndpoint(
  endpoint: string,
  symbol: string,
  apiKey: string,
): Promise<NumericMap> {
  const response = await fetchWithRetry(
    `${TWELVE_DATA_URL}/${endpoint}?symbol=${encodeURIComponent(symbol)}` +
    `&apikey=${apiKey}`,
  );
  if (!response.ok) {
    throw new Error(`${endpoint} returned HTTP ${response.status}`);
  }
  const data: unknown = await response.json();
  if (!data || typeof data !== "object" || "code" in data) {
    throw new Error(`${endpoint} returned no data`);
  }
  return data as NumericMap;
}

/**
 * Converts a normalized record into the app's Instrument document shape.
 * @param {ScreenerUniverseRecord} record Normalized symbol data.
 * @return {NumericMap} Firestore document data.
 */
function instrumentDocument(record: ScreenerUniverseRecord): NumericMap {
  const now = FieldValue.serverTimestamp();
  const fundamentalsObj: NumericMap = {
    description: "",
    instrument: "",
    ceo: "",
    headquarters_city: "",
    headquarters_state: "",
    sector: record.sector,
    industry: record.industry,
  };
  const numericFields: Array<[string, number | undefined]> = [
    ["market_cap", record.marketCap],
    ["pe_ratio", record.peRatio],
    ["pb_ratio", record.pbRatio],
    ["dividend_yield", record.dividendYield],
    ["average_volume", record.averageVolume],
    ["high_52_weeks", record.high52Weeks],
    ["low_52_weeks", record.low52Weeks],
  ];
  for (const [key, value] of numericFields) {
    if (value !== undefined) fundamentalsObj[key] = value;
  }

  const document: NumericMap = {
    id: record.symbol,
    url: "",
    quote: "",
    fundamentals: "",
    splits: "",
    state: "active",
    market: record.exchange,
    simple_name: record.name,
    name: record.name,
    tradeable: true,
    tradability: "tradable",
    symbol: record.symbol,
    bloomberg_unique: "",
    country: "US",
    type: "stock",
    rhs_tradability: "tradable",
    fractional_tradability: "tradable",
    is_spac: false,
    is_test: false,
    ipo_access_supports_dsp: false,
    date_created: now,
    date_updated: now,
    fundamentalsObj,
  };
  if (record.price !== undefined) {
    document.quoteObj = {
      ask_size: 0,
      bid_size: 0,
      last_trade_price: record.price,
      symbol: record.symbol,
      trading_halted: false,
      has_traded: true,
      last_trade_price_source: "twelve_data",
      instrument: "",
      instrument_id: record.symbol,
    };
  }
  return document;
}

/**
 * Fetches all data required to enrich one symbol.
 * @param {string} symbol Requested symbol.
 * @param {string} apiKey Twelve Data API key.
 * @return {Promise<ScreenerUniverseRecord>} Enriched symbol data.
 */
async function enrichSymbol(symbol: string, apiKey: string):
  Promise<ScreenerUniverseRecord> {
  const [profile, statistics, quote] = await Promise.all([
    fetchEndpoint("profile", symbol, apiKey),
    fetchEndpoint("statistics", symbol, apiKey),
    fetchEndpoint("quote", symbol, apiKey),
  ]);
  const record = normalizeScreenerRecord(symbol, profile, statistics, quote);
  if (!record) throw new Error("Unable to normalize response");
  return record;
}

/**
 * Enriches and persists a bounded set of symbols in Firestore.
 * @param {string[]} symbols Symbols to process.
 * @param {string} apiKey Twelve Data API key.
 * @return {Promise<object>} Processing summary.
 */
export async function seedScreenerUniverse(
  symbols: string[],
  apiKey: string,
): Promise<{processed: number; written: number; errors: string[]}> {
  const targetSymbols = [...new Set(symbols.map((symbol) =>
    String(symbol).trim().toUpperCase()).filter(Boolean))]
    .slice(0, MAX_SYMBOLS_PER_REQUEST);
  const errors: string[] = [];
  let written = 0;

  for (let index = 0; index < targetSymbols.length;
    index += ENRICHMENT_CONCURRENCY) {
    const chunk = targetSymbols.slice(index, index + ENRICHMENT_CONCURRENCY);
    const records = await Promise.all(chunk.map(async (symbol) => {
      try {
        return await enrichSymbol(symbol, apiKey);
      } catch (error) {
        errors.push(`${symbol}: ${String(error)}`);
        return null;
      }
    }));
    const batch = db().batch();
    for (const record of records) {
      if (record) {
        batch.set(db().doc(`instrument/${record.symbol}`),
          instrumentDocument(record), { merge: true });
        written++;
      }
    }
    await batch.commit();
  }

  return { processed: targetSymbols.length, written, errors };
}

/** Callable entry point for manually refreshing the screener universe. */
export const seedScreenerUniverseCall = onCall({
  secrets: ["TWELVE_DATA_API_KEY"],
  timeoutSeconds: 540,
  memory: "1GiB",
}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }
  const inputSymbols = request.data?.symbols;
  const symbols = Array.isArray(inputSymbols) ? inputSymbols : ALL_STOCKS;
  const apiKey = process.env.TWELVE_DATA_API_KEY;
  if (!apiKey) {
    throw new HttpsError(
      "failed-precondition", "Twelve Data is not configured.");
  }
  logger.info(`Seeding screener universe for ${symbols.length} symbols`);
  return seedScreenerUniverse(symbols, apiKey);
});
