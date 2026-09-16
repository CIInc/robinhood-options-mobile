import 'dart:async';
import 'dart:collection';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:robinhood_options_mobile/model/option_flow_notification.dart';

class OptionFlowNotificationsStore extends ChangeNotifier {
  final List<OptionFlowNotification> _notifications = [];
  StreamSubscription<QuerySnapshot>? _subscription;
  String? _userId;

  UnmodifiableListView<OptionFlowNotification> get notifications =>
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
        .collection('flow_notifications')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .listen((snapshot) {
      _notifications.clear();
      for (var doc in snapshot.docs) {
        try {
          _notifications.add(OptionFlowNotification.fromDocument(doc));
        } catch (e) {
          debugPrint('Error parsing flow notification ${doc.id}: $e');
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
          .collection('flow_notifications')
          .doc(notificationId)
          .update({'read': true});
    } catch (e) {
      debugPrint('Error marking flow notification as read: $e');
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
            .collection('flow_notifications')
            .doc(n.id);
        batch.update(ref, {'read': true});
      }

      if (unreadDocs.isNotEmpty) {
        await batch.commit();
      }
    } catch (e) {
      debugPrint('Error marking all flow notifications as read: $e');
    }
  }

  Future<void> delete(String notificationId) async {
    if (_userId == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('user')
          .doc(_userId)
          .collection('flow_notifications')
          .doc(notificationId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting flow notification: $e');
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
