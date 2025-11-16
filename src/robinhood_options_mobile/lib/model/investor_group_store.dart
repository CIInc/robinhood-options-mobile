import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/model/investor_group.dart';

class InvestorGroupStore with ChangeNotifier {
  final List<InvestorGroup> _items = [];

  List<InvestorGroup> get items => _items;

  void setItems(List<InvestorGroup> groups) {
    _items.clear();
    _items.addAll(groups);
    notifyListeners();
  }

  void addItem(InvestorGroup group) {
    _items.add(group);
    notifyListeners();
  }

  void updateItem(InvestorGroup group) {
    final index = _items.indexWhere((item) => item.id == group.id);
    if (index != -1) {
      _items[index] = group;
      notifyListeners();
    }
  }

  void removeItem(String groupId) {
    _items.removeWhere((item) => item.id == groupId);
    notifyListeners();
  }

  InvestorGroup? getById(String groupId) {
    try {
      return _items.firstWhere((item) => item.id == groupId);
    } catch (e) {
      return null;
    }
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}
