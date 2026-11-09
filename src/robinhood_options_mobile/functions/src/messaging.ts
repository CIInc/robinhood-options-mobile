import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { getMessaging } from "firebase-admin/messaging";

const messaging = getMessaging();

const MAX_TOKENS_PER_MULTICAST = 500;
const MAX_TITLE_LENGTH = 200;
const MAX_BODY_LENGTH = 2000;
const MAX_URL_OR_ROUTE_LENGTH = 2048;
const MAX_TOKEN_LENGTH = 4096;

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

  const data = request.data || {};
  const { title, body, imageUrl, tokens, route } = data;

  // SECURITY: Validate tokens array bounds and items
  if (
    !Array.isArray(tokens) ||
    tokens.length === 0 ||
    tokens.length > MAX_TOKENS_PER_MULTICAST ||
    !tokens.every(
      (t) => typeof t === "string" && t.length > 0 &&
        t.length <= MAX_TOKEN_LENGTH
    )
  ) {
    throw new HttpsError(
      "invalid-argument",
      "tokens must be a non-empty array of up to 500 valid strings."
    );
  }

  // SECURITY: Validate notification title and body
  if (
    typeof title !== "string" ||
    title.trim().length === 0 ||
    title.length > MAX_TITLE_LENGTH
  ) {
    throw new HttpsError(
      "invalid-argument",
      `title must be a non-empty string under ${MAX_TITLE_LENGTH} characters.`
    );
  }

  if (
    typeof body !== "string" ||
    body.trim().length === 0 ||
    body.length > MAX_BODY_LENGTH
  ) {
    throw new HttpsError(
      "invalid-argument",
      `body must be a non-empty string under ${MAX_BODY_LENGTH} characters.`
    );
  }

  // SECURITY: Validate optional imageUrl and route parameters
  if (
    imageUrl !== undefined &&
    imageUrl !== null &&
    (typeof imageUrl !== "string" ||
      imageUrl.length > MAX_URL_OR_ROUTE_LENGTH)
  ) {
    throw new HttpsError(
      "invalid-argument",
      `imageUrl must be a string under ${MAX_URL_OR_ROUTE_LENGTH} characters.`
    );
  }

  if (
    route !== undefined &&
    route !== null &&
    (typeof route !== "string" ||
      route.length > MAX_URL_OR_ROUTE_LENGTH)
  ) {
    throw new HttpsError(
      "invalid-argument",
      `route must be a string under ${MAX_URL_OR_ROUTE_LENGTH} characters.`
    );
  }

  try {
    return await messaging.sendEachForMulticast({
      tokens: tokens,
      data: {
        ...(typeof route === "string" ? { route } : {}),
      },
      notification: {
        title: title,
        body: body,
        ...(typeof imageUrl === "string" ? { imageUrl } : {}),
      },
    });
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }
    logger.error("Error sending multicast notification", { error });
    throw new HttpsError(
      "internal",
      "An unexpected error occurred while sending multicast notifications."
    );
  }
});
