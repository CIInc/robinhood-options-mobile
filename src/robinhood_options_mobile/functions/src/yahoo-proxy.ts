import { onRequest } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import fetch from "node-fetch";
import { createHash } from "crypto";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { fetchFromTwelveData, getQuotes } from "./market-data";

/**
 * CORS proxy for Yahoo Finance.
 *
 * Yahoo's API endpoints don't send Access-Control-Allow-Origin headers, so
 * browser clients (Flutter web) can't call them directly. This function
 * forwards whitelisted Yahoo Finance requests server-side — including the
 * cookie/crumb session Yahoo requires — and returns the JSON with CORS
 * enabled.
 */

const ALLOWED_HOSTS = new Set([
  "query1.finance.yahoo.com",
  "query2.finance.yahoo.com",
]);

/**
 * Validates a proxy target: must be an https URL on a whitelisted Yahoo
 * Finance host. Exported for unit testing.
 * @param {string} raw The requested target URL.
 * @return {boolean} Whether the URL may be proxied.
 */
export function isAllowedYahooUrl(raw: string): boolean {
  try {
    const url = new URL(raw);
    return url.protocol === "https:" && ALLOWED_HOSTS.has(url.hostname);
  } catch (_) {
    return false;
  }
}

/**
 * Cache lifetime per endpoint. Yahoo throttles datacenter IPs hard, so the
 * proxy is cache-first: many clients collapse into at most one upstream
 * request per unique URL per TTL window. Exported for unit testing.
 * @param {string} raw The target Yahoo URL.
 * @return {number} TTL in seconds.
 */
export function cacheTtlSeconds(raw: string): number {
  let path: string;
  try {
    path = new URL(raw).pathname;
  } catch (_) {
    return 300;
  }
  // Order matters: quoteSummary must match before the quote prefix.
  if (path.includes("/finance/quoteSummary/")) return 86400; // fundamentals
  if (path.includes("/finance/quote")) return 60; // live-ish quotes
  if (path.includes("/finance/chart/")) return 300; // intraday charts
  if (path.includes("/finance/options/")) return 300; // option chains
  if (path.includes("/finance/screener")) return 600; // movers/screeners
  if (path.includes("/finance/search")) return 86400; // symbol lookup
  return 300;
}

/**
 * Stable Firestore document id for a target URL. Exported for testing.
 * @param {string} raw The target Yahoo URL.
 * @return {string} Hex digest usable as a document id.
 */
export function cacheKey(raw: string): string {
  return createHash("sha256").update(raw).digest("hex");
}

interface CachedResponse {
  body: string;
  status: number;
  fetchedAtMs: number;
}

// L1: per-instance memory cache (fast path, dies with the instance).
const memoryCache = new Map<string, CachedResponse>();
const MEMORY_CACHE_MAX_ENTRIES = 500;
// L2: Firestore (shared across instances and users).
const CACHE_COLLECTION = "yahoo_proxy_cache";
// Firestore documents cap at ~1MB; skip persisting oversized bodies.
const MAX_CACHED_BODY_BYTES = 900_000;

const isFresh = (entry: CachedResponse, ttlSeconds: number): boolean =>
  Date.now() - entry.fetchedAtMs < ttlSeconds * 1000;

/**
 * Serves translatable endpoints from Twelve Data (the app's contracted
 * provider) instead of Yahoo, whose datacenter-IP throttling makes direct
 * fetches from Cloud Functions unreliable. The response is translated into
 * the Yahoo shape the client already parses. Returns null for endpoints
 * without a Twelve Data equivalent (screeners, quoteSummary, options) so
 * the caller falls back to the cached Yahoo path.
 * @param {string} target The Yahoo URL being proxied.
 * @return {Promise<CachedResponse | null>} Translated response or null.
 */
async function fetchViaTwelveData(
  target: string,
): Promise<CachedResponse | null> {
  const apiKey = process.env.TWELVE_DATA_API_KEY;
  if (!apiKey) return null;
  const url = new URL(target);
  const path = url.pathname;

  // Symbol search -> /symbol_search
  if (path.includes("/finance/search")) {
    const q = url.searchParams.get("q");
    if (!q) return null;
    const resp = await fetch(
      "https://api.twelvedata.com/symbol_search?symbol=" +
      `${encodeURIComponent(q)}&outputsize=10&apikey=${apiKey}`);
    if (!resp.ok) return null;
    const data: any = await resp.json();
    if (!Array.isArray(data?.data)) return null;
    const quotes = data.data.map((item: any) => ({
      symbol: item.symbol,
      longname: item.instrument_name,
      shortname: item.instrument_name,
      typeDisp: item.instrument_type,
      exchDisp: item.exchange,
      quoteType: item.instrument_type === "ETF" ? "ETF" : "EQUITY",
    }));
    return {
      body: JSON.stringify({ quotes }),
      status: 200,
      fetchedAtMs: Date.now(),
    };
  }

  // Quotes -> /quote (via getQuotes: Twelve Data first, Fidelity fallback)
  if (path.includes("/finance/quote") &&
    !path.includes("/finance/quoteSummary")) {
    const symbolsParam = url.searchParams.get("symbols");
    if (!symbolsParam) return null;
    const symbols = symbolsParam.split(",").filter((s) => s.length > 0);
    const quoteMap = await getQuotes(symbols);
    const result = symbols
      .map((symbol) => {
        const q = quoteMap?.[symbol];
        if (!q) return null;
        const last = Number(q.last ?? q.LAST_PRICE);
        if (!isFinite(last) || last === 0) return null;
        const change = Number(q.change ?? q.TODAYS_CHANGE) || 0;
        return {
          symbol,
          shortName: q.name,
          regularMarketPrice: last,
          regularMarketPreviousClose:
            Number(q.PREVIOUS_CLOSE) || last - change,
          regularMarketVolume: Number(q.volume ?? q.VOLUME) || 0,
          ask: 0,
          bid: 0,
          askSize: 0,
          bidSize: 0,
        };
      })
      .filter((q) => q != null);
    if (result.length === 0) return null;
    return {
      body: JSON.stringify({ quoteResponse: { result } }),
      status: 200,
      fetchedAtMs: Date.now(),
    };
  }

  // Charts -> /time_series (already translated to the Yahoo result shape)
  if (path.includes("/finance/chart/")) {
    const symbol = decodeURIComponent(
      path.split("/finance/chart/")[1]?.split("/")[0] ?? "");
    if (!symbol) return null;
    const interval = url.searchParams.get("interval") ?? "1d";
    const range = url.searchParams.get("range") ?? "1y";
    const result = await fetchFromTwelveData(symbol, interval, range);
    if (!result) return null;
    return {
      body: JSON.stringify({ chart: { result: [result], error: null } }),
      status: 200,
      fetchedAtMs: Date.now(),
    };
  }

  return null;
}

/**
 * Reads the shared Firestore cache entry for [target], if any.
 * @param {string} target The Yahoo URL.
 * @return {Promise<CachedResponse | null>} Entry or null.
 */
async function readFirestoreCache(
  target: string,
): Promise<CachedResponse | null> {
  try {
    const doc = await getFirestore()
      .collection(CACHE_COLLECTION)
      .doc(cacheKey(target))
      .get();
    const data = doc.data();
    if (!doc.exists || !data?.body) return null;
    const fetchedAt = data.fetchedAt as Timestamp | undefined;
    return {
      body: data.body,
      status: Number(data.status) || 200,
      fetchedAtMs: fetchedAt ? fetchedAt.toMillis() : 0,
    };
  } catch (e) {
    logger.warn(`Cache read failed for ${target}`, e);
    return null;
  }
}

/**
 * Persists a successful upstream response to both cache layers.
 * @param {string} target The Yahoo URL.
 * @param {CachedResponse} entry The response to cache.
 */
async function writeCaches(
  target: string,
  entry: CachedResponse,
): Promise<void> {
  if (memoryCache.size >= MEMORY_CACHE_MAX_ENTRIES) memoryCache.clear();
  memoryCache.set(target, entry);
  if (Buffer.byteLength(entry.body, "utf8") > MAX_CACHED_BODY_BYTES) return;
  try {
    await getFirestore()
      .collection(CACHE_COLLECTION)
      .doc(cacheKey(target))
      .set({
        url: target,
        body: entry.body,
        status: entry.status,
        fetchedAt: Timestamp.fromMillis(entry.fetchedAtMs),
      });
  } catch (e) {
    logger.warn(`Cache write failed for ${target}`, e);
  }
}

const YAHOO_HEADERS: Record<string, string> = {
  "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " +
    "AppleWebKit/537.36 (KHTML, like Gecko) " +
    "Chrome/133.0.0.0 Safari/537.36",
  "Accept": "*/*",
  "Referer": "https://finance.yahoo.com/",
  "Origin": "https://finance.yahoo.com",
};

let yahooCookie: string | null = null;
let yahooCrumb: string | null = null;

/**
 * Fetches (and caches per instance) the Yahoo session cookie and crumb that
 * authenticated endpoints (e.g. v7/finance/quote) require.
 */
async function ensureYahooSession(): Promise<void> {
  if (yahooCookie && yahooCrumb) return;
  try {
    let cookieResponse = await fetch("https://finance.yahoo.com", {
      headers: YAHOO_HEADERS,
    });
    let setCookie = cookieResponse.headers.get("set-cookie");
    if (!setCookie) {
      cookieResponse = await fetch("https://fc.yahoo.com", {
        headers: YAHOO_HEADERS,
      });
      setCookie = cookieResponse.headers.get("set-cookie");
    }
    if (!setCookie) throw new Error("No set-cookie header from Yahoo");
    yahooCookie = setCookie.split(";")[0];

    const crumbResponse = await fetch(
      "https://query2.finance.yahoo.com/v1/test/getcrumb",
      { headers: { ...YAHOO_HEADERS, "Cookie": yahooCookie } },
    );
    if (crumbResponse.ok) {
      yahooCrumb = await crumbResponse.text();
    }
  } catch (e) {
    logger.warn("Failed to establish Yahoo session", e);
  }
}

/**
 * Performs the proxied fetch, appending the crumb when available.
 * @param {string} target The validated Yahoo URL.
 * @return {Promise<{status: number, body: string}>} Upstream result.
 */
async function fetchFromYahoo(
  target: string,
): Promise<{ status: number; body: string }> {
  await ensureYahooSession();

  let url = target;
  if (yahooCrumb && !url.includes("crumb=")) {
    url += (url.includes("?") ? "&" : "?") +
      `crumb=${encodeURIComponent(yahooCrumb)}`;
  }
  const headers: Record<string, string> = { ...YAHOO_HEADERS };
  if (yahooCookie) headers["Cookie"] = yahooCookie;

  const response = await fetch(url, { headers });
  return { status: response.status, body: await response.text() };
}

export const yahooProxy = onRequest(
  {
    cors: true,
    memory: "256MiB",
    timeoutSeconds: 30,
    secrets: ["TWELVE_DATA_API_KEY"],
  },
  async (req, res) => {
    const target = req.query.url;
    if (typeof target !== "string" || !isAllowedYahooUrl(target)) {
      res.status(400).json({
        error: "Query parameter 'url' must be an https Yahoo Finance " +
          "(query1/query2.finance.yahoo.com) URL.",
      });
      return;
    }

    const ttl = cacheTtlSeconds(target);
    const send = (entry: CachedResponse, cacheState: string) => {
      res
        .status(entry.status)
        .set("Content-Type", "application/json")
        .set("X-Proxy-Cache", cacheState)
        .send(entry.body);
    };

    // L1: per-instance memory.
    const memoryHit = memoryCache.get(target);
    if (memoryHit && isFresh(memoryHit, ttl)) {
      send(memoryHit, "memory");
      return;
    }

    // L2: shared Firestore cache.
    const firestoreHit = await readFirestoreCache(target);
    if (firestoreHit && isFresh(firestoreHit, ttl)) {
      memoryCache.set(target, firestoreHit);
      send(firestoreHit, "firestore");
      return;
    }

    const stale = memoryHit ?? firestoreHit;

    // Prefer Twelve Data for endpoints it can serve — Yahoo throttles
    // datacenter IPs, so direct fetches from Cloud Functions 429 easily.
    try {
      const translated = await fetchViaTwelveData(target);
      if (translated) {
        await writeCaches(target, translated);
        send(translated, "miss-twelvedata");
        return;
      }
    } catch (e) {
      logger.warn(`Twelve Data translation failed for ${target}`, e);
    }

    try {
      let result = await fetchFromYahoo(target);

      // Session may have expired; refresh once and retry.
      if (result.status === 401 || result.status === 403) {
        yahooCookie = null;
        yahooCrumb = null;
        result = await fetchFromYahoo(target);
      }

      if (result.status === 200) {
        const entry: CachedResponse = {
          body: result.body,
          status: 200,
          fetchedAtMs: Date.now(),
        };
        await writeCaches(target, entry);
        send(entry, "miss");
        return;
      }

      // Rate limited or upstream error: serve the last good copy if any.
      if (stale) {
        logger.warn(
          `Yahoo returned ${result.status} for ${target}; serving stale.`);
        send(stale, "stale");
        return;
      }
      res
        .status(result.status)
        .set("Content-Type", "application/json")
        .send(result.body);
    } catch (e) {
      logger.error(`Yahoo proxy fetch failed for ${target}`, e);
      if (stale) {
        send(stale, "stale");
        return;
      }
      res.status(502).json({ error: "Upstream Yahoo Finance request failed." });
    }
  },
);
