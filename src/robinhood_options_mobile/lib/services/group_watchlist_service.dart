import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:robinhood_options_mobile/model/group_watchlist_models.dart';

class GroupWatchlistService {
  final FirebaseFirestore _firestore;

  GroupWatchlistService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Create a new group watchlist
  Future<String> createGroupWatchlist({
    required String groupId,
    required String name,
    required String description,
    required String createdBy,
    required Map<String, String> permissions,
  }) async {
    final watchlistRef = _firestore
        .collection('investor_groups')
        .doc(groupId)
        .collection('watchlists')
        .doc();

    await watchlistRef.set({
      'groupId': groupId,
      'name': name,
      'description': description,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'permissions': permissions,
    });

    return watchlistRef.id;
  }

  /// Delete a group watchlist
  Future<void> deleteGroupWatchlist({
    required String groupId,
    required String watchlistId,
  }) async {
    final watchlistRef = _firestore
        .collection('investor_groups')
        .doc(groupId)
        .collection('watchlists')
        .doc(watchlistId);

    // Delete all symbols in the watchlist
    final symbolsSnapshot = await watchlistRef.collection('symbols').get();
    for (final doc in symbolsSnapshot.docs) {
      await doc.reference.delete();
    }

    // Delete the watchlist itself
    await watchlistRef.delete();
  }

  /// Get all watchlists for a group
  Stream<List<GroupWatchlist>> getGroupWatchlistsStream(String groupId) {
    return _firestore
        .collection('investor_groups')
        .doc(groupId)
        .collection('watchlists')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final watchlists = <GroupWatchlist>[];

      for (final doc in snapshot.docs) {
        final watchlist = GroupWatchlist.fromFirestore(doc);

        // Get all symbols for this watchlist
        final symbolsSnapshot = await _firestore
            .collection('investor_groups')
            .doc(groupId)
            .collection('watchlists')
            .doc(doc.id)
            .collection('symbols')
            .get();

        final symbols = <WatchlistSymbol>[];

        // For each symbol, fetch its alerts
        for (final symbolDoc in symbolsSnapshot.docs) {
          final symbol = WatchlistSymbol.fromFirestore(symbolDoc);

          final alertsSnapshot = await _firestore
              .collection('investor_groups')
              .doc(groupId)
              .collection('watchlists')
              .doc(doc.id)
              .collection('symbols')
              .doc(symbol.id)
              .collection('alerts')
              .get();

          final alerts = alertsSnapshot.docs
              .map((alertDoc) =>
                  WatchlistAlert.fromFirestore(alertDoc.data(), alertDoc.id))
              .toList();

          symbols.add(symbol.copyWith(alerts: alerts));
        }

        watchlists.add(watchlist.copyWith(symbols: symbols));
      }

      return watchlists;
    });
  }

  /// Get a single watchlist with all symbols and alerts
  Stream<GroupWatchlist?> getWatchlistStream({
    required String groupId,
    required String watchlistId,
  }) {
    return _firestore
        .collection('investor_groups')
        .doc(groupId)
        .collection('watchlists')
        .doc(watchlistId)
        .snapshots()
        .asyncMap((watchlistDoc) async {
      if (!watchlistDoc.exists) {
        return null;
      }

      final watchlist = GroupWatchlist.fromFirestore(watchlistDoc);

      // Get all symbols
      final symbolsSnapshot = await _firestore
          .collection('investor_groups')
          .doc(groupId)
          .collection('watchlists')
          .doc(watchlistId)
          .collection('symbols')
          .get();

      final symbols = <WatchlistSymbol>[];

      // For each symbol, fetch its alerts
      for (final symbolDoc in symbolsSnapshot.docs) {
        final symbol = WatchlistSymbol.fromFirestore(symbolDoc);

        final alertsSnapshot = await _firestore
            .collection('investor_groups')
            .doc(groupId)
            .collection('watchlists')
            .doc(watchlistId)
            .collection('symbols')
            .doc(symbol.id)
            .collection('alerts')
            .get();

        final alerts = alertsSnapshot.docs
            .map((alertDoc) =>
                WatchlistAlert.fromFirestore(alertDoc.data(), alertDoc.id))
            .toList();

        symbols.add(symbol.copyWith(alerts: alerts));
      }

      return watchlist.copyWith(symbols: symbols);
    });
  }

  /// Add a symbol to a watchlist
  Future<void> addSymbolToWatchlist({
    required String groupId,
    required String watchlistId,
    required String symbol,
    required String addedBy,
  }) async {
    final symbolRef = _firestore
        .collection('investor_groups')
        .doc(groupId)
        .collection('watchlists')
        .doc(watchlistId)
        .collection('symbols')
        .doc(symbol.toUpperCase());

    await symbolRef.set({
      'symbol': symbol.toUpperCase(),
      'addedBy': addedBy,
      'addedAt': FieldValue.serverTimestamp(),
    });

    // Update the watchlist's updatedAt timestamp
    await _firestore
        .collection('investor_groups')
        .doc(groupId)
        .collection('watchlists')
        .doc(watchlistId)
        .update({
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Remove a symbol from a watchlist
  Future<void> removeSymbolFromWatchlist({
    required String groupId,
    required String watchlistId,
    required String symbol,
  }) async {
    await _firestore
        .collection('investor_groups')
        .doc(groupId)
        .collection('watchlists')
        .doc(watchlistId)
        .collection('symbols')
        .doc(symbol.toUpperCase())
        .delete();

    // Update the watchlist's updatedAt timestamp
    await _firestore
        .collection('investor_groups')
        .doc(groupId)
        .collection('watchlists')
        .doc(watchlistId)
        .update({
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Create a price alert for a symbol in a watchlist
  Future<String> createPriceAlert({
    required String groupId,
    required String watchlistId,
    required String symbol,
    required String type,
    required double threshold,
  }) async {
    final symbolRef = _firestore
        .collection('investor_groups')
        .doc(groupId)
        .collection('watchlists')
        .doc(watchlistId)
        .collection('symbols')
        .doc(symbol.toUpperCase());

    final alertRef = symbolRef.collection('alerts').doc();

    await alertRef.set({
      'type': type,
      'threshold': threshold,
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return alertRef.id;
  }

  /// Delete a price alert
  Future<void> deletePriceAlert({
    required String groupId,
    required String watchlistId,
    required String symbol,
    required String alertId,
  }) async {
    await _firestore
        .collection('investor_groups')
        .doc(groupId)
        .collection('watchlists')
        .doc(watchlistId)
        .collection('symbols')
        .doc(symbol.toUpperCase())
        .collection('alerts')
        .doc(alertId)
        .delete();
  }

  /// Update a price alert
  Future<void> updatePriceAlert({
    required String groupId,
    required String watchlistId,
    required String symbol,
    required String alertId,
    required bool active,
    double? threshold,
  }) async {
    final updateData = <String, dynamic>{
      'active': active,
    };
    if (threshold != null) {
      updateData['threshold'] = threshold;
    }

    await _firestore
        .collection('investor_groups')
        .doc(groupId)
        .collection('watchlists')
        .doc(watchlistId)
        .collection('symbols')
        .doc(symbol.toUpperCase())
        .collection('alerts')
        .doc(alertId)
        .update(updateData);
  }

  /// Update watchlist metadata (name, description)
  Future<void> updateWatchlist({
    required String groupId,
    required String watchlistId,
    String? name,
    String? description,
  }) async {
    final updateData = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (name != null) {
      updateData['name'] = name;
    }
    if (description != null) {
      updateData['description'] = description;
    }

    await _firestore
        .collection('investor_groups')
        .doc(groupId)
        .collection('watchlists')
        .doc(watchlistId)
        .update(updateData);
  }

  /// Set member permission for watchlist (editor/viewer)
  Future<void> setWatchlistMemberPermission({
    required String groupId,
    required String watchlistId,
    required String memberId,
    required String permission, // "editor" or "viewer"
  }) async {
    await _firestore
        .collection('investor_groups')
        .doc(groupId)
        .collection('watchlists')
        .doc(watchlistId)
        .update({
      'permissions.$memberId': permission,
    });
  }

  /// Remove member permission from watchlist
  Future<void> removeWatchlistMemberPermission({
    required String groupId,
    required String watchlistId,
    required String memberId,
  }) async {
    await _firestore
        .collection('investor_groups')
        .doc(groupId)
        .collection('watchlists')
        .doc(watchlistId)
        .update({
      'permissions.$memberId': FieldValue.delete(),
    });
  }

  /// Get stream of symbols for a watchlist
  Stream<List<WatchlistSymbol>> getWatchlistSymbolsStream({
    required String groupId,
    required String watchlistId,
  }) {
    return _firestore
        .collection('investor_groups')
        .doc(groupId)
        .collection('watchlists')
        .doc(watchlistId)
        .collection('symbols')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => WatchlistSymbol.fromFirestore(doc))
          .toList();
    });
  }

  /// Get stream of alerts for a symbol in a watchlist
  Stream<List<WatchlistAlert>> getSymbolAlertsStream({
    required String groupId,
    required String watchlistId,
    required String symbol,
  }) {
    return _firestore
        .collection('investor_groups')
        .doc(groupId)
        .collection('watchlists')
        .doc(watchlistId)
        .collection('symbols')
        .doc(symbol.toUpperCase())
        .collection('alerts')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => WatchlistAlert.fromFirestore(doc.data(), doc.id))
          .toList();
    });
  }
}
