//import 'dart:collection';
import 'package:collection/collection.dart';

import 'package:flutter/foundation.dart';
import 'package:robinhood_options_mobile/model/equity_historical.dart';
import 'package:robinhood_options_mobile/model/portfolio_historicals.dart';

class PortfolioHistoricalsStore extends ChangeNotifier {
  /// Internal, private state of the store.
  final List<PortfolioHistoricals> _items = [];
  EquityHistorical? selection;

  /// An unmodifiable view of the items in the store.
  UnmodifiableListView<PortfolioHistoricals> get items =>
      UnmodifiableListView(_items);

  /// The current total price of all items (assuming all items cost $42).
  //int get totalPrice => _items.length * 42;

  void set(PortfolioHistoricals item) {
    var index = _items.indexWhere((element) =>
        element.span == item.span &&
        element.bounds == item.bounds &&
        element.interval == item.interval);
    if (index == -1) {
      _items.add(item);
      notifyListeners();
    } else {
      var current = _items[index];
      if (current.equityHistoricals.first.beginsAt!
                  .compareTo(item.equityHistoricals.first.beginsAt!) !=
              0 ||
          current.equityHistoricals.last.beginsAt!
                  .compareTo(item.equityHistoricals.last.beginsAt!) !=
              0) {
        debugPrint(
            '${current.equityHistoricals.first.beginsAt} != ${item.equityHistoricals.first.beginsAt!}');
        debugPrint(
            '${current.equityHistoricals.last.beginsAt} != ${item.equityHistoricals.last.beginsAt!}');
        //_items.clear();
        //_items.add(item);
        _items[index] = item;
        notifyListeners();
      } else {
        debugPrint('No updates for PortfolioHistoricals.');
      }
    }
  }

  void add(PortfolioHistoricals item) {
    _items.add(item);
    // This call tells the widgets that are listening to this model to rebuild.
    notifyListeners();
  }

  void removeAll() {
    _items.clear();
    // This call tells the widgets that are listening to this model to rebuild.
    notifyListeners();
  }

  bool update(PortfolioHistoricals item) {
    var index = _items.indexWhere((element) =>
        element.span == item.span && element.bounds == item.bounds);
    if (index == -1) {
      return false;
    }
    _items[index] = item;
    notifyListeners();
    return true;
  }

  void addOrUpdate(PortfolioHistoricals item) {
    if (!update(item)) {
      add(item);
    }
  }

  void notify() {
    notifyListeners();
  }
}
