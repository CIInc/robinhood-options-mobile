import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

const db = getFirestore();

/**
 * Verifies group existence and that caller is currently an active member.
 * @param {string} groupId ID of the investor group.
 * @param {string} userId ID of the user calling the function.
 * @return {Promise<any>} The group data object.
 */
async function ensureGroupMember(groupId: string, userId: string) {
  const groupDoc = await db
    .collection("investor_groups")
    .doc(groupId)
    .get();

  if (!groupDoc.exists) {
    throw new HttpsError("not-found", "Group not found");
  }

  const groupData = groupDoc.data() as any;
  const members = groupData?.members || [];
  if (!Array.isArray(members) || !members.includes(userId)) {
    throw new HttpsError(
      "permission-denied",
      "You must be an active member of this group"
    );
  }
  return groupData;
}

/**
 * Create a new group watchlist
 */
export const createGroupWatchlist = onCall(
  async (request: any) => {
    // Verify user is authenticated
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "User must be authenticated"
      );
    }

    const { groupId, name, description } = request.data;
    const userId = request.auth.uid;

    // Validate input
    if (!groupId || !name) {
      throw new HttpsError(
        "invalid-argument",
        "groupId and name are required"
      );
    }

    await ensureGroupMember(groupId, userId);

    // Create watchlist with user as editor only
    // All other group members are assumed to be
    // viewers by convention (not stored in permissions)
    const watchlistRef = db
      .collection("investor_groups")
      .doc(groupId)
      .collection("watchlists")
      .doc();

    await watchlistRef.set({
      groupId,
      name,
      description,
      createdBy: userId,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      permissions: {
        [userId]: "editor",
      },
    });

    return {
      success: true,
      watchlistId: watchlistRef.id,
    };
  }
);

/**
 * Delete a group watchlist
 */
export const deleteGroupWatchlist = onCall(
  async (request: any) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "User must be authenticated"
      );
    }

    const { groupId, watchlistId } = request.data;
    const userId = request.auth.uid;

    await ensureGroupMember(groupId, userId);

    const watchlistDoc = await db
      .collection("investor_groups")
      .doc(groupId)
      .collection("watchlists")
      .doc(watchlistId)
      .get();

    if (!watchlistDoc.exists) {
      throw new HttpsError(
        "not-found",
        "Watchlist not found"
      );
    }

    const watchlistData = watchlistDoc.data() as any;
    const permissions = watchlistData?.permissions || {};

    // Only creator or editor can delete
    if (permissions[userId] !== "editor" &&
      watchlistData.createdBy !== userId) {
      throw new HttpsError(
        "permission-denied",
        "Only the watchlist creator or an editor can delete this watchlist"
      );
    }

    // Delete all symbols and their alerts
    const symbolsSnapshot = await watchlistDoc.ref
      .collection("symbols")
      .get();
    const batch = db.batch();

    const alertsSnapshots = await Promise.all(
      symbolsSnapshot.docs.map((symbolDoc) =>
        symbolDoc.ref.collection("alerts").get()
      )
    );

    symbolsSnapshot.docs.forEach((symbolDoc, index) => {
      const alertsSnapshot = alertsSnapshots[index];
      for (const alertDoc of alertsSnapshot.docs) {
        batch.delete(alertDoc.ref);
      }
      batch.delete(symbolDoc.ref);
    });

    // Delete watchlist
    batch.delete(watchlistDoc.ref);
    await batch.commit();

    return { success: true };
  }
);

/**
 * Add symbol to watchlist
 */
export const addSymbolToWatchlist = onCall(
  async (request: any) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "User must be authenticated"
      );
    }

    const { groupId, watchlistId, symbol } = request.data || {};
    const userId = request.auth.uid;

    if (!groupId || typeof groupId !== "string" ||
      !watchlistId || typeof watchlistId !== "string" ||
      !symbol || typeof symbol !== "string" || !symbol.trim()) {
      throw new HttpsError(
        "invalid-argument",
        "groupId, watchlistId, and symbol must be non-empty strings"
      );
    }

    await ensureGroupMember(groupId, userId);

    const watchlistDoc = await db
      .collection("investor_groups")
      .doc(groupId)
      .collection("watchlists")
      .doc(watchlistId)
      .get();

    if (!watchlistDoc.exists) {
      throw new HttpsError(
        "not-found",
        "Watchlist not found"
      );
    }

    const watchlistData = watchlistDoc.data() as any;
    const permissions = watchlistData?.permissions || {};

    // User must be editor
    if (permissions[userId] !== "editor" &&
      watchlistData.createdBy !== userId) {
      throw new HttpsError(
        "permission-denied",
        "User does not have permission to edit this watchlist"
      );
    }

    // Add symbol
    const upperSymbol = symbol.toUpperCase();
    await watchlistDoc.ref.collection("symbols").doc(upperSymbol).set({
      symbol: upperSymbol,
      addedBy: userId,
      addedAt: FieldValue.serverTimestamp(),
    });

    // Update watchlist timestamp
    await watchlistDoc.ref.update({
      updatedAt: FieldValue.serverTimestamp(),
    });

    return { success: true };
  }
);

/**
 * Remove symbol from watchlist
 */
export const removeSymbolFromWatchlist = onCall(
  async (request: any) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "User must be authenticated"
      );
    }

    const { groupId, watchlistId, symbol } = request.data || {};
    const userId = request.auth.uid;

    if (!groupId || typeof groupId !== "string" ||
      !watchlistId || typeof watchlistId !== "string" ||
      !symbol || typeof symbol !== "string" || !symbol.trim()) {
      throw new HttpsError(
        "invalid-argument",
        "groupId, watchlistId, and symbol must be non-empty strings"
      );
    }

    await ensureGroupMember(groupId, userId);

    const watchlistDoc = await db
      .collection("investor_groups")
      .doc(groupId)
      .collection("watchlists")
      .doc(watchlistId)
      .get();

    if (!watchlistDoc.exists) {
      throw new HttpsError(
        "not-found",
        "Watchlist not found"
      );
    }

    const watchlistData = watchlistDoc.data() as any;
    const permissions = watchlistData?.permissions || {};

    // User must be editor
    if (permissions[userId] !== "editor" &&
      watchlistData.createdBy !== userId) {
      throw new HttpsError(
        "permission-denied",
        "User does not have permission to edit this watchlist"
      );
    }

    // Remove symbol and its alerts
    const upperSymbol = symbol.toUpperCase();
    const symbolRef = watchlistDoc.ref
      .collection("symbols")
      .doc(upperSymbol);
    const alertsSnapshot = await symbolRef
      .collection("alerts")
      .get();

    const batch = db.batch();
    for (const alertDoc of alertsSnapshot.docs) {
      batch.delete(alertDoc.ref);
    }
    batch.delete(symbolRef);
    await batch.commit();

    // Update watchlist timestamp
    await watchlistDoc.ref.update({
      updatedAt: FieldValue.serverTimestamp(),
    });

    return { success: true };
  }
);

/**
 * Create price alert for a symbol
 */
export const createPriceAlert = onCall(
  async (request: any) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "User must be authenticated"
      );
    }

    const { groupId, watchlistId, symbol, type, threshold } =
      request.data || {};
    const userId = request.auth.uid;

    if (!groupId || typeof groupId !== "string" ||
      !watchlistId || typeof watchlistId !== "string" ||
      !symbol || typeof symbol !== "string" || !symbol.trim()) {
      throw new HttpsError(
        "invalid-argument",
        "groupId, watchlistId, and symbol must be non-empty strings"
      );
    }

    if (type !== "above" && type !== "below") {
      throw new HttpsError(
        "invalid-argument",
        "Alert type must be 'above' or 'below'"
      );
    }

    if (
      typeof threshold !== "number" ||
      !Number.isFinite(threshold) ||
      threshold <= 0
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Alert threshold must be a positive number"
      );
    }

    await ensureGroupMember(groupId, userId);

    const watchlistDoc = await db
      .collection("investor_groups")
      .doc(groupId)
      .collection("watchlists")
      .doc(watchlistId)
      .get();

    if (!watchlistDoc.exists) {
      throw new HttpsError(
        "not-found",
        "Watchlist not found"
      );
    }

    const watchlistData = watchlistDoc.data() as any;
    const permissions = watchlistData?.permissions || {};

    // User must be editor
    if (permissions[userId] !== "editor" &&
      watchlistData.createdBy !== userId) {
      throw new HttpsError(
        "permission-denied",
        "User does not have permission to edit this watchlist"
      );
    }

    // Create alert
    const upperSymbol = symbol.toUpperCase();
    const alertRef = watchlistDoc.ref
      .collection("symbols")
      .doc(upperSymbol)
      .collection("alerts")
      .doc();

    await alertRef.set({
      type,
      threshold,
      active: true,
      createdAt: FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      alertId: alertRef.id,
    };
  }
);

/**
 * Delete price alert
 */
export const deletePriceAlert = onCall(
  async (request: any) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "User must be authenticated"
      );
    }

    const { groupId, watchlistId, symbol, alertId } = request.data || {};
    const userId = request.auth.uid;

    if (!groupId || typeof groupId !== "string" ||
      !watchlistId || typeof watchlistId !== "string" ||
      !symbol || typeof symbol !== "string" || !symbol.trim() ||
      !alertId || typeof alertId !== "string") {
      throw new HttpsError(
        "invalid-argument",
        "groupId, watchlistId, symbol, and alertId must be non-empty strings"
      );
    }

    await ensureGroupMember(groupId, userId);

    const watchlistDoc = await db
      .collection("investor_groups")
      .doc(groupId)
      .collection("watchlists")
      .doc(watchlistId)
      .get();

    if (!watchlistDoc.exists) {
      throw new HttpsError(
        "not-found",
        "Watchlist not found"
      );
    }

    const watchlistData = watchlistDoc.data() as any;
    const permissions = watchlistData?.permissions || {};

    // User must be editor
    if (permissions[userId] !== "editor" &&
      watchlistData.createdBy !== userId) {
      throw new HttpsError(
        "permission-denied",
        "User does not have permission to edit this watchlist"
      );
    }

    // Delete alert
    const upperSymbol = symbol.toUpperCase();
    await watchlistDoc.ref
      .collection("symbols")
      .doc(upperSymbol)
      .collection("alerts")
      .doc(alertId)
      .delete();

    return { success: true };
  }
);

/**
 * Set member permission on watchlist
 */
export const setWatchlistMemberPermission = onCall(
  async (request: any) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "User must be authenticated"
      );
    }

    const { groupId, watchlistId, memberId, permission } = request.data;
    const userId = request.auth.uid;

    // Validate permission value
    if (!["editor", "viewer"].includes(permission)) {
      throw new HttpsError(
        "invalid-argument",
        "Permission must be \"editor\" or \"viewer\""
      );
    }

    const groupData = await ensureGroupMember(groupId, userId);

    const watchlistDoc = await db
      .collection("investor_groups")
      .doc(groupId)
      .collection("watchlists")
      .doc(watchlistId)
      .get();

    if (!watchlistDoc.exists) {
      throw new HttpsError(
        "not-found",
        "Watchlist not found"
      );
    }

    const watchlistData = watchlistDoc.data() as any;
    const permissions = watchlistData?.permissions || {};

    // Only creator or existing editors can change permissions
    if (permissions[userId] !== "editor" &&
      watchlistData.createdBy !== userId) {
      throw new HttpsError(
        "permission-denied",
        "User does not have permission to manage this watchlist"
      );
    }

    // Check member exists in group
    const groupMembers = groupData?.members || [];
    if (!Array.isArray(groupMembers) || !groupMembers.includes(memberId)) {
      throw new HttpsError(
        "not-found",
        "Member not found in group"
      );
    }

    // Update permission: promote to editor or demote to viewer (by deleting)
    if (permission === "editor") {
      await watchlistDoc.ref.update({
        [`permissions.${memberId}`]: "editor",
      });
    } else {
      // Remove from permissions to make them a viewer by convention
      await watchlistDoc.ref.update({
        [`permissions.${memberId}`]: FieldValue.delete(),
      });
    }

    return { success: true };
  }
);

/**
 * Remove member permission from watchlist
 */
export const removeWatchlistMemberPermission = onCall(
  async (request: any) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "User must be authenticated"
      );
    }

    const { groupId, watchlistId, memberId } = request.data;
    const userId = request.auth.uid;

    await ensureGroupMember(groupId, userId);

    const watchlistDoc = await db
      .collection("investor_groups")
      .doc(groupId)
      .collection("watchlists")
      .doc(watchlistId)
      .get();

    if (!watchlistDoc.exists) {
      throw new HttpsError(
        "not-found",
        "Watchlist not found"
      );
    }

    const watchlistData = watchlistDoc.data() as any;
    const permissions = watchlistData?.permissions || {};

    // Only creator or existing editors can change permissions
    if (permissions[userId] !== "editor" &&
      watchlistData.createdBy !== userId) {
      throw new HttpsError(
        "permission-denied",
        "User does not have permission to manage this watchlist"
      );
    }

    // Remove permission
    await watchlistDoc.ref.update({
      [`permissions.${memberId}`]: FieldValue.delete(),
    });

    return { success: true };
  }
);
