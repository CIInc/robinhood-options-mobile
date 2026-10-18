import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

const db = getFirestore();
const batchSize = 400;

const asFirestoreDate = (value: unknown): unknown => {
  if (typeof value !== "string") return value;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? value : Timestamp.fromDate(date);
};

export const syncInstrumentOrders = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }

  const orders = request.data?.orders;
  if (!Array.isArray(orders)) {
    throw new HttpsError("invalid-argument", "orders must be an array.");
  }

  const orderCollection = db.collection("user").doc(uid)
    .collection("instrumentOrder");
  let written = 0;

  for (let offset = 0; offset < orders.length; offset += batchSize) {
    const batch = db.batch();
    const chunk = orders.slice(offset, offset + batchSize);
    for (const rawOrder of chunk) {
      if (!rawOrder || typeof rawOrder !== "object" ||
        typeof rawOrder.id !== "string" || rawOrder.id.length === 0) {
        throw new HttpsError("invalid-argument", "Every order needs an id.");
      }

      const order = { ...rawOrder } as Record<string, unknown>;
      order.created_at = asFirestoreDate(order.created_at);
      order.updated_at = asFirestoreDate(order.updated_at);
      batch.set(orderCollection.doc(rawOrder.id), order);
    }
    await batch.commit();
    written += chunk.length;
  }

  return { written };
});
