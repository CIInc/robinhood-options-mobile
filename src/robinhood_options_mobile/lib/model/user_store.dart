import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:robinhood_options_mobile/model/robinhood_user.dart';

class UserStore extends ChangeNotifier {
  /// Internal, private state of the store.
  final List<RobinhoodUser> _items = [];

  /// An unmodifiable view of the items in the store.
  UnmodifiableListView<RobinhoodUser> get items => UnmodifiableListView(_items);

  /// The current total price of all items (assuming all items cost $42).
  //int get totalPrice => _items.length * 42;

  void add(RobinhoodUser item) {
    _items.add(item);
    // This call tells the widgets that are listening to this model to rebuild.
    notifyListeners();
  }

  void removeAll() {
    _items.clear();
    // This call tells the widgets that are listening to this model to rebuild.
    notifyListeners();
  }

  bool update(RobinhoodUser item) {
    var index = _items.indexWhere((element) =>
        element.userName == item.userName && element.source == item.source);
    if (index == -1) {
      return false;
    }
    _items[index] = item;
    notifyListeners();
    return true;
  }

  void addOrUpdate(RobinhoodUser item) {
    if (!update(item)) {
      add(item);
    }
  }

  void remove(RobinhoodUser item) {
    var index =
        _items.indexWhere((element) => element.userName == item.userName);
    if (index != -1) {
      _items.removeAt(index);
      notifyListeners();
    }
  }
}
