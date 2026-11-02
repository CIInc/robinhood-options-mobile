import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { getAuth } from "firebase-admin/auth";

const auth = getAuth();
const VALID_ROLES = new Set(["admin", "user", "beta"]);

export const changeUserRole = onCall(async (request) => {
  logger.info(request, { structuredData: true });
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError(
      "unauthenticated",
      "Authentication is required to change user roles."
    );
  }
  if (request.auth.token?.role !== "admin") {
    throw new HttpsError(
      "permission-denied",
      "Only admin users can change user roles."
    );
  }
  const uid = request.data?.uid;
  const role = request.data?.role;
  if (!uid || typeof uid !== "string" || !role || typeof role !== "string") {
    throw new HttpsError(
      "invalid-argument",
      "Parameters 'uid' and 'role' are required and must be strings."
    );
  }
  if (!VALID_ROLES.has(role)) {
    throw new HttpsError(
      "invalid-argument",
      `Invalid role '${role}'. Allowed roles: admin, user, beta.`
    );
  }
  await auth.setCustomUserClaims(uid, {
    role: role,
  });
  const user = await auth.getUser(uid);
  const displayName = user.displayName ?? "";
  const email = user.email ?? "";
  const resp = `${uid} ${displayName} <${email}> role: ${role}`;
  logger.info(resp, { structuredData: true });
  return resp;
});
