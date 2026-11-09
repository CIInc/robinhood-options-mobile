import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { getMessaging } from "firebase-admin/messaging";

const messaging = getMessaging();
const MAX_MULTICAST_TOKENS = 500;
const MAX_TITLE_LENGTH = 200;
const MAX_BODY_LENGTH = 2000;
const MAX_URL_LENGTH = 2048;

export const sendEachForMulticast = onCall(async (request) => {
  logger.info(request, { structuredData: true });
  // SECURITY: Require authentication
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError(
      "unauthenticated",
      "Authentication is required to send notifications."
    );
  }
  // SECURITY: Require admin role for multicast messaging
  if (request.auth.token?.role !== "admin") {
    throw new HttpsError(
      "permission-denied",
      "Admin permissions are required to send notifications."
    );
  }

  const { title, body, imageUrl, tokens, route } = request.data ?? {};

  // SECURITY: Validate multicast tokens array bounds and types
  if (!Array.isArray(tokens) || tokens.length === 0 ||
      tokens.length > MAX_MULTICAST_TOKENS) {
    throw new HttpsError(
      "invalid-argument",
      `'tokens' must be a non-empty array up to ${MAX_MULTICAST_TOKENS} items.`
    );
  }
  for (const token of tokens) {
    if (typeof token !== "string" || token.trim().length === 0) {
      throw new HttpsError(
        "invalid-argument",
        "All elements in 'tokens' must be non-empty strings."
      );
    }
  }

  // SECURITY: Validate message payload bounds and types
  if (typeof title !== "string" || title.trim().length === 0 ||
      title.length > MAX_TITLE_LENGTH) {
    throw new HttpsError(
      "invalid-argument",
      `'title' must be a non-empty string up to ${MAX_TITLE_LENGTH} chars.`
    );
  }
  if (typeof body !== "string" || body.trim().length === 0 ||
      body.length > MAX_BODY_LENGTH) {
    throw new HttpsError(
      "invalid-argument",
      `'body' must be a non-empty string up to ${MAX_BODY_LENGTH} chars.`
    );
  }
  if (imageUrl !== undefined &&
      (typeof imageUrl !== "string" || imageUrl.length > MAX_URL_LENGTH)) {
    throw new HttpsError(
      "invalid-argument",
      `'imageUrl' must be a string up to ${MAX_URL_LENGTH} chars.`
    );
  }
  if (route !== undefined &&
      (typeof route !== "string" || route.length > MAX_URL_LENGTH)) {
    throw new HttpsError(
      "invalid-argument",
      `'route' must be a string up to ${MAX_URL_LENGTH} chars.`
    );
  }

  try {
    return await messaging.sendEachForMulticast({
      tokens,
      data: {
        ...(route ? { route } : {}),
      },
      notification: {
        title,
        body,
        ...(imageUrl ? { imageUrl } : {}),
      },
    });
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.error("Failed to send multicast notifications", error);
    throw new HttpsError(
      "internal",
      "Failed to deliver multicast notifications."
    );
  }
});
