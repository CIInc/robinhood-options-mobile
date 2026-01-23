import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

const db = admin.firestore();

/**
 * Verifies a subscription receipt with Apple or Google.
 *
 * Current implementation acts as a secure placeholder that updates Firestore.
 * To make this production-ready, integrate with `googleapis` (Android)
 * and verifyReceipt endpoint (iOS) using proper secrets.
 */
export const verifySubscription = onCall(async (request) => {
  // 1. Authentication Check
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "The user must be authenticated to verify a subscription."
    );
  }

  const uid = request.auth.uid;
  const { productId, source } = request.data;

  // 2. Validate Input
  if (!productId || !source) {
    throw new HttpsError("invalid-argument", "Missing productId or source.");
  }

  console.log(
    `[Subscription] Verifying receipt for User: ${uid} | ` +
    `Product: ${productId} | Source: ${source}`
  );

  // 3. Receipt Validation Logic (Placeholder)
  // In a real implementation:
  // - For Android: use googleapis to call purchases.subscriptions.get
  // - For iOS: call https://buy.itunes.apple.com/verifyReceipt
  // For now, we assume the client-side purchase was successful.
  const isValid = true;

  if (!isValid) {
    throw new HttpsError("permission-denied", "Invalid receipt.");
  }

  // 4. Update Firestore
  // Calculate expiry (simplification: 14 days from now)
  const now = admin.firestore.Timestamp.now();
  const expiryDate = admin.firestore.Timestamp.fromMillis(
    Date.now() + 14 * 24 * 60 * 60 * 1000
  );

  // If it's a trial, logic could be different,
  // but assuming standard flow here.
  // Set to 'active' instantly.
  await db.collection("user").doc(uid).set(
    {
      subscriptionStatus: "active",
      subscriptionExpiryDate: expiryDate,
      lastUpdated: now,
    },
    { merge: true }
  );

  return {
    success: true,
    status: "active",
    expiryDate: expiryDate.toMillis(),
  };
});
