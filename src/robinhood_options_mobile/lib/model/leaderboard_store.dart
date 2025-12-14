import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'portfolio_leaderboard.dart';

/// Store for managing leaderboard state and operations
class LeaderboardStore extends ChangeNotifier {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  List<PortfolioPerformance> _leaderboard = [];
  Set<String> _followedUsers = {};
  LeaderboardTimePeriod _selectedPeriod = LeaderboardTimePeriod.all;
  bool _showOnlyFollowed = false;
  bool _isLoading = false;
  String? _error;
  StreamSubscription<QuerySnapshot>? _leaderboardSubscription;
  StreamSubscription<QuerySnapshot>? _followsSubscription;

  LeaderboardStore({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance,
        _auth = auth ?? FirebaseAuth.instance {
    _init();
  }

  List<PortfolioPerformance> get leaderboard => _showOnlyFollowed
      ? _leaderboard.where((p) => _followedUsers.contains(p.userId)).toList()
      : _leaderboard;

  Set<String> get followedUsers => _followedUsers;
  LeaderboardTimePeriod get selectedPeriod => _selectedPeriod;
  bool get showOnlyFollowed => _showOnlyFollowed;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool isFollowing(String userId) => _followedUsers.contains(userId);

  void _init() {
    _subscribeToLeaderboard();
    _subscribeToFollows();
  }

  /// Subscribe to real-time leaderboard updates
  void _subscribeToLeaderboard() {
    _leaderboardSubscription?.cancel();
    _leaderboardSubscription = _firestore
        .collection('portfolio_leaderboard')
        .where('isPublic', isEqualTo: true)
        .snapshots()
        .listen(
      (snapshot) {
        try {
          // Create a list with rankings based on the selected period
          final performances = snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'doc': doc,
              'return': _getReturnForPeriod(data),
            };
          }).toList();

          // Sort by return for selected period
          performances.sort((a, b) =>
              (b['return'] as double).compareTo(a['return'] as double));

          // Get previous rankings
          final previousRankings = <String, int>{};
          for (final perf in _leaderboard) {
            previousRankings[perf.userId] = perf.rank;
          }

          // Create PortfolioPerformance objects with ranks
          _leaderboard = performances.asMap().entries.map((entry) {
            final rank = entry.key + 1;
            final doc = entry.value['doc'] as DocumentSnapshot;
            final previousRank = previousRankings[doc.id];
            return PortfolioPerformance.fromFirestore(doc, rank, previousRank);
          }).toList();

          _error = null;
          notifyListeners();
        } catch (e) {
          _error = 'Error loading leaderboard: $e';
          notifyListeners();
        }
      },
      onError: (error) {
        _error = 'Error subscribing to leaderboard: $error';
        notifyListeners();
      },
    );
  }

  /// Subscribe to user's follows
  void _subscribeToFollows() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    _followsSubscription?.cancel();
    _followsSubscription = _firestore
        .collection('portfolio_follows')
        .where('followerId', isEqualTo: userId)
        .snapshots()
        .listen(
      (snapshot) {
        _followedUsers = snapshot.docs.map((doc) {
          final data = doc.data();
          return data['followeeId'] as String;
        }).toSet();
        notifyListeners();
      },
      onError: (error) {
        debugPrint('Error subscribing to follows: $error');
      },
    );
  }

  /// Get return value for selected period from Firestore data
  double _getReturnForPeriod(Map<String, dynamic> data) {
    switch (_selectedPeriod) {
      case LeaderboardTimePeriod.day:
        return (data['dayReturnPercentage'] ?? 0.0).toDouble();
      case LeaderboardTimePeriod.week:
        return (data['weekReturnPercentage'] ?? 0.0).toDouble();
      case LeaderboardTimePeriod.month:
        return (data['monthReturnPercentage'] ?? 0.0).toDouble();
      case LeaderboardTimePeriod.threeMonths:
        return (data['threeMonthReturnPercentage'] ?? 0.0).toDouble();
      case LeaderboardTimePeriod.year:
        return (data['yearReturnPercentage'] ?? 0.0).toDouble();
      case LeaderboardTimePeriod.all:
        return (data['allTimeReturnPercentage'] ?? 0.0).toDouble();
    }
  }

  /// Change the selected time period
  void setTimePeriod(LeaderboardTimePeriod period) {
    if (_selectedPeriod == period) return;
    _selectedPeriod = period;
    _subscribeToLeaderboard(); // Re-sort by new period
  }

  /// Toggle showing only followed users
  void toggleShowOnlyFollowed() {
    _showOnlyFollowed = !_showOnlyFollowed;
    notifyListeners();
  }

  /// Follow a user
  Future<void> followUser(String userId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      throw Exception('User must be authenticated');
    }

    try {
      final followDoc = _firestore
          .collection('portfolio_follows')
          .doc('${currentUserId}_$userId');

      await followDoc.set({
        'followerId': currentUserId,
        'followeeId': userId,
        'followedAt': FieldValue.serverTimestamp(),
      });

      _followedUsers.add(userId);
      notifyListeners();
    } catch (e) {
      _error = 'Error following user: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Unfollow a user
  Future<void> unfollowUser(String userId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      throw Exception('User must be authenticated');
    }

    try {
      final followDoc = _firestore
          .collection('portfolio_follows')
          .doc('${currentUserId}_$userId');

      await followDoc.delete();

      _followedUsers.remove(userId);
      notifyListeners();
    } catch (e) {
      _error = 'Error unfollowing user: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Toggle follow status for a user
  Future<void> toggleFollow(String userId) async {
    if (isFollowing(userId)) {
      await unfollowUser(userId);
    } else {
      await followUser(userId);
    }
  }

  /// Update current user's portfolio public status
  Future<void> updatePortfolioPublicStatus(bool isPublic) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final callable = _functions.httpsCallable('updatePortfolioPublicStatus');
      await callable.call({'isPublic': isPublic});

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Error updating portfolio status: $e';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Manually trigger leaderboard calculation (admin)
  Future<void> calculateLeaderboard() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final callable = _functions.httpsCallable('calculateLeaderboardManual');
      await callable.call();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Error calculating leaderboard: $e';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Get portfolio performance for a specific user
  Future<PortfolioPerformance?> getPerformance(String userId) async {
    try {
      final doc = await _firestore
          .collection('portfolio_leaderboard')
          .doc(userId)
          .get();

      if (!doc.exists) return null;

      // Find the rank in current leaderboard
      final index = _leaderboard.indexWhere((p) => p.userId == userId);
      final rank = index >= 0 ? index + 1 : 0;

      return PortfolioPerformance.fromFirestore(doc, rank, null);
    } catch (e) {
      debugPrint('Error fetching performance for $userId: $e');
      return null;
    }
  }

  /// Get user's current rank
  int? getUserRank(String userId) {
    final index = _leaderboard.indexWhere((p) => p.userId == userId);
    return index >= 0 ? index + 1 : null;
  }

  @override
  void dispose() {
    _leaderboardSubscription?.cancel();
    _followsSubscription?.cancel();
    super.dispose();
  }
}
