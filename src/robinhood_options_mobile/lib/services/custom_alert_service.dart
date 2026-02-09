import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../model/custom_alert.dart';

class CustomAlertService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Stream of alerts for current user
  Stream<List<CustomAlert>> getAlerts() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('user')
        .doc(user.uid)
        .collection('alerts')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CustomAlert.fromFirestore(doc))
            .toList());
  }

  Future<void> createAlert(CustomAlert alert) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore
        .collection('user')
        .doc(user.uid)
        .collection('alerts')
        .add(alert.toFirestore());
  }

  Future<void> updateAlert(CustomAlert alert) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore
        .collection('user')
        .doc(user.uid)
        .collection('alerts')
        .doc(alert.id)
        .update(alert.toFirestore());
  }

  Future<void> deleteAlert(String alertId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore
        .collection('user')
        .doc(user.uid)
        .collection('alerts')
        .doc(alertId)
        .delete();
  }
}
