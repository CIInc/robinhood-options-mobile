import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret, defineString } from "firebase-functions/params";
import { google } from "googleapis";
import fetch from "node-fetch";
import * as admin from "firebase-admin";

const appleSharedSecret = defineSecret("APPLE_SHARED_SECRET");
const googlePlayServiceAccountJson = defineSecret(
  "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON"
);
const googlePlayPackageName = defineString("GOOGLE_PLAY_PACKAGE_NAME", {
  default: "com.cidevelop.robinhood_options_mobile",
});

const supportedProductId = "trade_signals_monthly";

/** Apple receipt verification response. */
interface AppleReceiptResponse {
  status: number;
  latest_receipt_info?: Array<{
    product_id?: string;
    expires_date_ms?: string;
    transaction_id?: string;
  }>;
  receipt?: {
    in_app?: Array<{
      product_id?: string;
      expires_date_ms?: string;
      transaction_id?: string;
    }>;
  };
}

/** Creates the public error used for invalid or expired receipts.
 * @return {HttpsError} The normalized invalid-receipt error.
 */
function invalidReceipt(): HttpsError {
  return new HttpsError("permission-denied", "Invalid subscription receipt.");
}

/** Verifies an App Store receipt and returns its latest active transaction.
 * @param {string} receiptData The App Store receipt payload.
 * @param {string} productId The product identifier to match.
 * @return {Object} The latest active transaction and expiry.
 */
async function verifyAppleReceipt(
  receiptData: string,
  productId: string
): Promise<{ expiryMillis: number; transactionId?: string }> {
  const requestBody = JSON.stringify({
    "receipt-data": receiptData,
    "password": appleSharedSecret.value(),
    "exclude-old-transactions": false,
  });

  const verify = async (url: string) =>
    fetch(url, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: requestBody,
    });

  let response = await verify("https://buy.itunes.apple.com/verifyReceipt");
  let data = (await response.json()) as AppleReceiptResponse;
  if (data.status === 21007) {
    response = await verify("https://sandbox.itunes.apple.com/verifyReceipt");
    data = (await response.json()) as AppleReceiptResponse;
  }
  if (!response.ok || data.status !== 0) {
    throw invalidReceipt();
  }

  const transactions = [
    ...(data.latest_receipt_info ?? []),
    ...(data.receipt?.in_app ?? []),
  ].filter((transaction) => transaction.product_id === productId);
  const activeTransaction = transactions
    .map((transaction) => ({
      expiryMillis: Number(transaction.expires_date_ms),
      transactionId: transaction.transaction_id,
    }))
    .filter((transaction) => Number.isFinite(transaction.expiryMillis))
    .sort((left, right) => right.expiryMillis - left.expiryMillis)[0];

  if (!activeTransaction || activeTransaction.expiryMillis <= Date.now()) {
    throw invalidReceipt();
  }
  return activeTransaction;
}

/** Verifies a Google Play subscription token and returns its expiry.
 * @param {string} purchaseToken The token returned by Google Play.
 * @param {string} productId The product identifier to match.
 * @return {Object} The active subscription transaction and expiry.
 */
async function verifyGoogleReceipt(
  purchaseToken: string,
  productId: string
): Promise<{ expiryMillis: number; transactionId?: string }> {
  let credentials: Record<string, unknown>;
  try {
    credentials = JSON.parse(googlePlayServiceAccountJson.value()) as Record<
      string,
      unknown
    >;
  } catch {
    throw new HttpsError(
      "failed-precondition",
      "Google Play service credentials are invalid."
    );
  }

  const auth = new google.auth.GoogleAuth({
    credentials,
    scopes: ["https://www.googleapis.com/auth/androidpublisher"],
  });
  const publisher = google.androidpublisher({ version: "v3", auth });
  let result;
  try {
    result = await publisher.purchases.subscriptionsv2.get({
      packageName: googlePlayPackageName.value(),
      token: purchaseToken,
    });
  } catch {
    throw invalidReceipt();
  }

  const lineItem = result.data.lineItems?.find((item) =>
    item.productId === productId
  );
  const expiryMillis = lineItem?.expiryTime ?
    Date.parse(lineItem.expiryTime) :
    NaN;
  const subscriptionState = result.data.subscriptionState;
  if (
    !lineItem ||
    !Number.isFinite(expiryMillis) ||
    expiryMillis <= Date.now() ||
    (subscriptionState !== "SUBSCRIPTION_STATE_ACTIVE" &&
      subscriptionState !== "SUBSCRIPTION_STATE_IN_GRACE_PERIOD")
  ) {
    throw invalidReceipt();
  }
  return {
    expiryMillis,
    transactionId: result.data.latestOrderId ?? undefined,
  };
}

/**
 * Verifies a subscription receipt with Apple or Google.
 *
 * Entitlements must only be written after the store receipt is verified.
 */
export const verifySubscription = onCall(
  { secrets: [appleSharedSecret, googlePlayServiceAccountJson] },
  async (request) => {
    // 1. Authentication Check
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "The user must be authenticated to verify a subscription."
      );
    }

    const uid = request.auth.uid;
    const { productId, source, verificationData } = request.data;

    // 2. Validate Input
    if (
      productId !== supportedProductId ||
      !["ios", "android"].includes(source) ||
      typeof verificationData !== "string" ||
      verificationData.length === 0
    ) {
      throw new HttpsError("invalid-argument", "Invalid subscription data.");
    }

    console.log(
      `[Subscription] Verifying receipt for User: ${uid} | ` +
      `Product: ${productId} | Source: ${source}`
    );

    if (
      (source === "ios" && !appleSharedSecret.value()) ||
      (source === "android" && !googlePlayServiceAccountJson.value())
    ) {
      throw new HttpsError(
        "failed-precondition",
        "Subscription verification is not configured for this environment."
      );
    }

    const verified = source === "ios" ?
      await verifyAppleReceipt(verificationData, productId) :
      await verifyGoogleReceipt(verificationData, productId);
    const now = admin.firestore.Timestamp.now();
    const expiryDate = admin.firestore.Timestamp.fromMillis(
      verified.expiryMillis
    );
    await admin.firestore().collection("user").doc(uid).set(
      {
        subscriptionStatus: "active",
        subscriptionExpiryDate: expiryDate,
        subscriptionProductId: productId,
        subscriptionTransactionId: verified.transactionId ?? null,
        subscriptionPurchaseDate: now,
        lastUpdated: now,
      },
      { merge: true }
    );

    return {
      success: true,
      status: "active",
      expiryDate: verified.expiryMillis,
    };
  }
);
