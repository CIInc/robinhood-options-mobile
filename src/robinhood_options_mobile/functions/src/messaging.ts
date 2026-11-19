import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { getMessaging } from "firebase-admin/messaging";

const messaging = getMessaging();

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
  const tokens = request.data?.tokens;
  // SECURITY: FCM multicast limits batches to 500 tokens per request
  if (
    !Array.isArray(tokens) ||
    tokens.length === 0 ||
    tokens.length > 500 ||
    tokens.some((t) => typeof t !== "string" || t.trim().length === 0)
  ) {
    throw new HttpsError(
      "invalid-argument",
      "tokens must be a non-empty array of up to 500 valid strings."
    );
  }

  const title = typeof request.data?.title === "string" ?
    request.data.title : "";
  const body = typeof request.data?.body === "string" ?
    request.data.body : "";
  const imageUrl = typeof request.data?.imageUrl === "string" ?
    request.data.imageUrl : undefined;
  const route = typeof request.data?.route === "string" ?
    request.data.route : "";

  try {
    return await messaging.sendEachForMulticast({
      tokens,
      data: { route },
      notification: { title, body, imageUrl },
    });
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.error("Failed to send multicast notifications", { error });
    throw new HttpsError("internal", "Failed to deliver multicast.");
  }
});
