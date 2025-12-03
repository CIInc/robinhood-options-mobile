import 'package:flutter/foundation.dart';
import 'package:robinhood_options_mobile/model/crypto_holding.dart';

class CryptoHoldingStore extends ChangeNotifier {
  final List<CryptoHolding> _items = [];

  List<CryptoHolding> get items => _items;

  void add(CryptoHolding item) {
    if (!_items.any((element) => element.id == item.id)) {
      _items.add(item);
      notifyListeners();
    }
  }

  void addOrUpdate(CryptoHolding item) {
    var index = _items.indexWhere((element) => element.id == item.id);
    if (index >= 0) {
      _items[index] = item;
    } else {
      _items.add(item);
    }
    notifyListeners();
  }

  void update(CryptoHolding item) {
    var index = _items.indexWhere((element) => element.id == item.id);
    if (index >= 0) {
      _items[index] = item;
      notifyListeners();
    }
  }

  void remove(CryptoHolding item) {
    _items.removeWhere((element) => element.id == item.id);
    notifyListeners();
  }

  void removeAll() {
    _items.clear();
    notifyListeners();
  }

  CryptoHolding? getById(String id) {
    try {
      return _items.firstWhere((element) => element.id == id);
    } catch (e) {
      return null;
    }
  }

  CryptoHolding? getByCurrencyCode(String currencyCode) {
    try {
      return _items.firstWhere((element) => element.currencyCode == currencyCode);
    } catch (e) {
      return null;
    }
  }

  double get totalMarketValue {
    return _items.fold(0.0, (sum, item) => sum + item.marketValue);
  }

  double get totalCost {
    return _items.fold(0.0, (sum, item) => sum + item.totalCost);
  }

  double get totalReturn {
    return totalMarketValue - totalCost;
  }

  double get totalReturnPercent {
    if (totalCost <= 0) {
      return 0.0;
    }
    return (totalReturn / totalCost) * 100;
  }
}
