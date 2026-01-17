import 'dart:async';
import 'dart:collection';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:robinhood_options_mobile/model/trade_signal_notification.dart';

class TradeSignalNotificationsStore extends ChangeNotifier {
  final List<TradeSignalNotification> _notifications = [];
  StreamSubscription<QuerySnapshot>? _subscription;
  String? _userId;

  UnmodifiableListView<TradeSignalNotification> get notifications =>
      UnmodifiableListView(_notifications);

  int get unreadCount => _notifications.where((n) => !n.read).length;

  void setUserId(String? userId) {
    if (_userId == userId) return;
    _userId = userId;
    _subscription?.cancel();
    _notifications.clear();

    if (userId != null) {
      _initSubscription(userId);
    } else {
      notifyListeners();
    }
  }

  void _initSubscription(String userId) {
    _subscription = FirebaseFirestore.instance
        .collection('user')
        .doc(userId)
        .collection('signal_notifications')
        .orderBy('timestamp', descending: true)
        .limit(100) // Limit to last 100 notifications
        .snapshots()
        .listen((snapshot) {
      _notifications.clear();
      for (var doc in snapshot.docs) {
        try {
          _notifications.add(TradeSignalNotification.fromDocument(doc));
        } catch (e) {
          debugPrint('Error parsing notification ${doc.id}: $e');
        }
      }
      notifyListeners();
    });
  }

  Future<void> markAsRead(String notificationId) async {
    if (_userId == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('user')
          .doc(_userId)
          .collection('signal_notifications')
          .doc(notificationId)
          .update({'read': true});
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    if (_userId == null) return;
    try {
      final batch = FirebaseFirestore.instance.batch();
      var unreadDocs = _notifications.where((n) => !n.read);

      for (var n in unreadDocs) {
        var ref = FirebaseFirestore.instance
            .collection('user')
            .doc(_userId)
            .collection('signal_notifications')
            .doc(n.id);
        batch.update(ref, {'read': true});
      }

      if (unreadDocs.isNotEmpty) {
        await batch.commit();
      }
    } catch (e) {
      debugPrint('Error marking all as read: $e');
    }
  }

  Future<void> delete(String notificationId) async {
    if (_userId == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('user')
          .doc(_userId)
          .collection('signal_notifications')
          .doc(notificationId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
