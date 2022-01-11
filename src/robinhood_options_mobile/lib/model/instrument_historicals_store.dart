import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:robinhood_options_mobile/model/instrument_historical.dart';
import 'package:robinhood_options_mobile/model/instrument_historicals.dart';

class InstrumentHistoricalsStore extends ChangeNotifier {
  /// Internal, private state of the store.
  final List<InstrumentHistoricals> _items = [];
  InstrumentHistorical? selection;

  /// An unmodifiable view of the items in the store.
  UnmodifiableListView<InstrumentHistoricals> get items =>
      UnmodifiableListView(_items);

  /// The current total price of all items (assuming all items cost $42).
  //int get totalPrice => _items.length * 42;

  void set(InstrumentHistoricals item) {
    if (items.isEmpty) {
      _items.add(item);
      notifyListeners();
    } else {
      if (_items[0].historicals.first.beginsAt !=
          item.historicals.first.beginsAt) {
        _items[0] = item;
        notifyListeners();
      }
    }
  }

  void select(InstrumentHistoricals historical) {
    if (selection != historical) {
      selection = historical as InstrumentHistorical?;
      notifyListeners();
    }
  }

  void add(InstrumentHistoricals item) {
    _items.add(item);
    // This call tells the widgets that are listening to this model to rebuild.
    notifyListeners();
  }

  void removeAll() {
    _items.clear();
    // This call tells the widgets that are listening to this model to rebuild.
    notifyListeners();
  }

  bool update(InstrumentHistoricals item) {
    var index = _items.indexWhere((element) =>
        element.span == item.span && element.bounds == item.bounds);
    if (index == -1) {
      return false;
    }
    _items[index] = item;
    notifyListeners();
    return true;
  }

  void addOrUpdate(InstrumentHistoricals item) {
    if (!update(item)) {
      add(item);
    }
  }
}
