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
    if (item.legs.isEmpty) {
      return false;
    }
    var index = _items.indexWhere((element) =>
        element.legs.isNotEmpty &&
        element.legs.first.id == item.legs.first.id &&
        element.span == item.span &&
        element.bounds == item.bounds &&
        element.interval == item.interval);
    if (index == -1) {
      return false;
    }
    var current = _items[index];
    bool isDifferent = false;
    if (current.historicals.isEmpty || item.historicals.isEmpty) {
      isDifferent = current.historicals.length != item.historicals.length;
    } else {
      final currentFirst = current.historicals.first.beginsAt;
      final itemFirst = item.historicals.first.beginsAt;
      final currentLast = current.historicals.last.beginsAt;
      final itemLast = item.historicals.last.beginsAt;

      isDifferent = (currentFirst == null ||
              itemFirst == null ||
              currentFirst.compareTo(itemFirst) != 0) ||
          (currentLast == null ||
              itemLast == null ||
              currentLast.compareTo(itemLast) != 0);
    }

    if (isDifferent) {
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
