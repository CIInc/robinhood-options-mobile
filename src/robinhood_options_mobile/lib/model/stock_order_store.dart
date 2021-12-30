import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:robinhood_options_mobile/model/stock_order.dart';

class StockOrderStore extends ChangeNotifier {
  /// Internal, private state of the store.
  final List<StockOrder> _items = [];

  /// An unmodifiable view of the items in the store.
  UnmodifiableListView<StockOrder> get items => UnmodifiableListView(_items);

  /// The current total price of all items (assuming all items cost $42).
  //int get totalPrice => _items.length * 42;

  void add(StockOrder item) {
    _items.add(item);
    // This call tells the widgets that are listening to this model to rebuild.
    notifyListeners();
  }

  void removeAll() {
    _items.clear();
    // This call tells the widgets that are listening to this model to rebuild.
    notifyListeners();
  }

  bool update(StockOrder item) {
    var index =
        _items.indexWhere((element) => element.instrument == item.instrument);
    if (index == -1) {
      return false;
    }
    _items[index] = item;
    notifyListeners();
    return true;
  }

  void addOrUpdate(StockOrder item) {
    if (!update(item)) {
      add(item);
    }
  }
}
