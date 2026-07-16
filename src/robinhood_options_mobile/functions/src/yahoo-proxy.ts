import { onRequest } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import fetch from "node-fetch";

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

    try {
      let result = await fetchFromYahoo(target);

      // Session may have expired; refresh once and retry.
      if (result.status === 401 || result.status === 403) {
        yahooCookie = null;
        yahooCrumb = null;
        result = await fetchFromYahoo(target);
      }

      res
        .status(result.status)
        .set("Content-Type", "application/json")
        .send(result.body);
    } catch (e) {
      logger.error(`Yahoo proxy fetch failed for ${target}`, e);
      res.status(502).json({ error: "Upstream Yahoo Finance request failed." });
    }
  },
);
