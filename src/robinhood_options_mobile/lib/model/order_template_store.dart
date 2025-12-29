import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:robinhood_options_mobile/model/order_template.dart';

class OrderTemplateStore extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<OrderTemplate> _templates = [];

  List<OrderTemplate> get templates => _templates;

  Future<void> loadTemplates(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('order_templates')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      _templates =
          snapshot.docs.map((doc) => OrderTemplate.fromFirestore(doc)).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading templates: $e');
    }
  }

  Future<void> addTemplate(OrderTemplate template) async {
    try {
      await _firestore
          .collection('order_templates')
          .doc(template.id)
          .set(template.toFirestore());
      _templates.insert(0, template);
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding template: $e');
    }
  }

  Future<void> deleteTemplate(String templateId) async {
    try {
      await _firestore.collection('order_templates').doc(templateId).delete();
      _templates.removeWhere((t) => t.id == templateId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting template: $e');
    }
  }

  OrderTemplate? getTemplateByName(String name) {
    try {
      return _templates.firstWhere((t) => t.name == name);
    } catch (e) {
      return null;
    }
  }
}
