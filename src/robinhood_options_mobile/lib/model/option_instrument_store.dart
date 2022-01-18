import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';

class OptionInstrumentStore extends ChangeNotifier {
  /// Internal, private state of the store.
  final List<OptionInstrument> _items = [];

  /// An unmodifiable view of the items in the store.
  UnmodifiableListView<OptionInstrument> get items =>
      UnmodifiableListView(_items);

  /// The current total price of all items (assuming all items cost $42).
  //int get totalPrice => _items.length * 42;

  void add(OptionInstrument item) {
    _items.add(item);
    // This call tells the widgets that are listening to this model to rebuild.
    notifyListeners();
  }

  void removeAll() {
    _items.clear();
    // This call tells the widgets that are listening to this model to rebuild.
    notifyListeners();
  }

  bool update(OptionInstrument item) {
    var index = _items.indexWhere((element) => element.id == item.id);
    if (index == -1) {
      return false;
    }
    _items[index] = item;
    notifyListeners();
    return true;
  }

  void addOrUpdate(OptionInstrument item) {
    if (!update(item)) {
      add(item);
    }
  }
}
