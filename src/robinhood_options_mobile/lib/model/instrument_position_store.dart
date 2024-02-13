import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';

class InstrumentPositionStore extends ChangeNotifier {
  /// Internal, private state of the store.
  final List<InstrumentPosition> _items = [];

  /// An unmodifiable view of the items in the store.
  UnmodifiableListView<InstrumentPosition> get items => UnmodifiableListView(_items);

  double get equity => _items.isNotEmpty
      ? _items.map((e) => e.marketValue).reduce((a, b) => a + b)
      : 0;

  List<String> get symbols => _items
      .where((element) => element.instrumentObj != null)
      .map((e) => e.instrumentObj!.symbol)
      .toSet()
      .toList();

  void add(InstrumentPosition item) {
    _items.add(item);
    // This call tells the widgets that are listening to this model to rebuild.
    notifyListeners();
  }

  void removeAll() {
    _items.clear();
    // This call tells the widgets that are listening to this model to rebuild.
    notifyListeners();
  }

  bool update(InstrumentPosition item) {
    var index = _items.indexWhere((element) =>
        //element.url == item.url);
        //element.instrument == item.instrument);
        element.instrumentId == item.instrumentId);
    if (index == -1) {
      return false;
    }
    _items[index] = item;
    notifyListeners();
    return true;
  }

  void addOrUpdate(InstrumentPosition item) {
    if (!update(item)) {
      add(item);
    }
  }
}
