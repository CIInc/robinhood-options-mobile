import { onRequest } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import fetch from "node-fetch";
import { createHash } from "crypto";
import { getFirestore, Timestamp } from "firebase-admin/firestore";

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
  { cors: true, memory: "256MiB", timeoutSeconds: 30 },
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
