import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';

class OptionPositionStore extends ChangeNotifier {
  /// Internal, private state of the store.
  final List<OptionAggregatePosition> _items = [];

  /// An unmodifiable view of the items in the store.
  UnmodifiableListView<OptionAggregatePosition> get items =>
      UnmodifiableListView(_items);

  double get equity => _items.isNotEmpty
      ? _items
          .map((e) => e.marketValue)
          /*
              e.legs.first.positionType == "long"
              ? e.marketValue
              : e.marketValue)
              */
          .reduce((a, b) => a + b)
      : 0;

  List<String> get symbols => _items.map((e) => e.symbol).toSet().toList();

  void add(OptionAggregatePosition item) {
    _items.add(item);
    // This call tells the widgets that are listening to this model to rebuild.
    notifyListeners();
  }

  void removeAll() {
    _items.clear();
    // This call tells the widgets that are listening to this model to rebuild.
    notifyListeners();
  }

  bool update(OptionAggregatePosition item) {
    var index = _items.indexWhere((element) => element.id == item.id);
    if (index == -1) {
      return false;
    }
    _items[index] = item;
    notifyListeners();
    return true;
  }

  void addOrUpdate(OptionAggregatePosition item) {
    if (!update(item)) {
      add(item);
    }
  }

  void sort() {
    _items.sort((a, b) {
      int comp =
          a.legs.first.expirationDate!.compareTo(b.legs.first.expirationDate!);
      if (comp != 0) return comp;
      return a.legs.first.strikePrice!.compareTo(b.legs.first.strikePrice!);
    });
  }
}
