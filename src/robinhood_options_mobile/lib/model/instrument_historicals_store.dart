//import 'dart:collection';
import 'package:collection/collection.dart';

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
    var index = items.indexWhere((element) =>
        element.symbol == item.symbol &&
        element.span == item.span &&
        element.bounds == item.bounds &&
        element.interval == item.interval);
    if (index == -1) {
      _items.add(item);
      notifyListeners();
    } else {
      var current = _items[index];
      if (current.historicals.first.beginsAt!
                  .compareTo(item.historicals.first.beginsAt!) !=
              0 ||
          current.historicals.last.beginsAt!
                  .compareTo(item.historicals.last.beginsAt!) !=
              0) {
        // QuoteStore entry was added to the end, so check that the historical is newer.
        debugPrint(
            '${current.historicals.first.beginsAt} != ${item.historicals.first.beginsAt!}');
        debugPrint(
            '${current.historicals.last.beginsAt} != ${item.historicals.last.beginsAt!}');
        _items[index] = item;
        notifyListeners();
      } else {
        debugPrint('No updates for InstrumentHistoricals.');
      }
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
