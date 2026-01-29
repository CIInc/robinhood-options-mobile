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
          if (e is Map && e['openPnlCalc'] != null) {
            return acc + (double.tryParse(e['openPnlCalc'].toString()) ?? 0.0);
          }
          return acc;
        })
      : 0.0;

  double get totalOpenPnl => _items.isNotEmpty
      ? _items.fold(0.0, (double acc, e) {
          if (e is Map && e['openPnlCalc'] != null) {
            return acc + (double.tryParse(e['openPnlCalc'].toString()) ?? 0.0);
          }
          return acc;
        })
      : 0.0;

  double get totalDayPnl => _items.isNotEmpty
      ? _items.fold(0.0, (double acc, e) {
          if (e is Map && e['dayPnlCalc'] != null) {
            return acc + (double.tryParse(e['dayPnlCalc'].toString()) ?? 0.0);
          }
          return acc;
        })
      : 0.0;

  double get totalNotional => _items.isNotEmpty
      ? _items.fold(0.0, (double acc, e) {
          if (e is Map && e['notionalValue'] != null) {
            return acc +
                (double.tryParse(e['notionalValue'].toString()) ?? 0.0);
          }
          return acc;
        })
      : 0.0;

  Map<String, double> get notionalDistribution {
    var distribution = <String, double>{};
    for (var position in _items) {
      if (position is Map) {
        String symbol = position['contractId']?.toString() ?? 'Other';
        // Try to find a better symbol
        if (position['contract'] != null) {
          symbol = position['contract']['rootSymbol'] ??
              position['contract']['symbol'] ??
              symbol;
        } else if (position['product'] != null) {
          symbol = position['product']['symbol'] ?? symbol;
        }

        double notional = 0;
        if (position['notionalValue'] != null) {
          notional = double.tryParse(position['notionalValue'].toString()) ?? 0;
        }
        distribution[symbol] = (distribution[symbol] ?? 0) + notional.abs();
      }
    }
    return distribution;
  }

  List<String> get symbols => _items
      .where((element) => element is Map && element.containsKey('contractId'))
      .map((e) => e['contractId'].toString())
      .toSet()
      .toList();

  void set(List<dynamic> items) {
    _items.clear();
    _items.addAll(items);
    notifyListeners();
  }

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
