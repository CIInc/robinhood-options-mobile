import 'dart:collection';

import 'package:flutter/foundation.dart';

/// A simple ChangeNotifier store for futures positions. The items are kept as
/// dynamic objects because the API returns varying shapes for aggregated
/// futures positions.
class FuturesPositionStore extends ChangeNotifier {
  final List<dynamic> _items = [];

  UnmodifiableListView<dynamic> get items => UnmodifiableListView(_items);

  double get equity => _items.isNotEmpty
      ? _items.fold(0.0, (double acc, e) {
          if (e is Map) {
            var q = 0.0;
            var p = 0.0;
            if (e.containsKey('quantity')) {
              q = double.tryParse(e['quantity'].toString()) ?? 0.0;
            }
            if (e.containsKey('avgTradePrice')) {
              p = double.tryParse(e['avgTradePrice'].toString()) ?? 0.0;
            }
            return acc + (q * p);
          }
          return acc;
        })
      : 0.0;

  List<String> get symbols => _items
      .where((element) => element is Map && element.containsKey('contractId'))
      .map((e) => e['contractId'].toString())
      .toSet()
      .toList();

  void add(dynamic item) {
    _items.add(item);
    notifyListeners();
  }

  void addAll(List<dynamic> items) {
    _items.addAll(items);
    notifyListeners();
  }

  void removeAll() {
    _items.clear();
    notifyListeners();
  }
}
