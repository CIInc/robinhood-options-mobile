import 'dart:collection';

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
    if (items.isEmpty) {
      _items.add(item);
      notifyListeners();
    } else {
      if (_items[0]
                  .equityHistoricals
                  .first
                  .beginsAt!
                  .compareTo(item.equityHistoricals.first.beginsAt!) !=
              0 ||
          _items[0]
                  .equityHistoricals
                  .last
                  .beginsAt!
                  .compareTo(item.equityHistoricals.last.beginsAt!) !=
              0) {
        _items[0] = item;
        notifyListeners();
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
}
