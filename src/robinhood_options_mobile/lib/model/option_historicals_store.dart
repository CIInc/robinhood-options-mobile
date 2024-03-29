import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:robinhood_options_mobile/model/option_historicals.dart';

class OptionHistoricalsStore extends ChangeNotifier {
  /// Internal, private state of the store.
  final List<OptionHistoricals> _items = [];

  /// An unmodifiable view of the items in the store.
  UnmodifiableListView<OptionHistoricals> get items =>
      UnmodifiableListView(_items);

  /// The current total price of all items (assuming all items cost $42).
  //int get totalPrice => _items.length * 42;

  void add(OptionHistoricals item) {
    _items.add(item);
    // This call tells the widgets that are listening to this model to rebuild.
    notifyListeners();
  }

  void removeAll() {
    _items.clear();
    // This call tells the widgets that are listening to this model to rebuild.
    notifyListeners();
  }

  bool update(OptionHistoricals item) {
    var index = _items.indexWhere((element) =>
        element.legs.first.id == item.legs.first.id &&
        element.span == item.span &&
        element.bounds == item.bounds &&
        element.interval == item.interval);
    if (index == -1) {
      return false;
    }
    if (_items[0]
                .historicals
                .first
                .beginsAt!
                .compareTo(item.historicals.first.beginsAt!) !=
            0 ||
        _items[0]
                .historicals
                .last
                .beginsAt!
                .compareTo(item.historicals.last.beginsAt!) !=
            0) {
      _items[index] = item;
      notifyListeners();
    } else {
      debugPrint('No updates for OptionHistoricals.');
    }
    return true;
  }

  void addOrUpdate(OptionHistoricals item) {
    if (!update(item)) {
      add(item);
    }
  }
}
