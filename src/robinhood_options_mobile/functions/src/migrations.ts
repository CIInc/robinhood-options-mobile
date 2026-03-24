import { onCall } from "firebase-functions/v2/https";
import { getFirestore } from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";

/**
 * Migration function to populate the 'date' field for all existing documents
 * in the 'signals' collection. The 'date' field is a Date object truncated
 * to midnight based on the 'timestamp' field.
 */
export const migrateSignalsDate = onCall({
  memory: "512MiB",
  timeoutSeconds: 540, // Max timeout for heavy migrations
}, async (request) => {
  logger.info("Request data:", request.data);
  const db = getFirestore();
  const signalsRef = db.collection("signals");

  logger.info("Starting migration of 'signals' collection to add 'date'...");

  let processedCount = 0;
  let updatedCount = 0;
  let batch = db.batch();
  let batchCount = 0;

  const snapshot = await signalsRef.get();

  for (const doc of snapshot.docs) {
    const data = doc.data();
    processedCount++;

    // Skip if date already exists
    if (data.date) continue;

    const timestamp = data.timestamp;
    if (timestamp) {
      const tsDate = new Date(timestamp);
      // Create date truncated to midnight
      const dateOnly = new Date(
        tsDate.getFullYear(),
        tsDate.getMonth(),
        tsDate.getDate()
      );

      batch.update(doc.ref, { date: dateOnly });
      batchCount++;
      updatedCount++;

      // Firestore batch limit is 500
      if (batchCount >= 400) {
        await batch.commit();
        batch = db.batch();
        batchCount = 0;
        logger.info(
          `Committed batch. Processed: ${processedCount}, ` +
          `Updated: ${updatedCount}`
        );
      }
    }
  }

  if (batchCount > 0) {
    await batch.commit();
  }

  logger.info(
    `Migration completed. Total processed: ${processedCount}, ` +
    `Total updated: ${updatedCount}`
  );
});
