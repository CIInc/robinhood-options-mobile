import 'package:flutter/foundation.dart';
import 'package:robinhood_options_mobile/model/crypto_order.dart';

class CryptoOrderStore extends ChangeNotifier {
  final List<CryptoOrder> _items = [];

  List<CryptoOrder> get items => _items;

  void add(CryptoOrder item) {
    if (!_items.any((element) => element.id == item.id)) {
      _items.add(item);
      notifyListeners();
    }
  }

  void addOrUpdate(CryptoOrder item) {
    var index = _items.indexWhere((element) => element.id == item.id);
    if (index >= 0) {
      _items[index] = item;
    } else {
      _items.add(item);
    }
    notifyListeners();
  }

  void update(CryptoOrder item) {
    var index = _items.indexWhere((element) => element.id == item.id);
    if (index >= 0) {
      _items[index] = item;
      notifyListeners();
    }
  }

  void remove(CryptoOrder item) {
    _items.removeWhere((element) => element.id == item.id);
    notifyListeners();
  }

  void removeAll() {
    _items.clear();
    notifyListeners();
  }

  CryptoOrder? getById(String id) {
    try {
      return _items.firstWhere((element) => element.id == id);
    } catch (e) {
      return null;
    }
  }

  List<CryptoOrder> getFilledOrders() {
    return _items.where((element) => element.isFilled).toList();
  }

  List<CryptoOrder> getPendingOrders() {
    return _items.where((element) => element.isPending).toList();
  }

  List<CryptoOrder> getCancelledOrders() {
    return _items.where((element) => element.isCancelled).toList();
  }
}
