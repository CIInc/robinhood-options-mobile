import { onCall } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { getAuth } from "firebase-admin/auth";

const auth = getAuth();

// export const changeUserRoleRequest = onRequest(async (request, response) => {
//   logger.info(request.query, { structuredData: true });
//   const uid = request.query.uid as string;
//   const role = request.query.role as string;
//   auth.setCustomUserClaims(uid, {
//     role: role,
//   });
//   const user = await auth.getUser(uid);
//   const resp = uid + " " + user.displayName + " <" + user.email +
//     "> role: " + role + "";
//   logger.info(resp, { structuredData: true });

//   response.send(resp);
// });

export const changeUserRole = onCall(async (request) => {
  logger.info(request, { structuredData: true });
  if (request.auth == null ||
    request.auth?.uid == null ||
    request.auth?.token.role != "admin") {
    return "Not authorized.";
  }
  const uid = request.data.uid as string;
  const role = request.data.role as string;
  auth.setCustomUserClaims(uid, {
    role: role,
  });
  const user = await auth.getUser(uid);
  const resp = uid + " " + user.displayName + " <" + user.email +
    "> role: " + role + "";
  logger.info(resp, { structuredData: true });
  return resp;
});
