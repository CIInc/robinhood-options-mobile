import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import { fetchOptionsFlowForSymbols } from "./options-flow-utils";

// Ensure Firebase Admin is initialized
if (admin.apps.length === 0) {
  admin.initializeApp();
}

// Deprecated: Using client to load options flow data
export const getOptionsFlow = functions.https.onCall(async (request) => {
  logger.info("getOptionsFlow called via onCall", { data: request.data });
  // Check authentication
  if (!request.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "The function must be called while authenticated."
    );
  }

  let symbols: string[] = [];

  if (request.data.symbol) {
    symbols = [request.data.symbol];
  } else if (request.data.symbols && Array.isArray(request.data.symbols)) {
    symbols = request.data.symbols;
  } else {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Symbol or symbols list is required"
    );
  }

  try {
    const items = await fetchOptionsFlowForSymbols(
      symbols,
      request.data.expiration
    );

    return {
      items: items,
    };
  } catch (error) {
    logger.error("Error fetching options flow", error);
    throw new functions.https.HttpsError(
      "internal",
      "Failed to fetch options flow data"
    );
  }
});

export const createOptionAlert = functions.https.onCall(async (request) => {
  if (!request.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "The function must be called while authenticated."
    );
  }

  const { symbol, targetPremium, sentiment, condition } = request.data;

  if (!symbol || typeof symbol !== "string") {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Symbol is required and must be a string"
    );
  }

  if (targetPremium && typeof targetPremium !== "number") {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Target premium must be a number"
    );
  }

  const uid = request.auth.uid;

  try {
    const alertRef = admin.firestore().collection("options_flow_alerts").doc();
    await alertRef.set({
      uid,
      symbol: symbol.toUpperCase(),
      targetPremium: targetPremium || 50000,
      sentiment: sentiment || "any",
      condition: condition || "above",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      isActive: true,
    });

    return { success: true, id: alertRef.id };
  } catch (error) {
    logger.error("Error creating option alert", error);
    throw new functions.https.HttpsError("internal", "Failed to create alert");
  }
});

export const toggleOptionAlert = functions.https.onCall(async (request) => {
  if (!request.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "The function must be called while authenticated."
    );
  }

  const { alertId, isActive } = request.data;
  const uid = request.auth.uid;

  if (!alertId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Alert ID is required"
    );
  }

  try {
    const alertRef = admin.firestore()
      .collection("options_flow_alerts")
      .doc(alertId);

    const doc = await alertRef.get();
    if (!doc.exists) {
      throw new functions.https.HttpsError("not-found", "Alert not found");
    }

    if (doc.data()?.uid !== uid) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Not authorized to update this alert"
      );
    }

    await alertRef.update({
      isActive: isActive,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true };
  } catch (error) {
    logger.error("Error toggling option alert", error);
    throw new functions.https.HttpsError("internal", "Failed to toggle alert");
  }
});

export const getOptionAlerts = functions.https.onCall(async (request) => {
  if (!request.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "The function must be called while authenticated."
    );
  }

  const uid = request.auth.uid;

  try {
    const snapshot = await admin.firestore()
      .collection("options_flow_alerts")
      .where("uid", "==", uid)
      .orderBy("createdAt", "desc")
      .get();

    const alerts = snapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));

    return { alerts };
  } catch (error) {
    logger.error("Error fetching option alerts", error);
    throw new functions.https.HttpsError("internal", "Failed to fetch alerts");
  }
});

export const deleteOptionAlert = functions.https.onCall(async (request) => {
  if (!request.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "The function must be called while authenticated."
    );
  }

  const { alertId } = request.data;
  const uid = request.auth.uid;

  try {
    const alertRef = admin.firestore()
      .collection("options_flow_alerts")
      .doc(alertId);

    const doc = await alertRef.get();
    if (!doc.exists) {
      throw new functions.https.HttpsError("not-found", "Alert not found");
    }

    if (doc.data()?.uid !== uid) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Not authorized to delete this alert"
      );
    }

    await alertRef.delete();
    return { success: true };
  } catch (error) {
    logger.error("Error deleting option alert", error);
    throw new functions.https.HttpsError("internal", "Failed to delete alert");
  }
});
