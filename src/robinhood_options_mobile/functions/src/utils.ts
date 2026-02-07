import fetch, { RequestInit, Response } from "node-fetch";
import * as logger from "firebase-functions/logger";

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
  options?: RequestInit,
  maxRetries = 3,
  baseDelay = 2000
): Promise<Response> {
  let attempt = 0;
  while (attempt <= maxRetries) {
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

        logger.warn(`⚠️ Rate limited (429) on ${url}. ` +
          `Retrying in ${Math.round(delay)}ms ` +
          `(Attempt ${attempt + 1}/${maxRetries})`);
        await new Promise((resolve) => setTimeout(resolve, delay));
        attempt++;
        continue;
      }

      // Also retry on 5xx server errors
      if (response.status >= 500 && response.status < 600) {
        const delay = baseDelay * Math.pow(2, attempt) + Math.random() * 1000;
        logger.warn(`⚠️ Server error (${response.status}) on ${url}. ` +
          `Retrying in ${Math.round(delay)}ms ` +
          `(Attempt ${attempt + 1}/${maxRetries})`);
        await new Promise((resolve) => setTimeout(resolve, delay));
        attempt++;
        continue;
      }

      return response;
    } catch (error) {
      // Network errors (DNS, timeout, etc.)
      if (attempt === maxRetries) throw error;

      const delay = baseDelay * Math.pow(2, attempt) + Math.random() * 1000;
      logger.warn(`⚠️ Network error on ${url}: ${error}. ` +
        `Retrying in ${Math.round(delay)}ms ` +
        `(Attempt ${attempt + 1}/${maxRetries})`);
      await new Promise((resolve) => setTimeout(resolve, delay));
      attempt++;
    }
  }
  throw new Error(`Failed to fetch ${url} after ${maxRetries} retries`);
}
