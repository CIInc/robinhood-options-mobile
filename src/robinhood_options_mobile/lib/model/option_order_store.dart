import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:robinhood_options_mobile/model/option_order.dart';

class OptionOrderStore extends ChangeNotifier {
  /// Internal, private state of the store.
  final List<OptionOrder> _items = [];

  /// An unmodifiable view of the items in the store.
  UnmodifiableListView<OptionOrder> get items => UnmodifiableListView(_items);

  /// The current total price of all items (assuming all items cost $42).
  //int get totalPrice => _items.length * 42;

  void add(OptionOrder item) {
    _items.add(item);
    // This call tells the widgets that are listening to this model to rebuild.
    notifyListeners();
  }

  void addAll(List<OptionOrder> items) {
    _items.addAll(items);
    notifyListeners();
  }

  void removeAll() {
    _items.clear();
    // This call tells the widgets that are listening to this model to rebuild.
    notifyListeners();
  }

  bool update(OptionOrder item) {
    var index = _items.indexWhere((element) => element.id == item.id);
    if (index == -1) {
      return false;
    }
    _items[index] = item;
    notifyListeners();
    return true;
  }

  void addOrUpdate(OptionOrder item) {
    if (!update(item)) {
      add(item);
    }
  }
}
