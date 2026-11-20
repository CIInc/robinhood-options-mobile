import fetch, { RequestInit, Response } from "node-fetch";
import * as logger from "firebase-functions/logger";

/**
 * Checks whether a query parameter name commonly carries a credential.
 * @param {string} name The query parameter name.
 * @return {boolean} Whether the parameter value should be redacted.
 */
function isSensitiveQueryParameter(name: string): boolean {
  const normalized = name.toLowerCase().replace(/[_-]/g, "");
  return normalized === "key" || normalized.includes("apikey") ||
    normalized.includes("token") || normalized.includes("secret") ||
    normalized.includes("password") ||
    normalized.includes("authorization") ||
    normalized.includes("signature") || normalized === "crumb";
}

/**
 * Redacts secret-like query parameters before URLs are written to logs.
 * @param {string} url The URL to sanitize.
 * @return {string} The sanitized URL.
 */
export function redactSensitiveUrl(url: string): string {
  try {
    const parsedUrl = new URL(url);
    const sensitiveParameters = [...parsedUrl.searchParams.keys()]
      .filter(isSensitiveQueryParameter);
    for (const parameter of sensitiveParameters) {
      parsedUrl.searchParams.set(parameter, "[REDACTED]");
    }
    return parsedUrl.toString();
  } catch {
    return url.replace(
      /([?&])([^=&\s]+)=([^&\s]*)/g,
      (match, separator: string, name: string) =>
        isSensitiveQueryParameter(name) ?
          `${separator}${name}=[REDACTED]` : match
    );
  }
}

/**
 * Fetches a URL with retry logic for 429 (Too Many Requests) errors.
 * @param {string} url The URL to fetch.
 * @param {RequestInit} options The fetch options.
 * @param {number} maxRetries The maximum number of retries.
 * @param {number} baseDelay The base delay in milliseconds for exponential
 * backoff.
 * @return {Promise<Response>} The fetch response.
 */
export async function fetchWithRetry(
  url: string,
  options: RequestInit = {},
  maxRetries = 2,
  baseDelay = 2000
): Promise<Response> {
  const safeUrl = redactSensitiveUrl(url);

  // Set default headers if not present
  if (!options.headers) {
    options.headers = {};
  }
  const headers = options.headers as Record<string, string>;
  if (!headers["User-Agent"]) {
    headers["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " +
      "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36";
  }
  if (!headers["Accept"]) {
    headers["Accept"] = "*/*";
  }

  let attempt = 0;
  while (attempt < maxRetries) {
    try {
      const response = await fetch(url, options);
      if (response.status === 429) {
        const retryAfter = response.headers.get("retry-after");
        let delay = baseDelay * Math.pow(2, attempt);
        if (retryAfter) {
          const parsed = parseInt(retryAfter, 10);
          if (!isNaN(parsed)) {
            delay = parsed * 1000;
          }
        }

        // Add some jitter to prevent synchronized retries
        delay = delay + Math.random() * 1000;

        logger.warn(`⚠️ Rate limited (429) on ${safeUrl}. ` +
          `Retrying in ${Math.round(delay)}ms ` +
          `(Attempt ${attempt + 1}/${maxRetries})`);
        await new Promise((resolve) => setTimeout(resolve, delay));
        attempt++;
        continue;
      }

      // Also retry on 5xx server errors
      if (response.status >= 500 && response.status < 600) {
        const delay = baseDelay * Math.pow(2, attempt) + Math.random() * 1000;
        logger.warn(`⚠️ Server error (${response.status}) on ${safeUrl}. ` +
          `Retrying in ${Math.round(delay)}ms ` +
          `(Attempt ${attempt + 1}/${maxRetries})`);
        await new Promise((resolve) => setTimeout(resolve, delay));
        attempt++;
        continue;
      }

      return response;
    } catch (error) {
      // Network errors (DNS, timeout, etc.)
      if (attempt === maxRetries) {
        throw new Error(`Network request failed for ${safeUrl}`);
      }

      const delay = baseDelay * Math.pow(2, attempt) + Math.random() * 1000;
      const errorType = error instanceof Error ? error.name : "Unknown error";
      logger.warn(`⚠️ Network error on ${safeUrl}: ${errorType}. ` +
        `Retrying in ${Math.round(delay)}ms ` +
        `(Attempt ${attempt + 1}/${maxRetries})`);
      await new Promise((resolve) => setTimeout(resolve, delay));
      attempt++;
    }
  }
  throw new Error(`Failed to fetch ${safeUrl} after ${maxRetries} retries`);
}
