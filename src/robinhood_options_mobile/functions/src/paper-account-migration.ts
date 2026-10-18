import { getAuth } from "firebase-admin/auth";
import {
  DocumentData,
  getFirestore,
  QueryDocumentSnapshot,
} from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

type MigrationPolicy = "keep_existing" | "replace_with_guest";

/**
 * Treats a default account document as empty so it does not prompt on sign-in.
 * @param {DocumentData | undefined} data Account document data.
 * @return {boolean} Whether the account contains user-created paper state.
 */
function hasPaperAccountActivity(data: DocumentData | undefined): boolean {
  if (!data) return false;
  const initialCapital =
    typeof data.initialCapital === "number" ? data.initialCapital : 100000;
  const cashBalance =
    typeof data.cashBalance === "number" ? data.cashBalance : initialCapital;
  const hasPositions = [
    "positions",
    "optionPositions",
    "futuresPositions",
    "pendingOrders",
    "history",
  ].some((key) => Array.isArray(data[key]) && data[key].length > 0);
  return hasPositions ||
    cashBalance !== initialCapital ||
    (typeof data.slippage === "number" && data.slippage !== 0) ||
    (typeof data.commission === "number" && data.commission !== 0);
}

/**
 * Copies a subcollection into another user's paper-trading namespace.
 * @param {FirebaseFirestore.CollectionReference} source Source collection.
 * @param {FirebaseFirestore.CollectionReference} destination Target collection.
 * @param {string} guestUid Source anonymous user id.
 * @return {Promise<void>} Resolves after all source documents are copied.
 */
async function copyCollection(
  source: FirebaseFirestore.CollectionReference,
  destination: FirebaseFirestore.CollectionReference,
  guestUid: string,
): Promise<void> {
  let lastDocument: QueryDocumentSnapshot | undefined;
  let done = false;
  while (!done) {
    let query = source.orderBy("__name__").limit(400);
    if (lastDocument) query = query.startAfter(lastDocument);
    const snapshot = await query.get();
    if (snapshot.empty) return;

    const batch = getFirestore().batch();
    for (const document of snapshot.docs) {
      const destinationId = `guest_${guestUid}_${document.id}`;
      batch.set(destination.doc(destinationId), document.data());
    }
    await batch.commit();
    lastDocument = snapshot.docs[snapshot.docs.length - 1];
    done = snapshot.size < 400;
  }
}

/**
 * Deletes every document in a source paper-trading subcollection.
 * @param {FirebaseFirestore.CollectionReference} collection Source to clear.
 * @return {Promise<void>} Resolves after the collection is empty.
 */
async function deleteCollection(
  collection: FirebaseFirestore.CollectionReference,
): Promise<void> {
  let done = false;
  while (!done) {
    const snapshot = await collection.orderBy("__name__").limit(400).get();
    if (snapshot.empty) return;
    const batch = getFirestore().batch();
    snapshot.docs.forEach((document) => batch.delete(document.ref));
    await batch.commit();
    done = snapshot.size < 400;
  }
}

export const migrateGuestPaperAccount = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "Sign in before migrating paper trading.",
    );
  }

  const guestIdToken = request.data?.guestIdToken;
  if (typeof guestIdToken !== "string" || guestIdToken.length === 0) {
    throw new HttpsError(
      "invalid-argument",
      "A guest session token is required.",
    );
  }

  let guestToken;
  try {
    guestToken = await getAuth().verifyIdToken(guestIdToken);
  } catch {
    throw new HttpsError("unauthenticated", "The guest session has expired.");
  }

  const guestUid = guestToken.uid;
  if (
    guestUid === request.auth.uid ||
    guestToken.firebase?.sign_in_provider !== "anonymous"
  ) {
    throw new HttpsError(
      "permission-denied",
      "Only a different anonymous session can be migrated.",
    );
  }

  const db = getFirestore();
  const guestUser = db.collection("user").doc(guestUid);
  const signedInUser = db.collection("user").doc(request.auth.uid);
  const guestAccount = guestUser.collection("paper_account").doc("main");
  const signedInAccount = signedInUser.collection("paper_account").doc("main");
  const [guestSnapshot, signedInSnapshot] = await Promise.all([
    guestAccount.get(),
    signedInAccount.get(),
  ]);

  const policyValue = request.data?.policy;
  if (policyValue != null &&
      policyValue !== "keep_existing" &&
      policyValue !== "replace_with_guest") {
    throw new HttpsError(
      "invalid-argument",
      "Unknown paper-account migration policy.",
    );
  }
  const policy = policyValue as MigrationPolicy | undefined;

  const migrationRef =
    signedInUser.collection("paper_migrations").doc(guestUid);
  const completedMigration = await migrationRef.get();
  if (completedMigration.exists) {
    return { migrated: true, alreadyMigrated: true, conflict: false };
  }

  const guestFills = guestUser.collection("paper_orders");
  const guestEquityHistory = guestUser.collection("paper_equity_history");
  const signedInFills = signedInUser.collection("paper_orders");
  const signedInHistory = signedInUser.collection("paper_equity_history");
  const [
    fillsSnapshot,
    historySnapshot,
    signedInFillsSnapshot,
    signedInHistorySnapshot,
  ] = await Promise.all([
    guestFills.limit(1).get(),
    guestEquityHistory.limit(1).get(),
    signedInFills.limit(1).get(),
    signedInHistory.limit(1).get(),
  ]);
  const hasGuestPaperData =
    hasPaperAccountActivity(guestSnapshot.data()) ||
    !fillsSnapshot.empty ||
    !historySnapshot.empty;

  if (!hasGuestPaperData) {
    return { migrated: false, alreadyMigrated: false, conflict: false };
  }

  const hasSignedInPaperData =
    hasPaperAccountActivity(signedInSnapshot.data()) ||
    !signedInFillsSnapshot.empty ||
    !signedInHistorySnapshot.empty;
  const conflict = hasGuestPaperData && hasSignedInPaperData;
  if (conflict && !policy) {
    return { migrated: false, alreadyMigrated: false, conflict: true };
  }

  const shouldReplace =
    !hasPaperAccountActivity(signedInSnapshot.data()) ||
    policy === "replace_with_guest";
  if (shouldReplace && guestSnapshot.exists) {
    const data: DocumentData = guestSnapshot.data()!;
    data.historyMigrated = true;
    await signedInAccount.set(data);
  }

  await copyCollection(
    guestFills,
    signedInFills,
    guestUid,
  );
  await copyCollection(
    guestEquityHistory,
    signedInHistory,
    guestUid,
  );

  if (!guestSnapshot.data()?.historyMigrated && fillsSnapshot.empty) {
    const legacyHistory =
      (guestSnapshot.data()?.history as DocumentData[] | undefined) ?? [];
    for (let offset = 0; offset < legacyHistory.length; offset += 400) {
      const batch = db.batch();
      legacyHistory.slice(offset, offset + 400).forEach((entry, index) => {
        const id = `guest_${guestUid}_legacy_${offset + index}`;
        batch.set(signedInUser.collection("paper_orders").doc(id), entry);
      });
      await batch.commit();
    }
  }

  await Promise.all([
    deleteCollection(guestFills),
    deleteCollection(guestEquityHistory),
    guestAccount.delete(),
  ]);

  await migrationRef.set({
    sourceUid: guestUid,
    policy: policy ?? "replace_with_guest",
    migratedAt: new Date(),
  });

  return { migrated: true, alreadyMigrated: false, conflict: false };
});
