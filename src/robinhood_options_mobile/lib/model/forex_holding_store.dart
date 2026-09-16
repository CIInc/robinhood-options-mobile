import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:robinhood_options_mobile/model/forex_holding.dart';

class ForexHoldingStore extends ChangeNotifier {
  /// Internal, private state of the store.
  final List<ForexHolding> _items = [];
  bool _isLoading = false;

  /// An unmodifiable view of the items in the store.
  UnmodifiableListView<ForexHolding> get items => UnmodifiableListView(_items);

  bool get isLoading => _isLoading;

  void setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      // Defer notification to avoid errors during build phase
      Future.microtask(() => notifyListeners());
    }
  }

  double get equity => _items.isNotEmpty
      ? _items.map((e) => e.marketValue).reduce((a, b) => a + b)
      : 0;

  void add(ForexHolding item) {
    _items.add(item);
    // This call tells the widgets that are listening to this model to rebuild.
    notifyListeners();
  }

  void removeAll() {
    _items.clear();
    // This call tells the widgets that are listening to this model to rebuild.
    notifyListeners();
  }

  bool update(ForexHolding item) {
    var index = _items
        .indexWhere((element) => element.currencyCode == item.currencyCode);
    if (index == -1) {
      return false;
    }
    _items[index] = item;
    notifyListeners();
    return true;
  }

  void addOrUpdate(ForexHolding item) {
    if (!update(item)) {
      add(item);
    }
  }
}
