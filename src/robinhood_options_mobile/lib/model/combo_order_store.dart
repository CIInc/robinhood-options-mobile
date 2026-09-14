import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:robinhood_options_mobile/model/combo_order.dart';

class ComboOrderStore extends ChangeNotifier {
  final List<ComboOrder> _items = [];

  int get count => _items.length;

  UnmodifiableListView<ComboOrder> get items => UnmodifiableListView(_items);

  ComboOrder? findById(String id) {
    try {
      return _items.firstWhere((element) => element.id == id);
    } catch (_) {
      return null;
    }
  }

  List<ComboOrder> bySymbol(String symbol) {
    final upper = symbol.toUpperCase();
    return _items.where((e) => e.primarySymbol.toUpperCase() == upper).toList();
  }

  List<ComboOrder> get openOrders => _items.where((e) => e.isOpen).toList();

  List<ComboOrder> get completedOrders =>
      _items.where((e) => !e.isOpen).toList();

  void setItems(List<ComboOrder> items) {
    _items.clear();
    _items.addAll(items);
    notifyListeners();
  }

  void add(ComboOrder item) {
    _items.add(item);
    notifyListeners();
  }

  void addAll(List<ComboOrder> items) {
    _items.addAll(items);
    notifyListeners();
  }

  bool remove(String id) {
    final index = _items.indexWhere((element) => element.id == id);
    if (index != -1) {
      _items.removeAt(index);
      notifyListeners();
      return true;
    }
    return false;
  }

  void removeAll() {
    _items.clear();
    notifyListeners();
  }

  void clear() => removeAll();

  void removeWhere(bool Function(ComboOrder) test) {
    _items.removeWhere(test);
    notifyListeners();
  }

  bool update(ComboOrder item) {
    var index = _items.indexWhere((element) => element.id == item.id);
    if (index == -1) {
      return false;
    }
    _items[index] = item;
    notifyListeners();
    return true;
  }

  void addOrUpdate(ComboOrder item) {
    if (!update(item)) {
      add(item);
    }
  }
}
