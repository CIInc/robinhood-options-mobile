import { onCall } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { getMessaging } from "firebase-admin/messaging";

const messaging = getMessaging();

export const sendEachForMulticast = onCall(async (request) => {
  logger.info(request, { structuredData: true });
  if (request.auth == null ||
    request.auth?.uid == null ||
    request.auth?.token.role != "admin") {
    return "Not authorized.";
  }
  const title = request.data.title as string;
  const body = request.data.body as string;
  const imageUrl = request.data.imageUrl as string;
  const tokens = request.data.tokens as string[];
  const route = request.data.route as string;
  // const golferId = request.data.golferId as string;
  return await messaging.sendEachForMulticast({
    tokens: tokens,
    data: {
      route: route,
      // golferId: golferId
    },
    notification: {
      title: title,
      body: body,
      imageUrl: imageUrl,
    },
  });
});
