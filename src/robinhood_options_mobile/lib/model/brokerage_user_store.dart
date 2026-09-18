import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BrokerageUserStore extends ChangeNotifier {
  int currentUserIndex = 0;
  bool aggregateAllAccounts = false;

  /// Internal, private state of the store.
  final List<BrokerageUser> _items;

  /// An unmodifiable view of the items in the store.
  UnmodifiableListView<BrokerageUser> get items => UnmodifiableListView(_items);

  /// The current total price of all items (assuming all items cost $42).
  //int get totalPrice => _items.length * 42;

  BrokerageUserStore(this._items, this.currentUserIndex,
      {this.aggregateAllAccounts = false});

  void add(BrokerageUser item) {
    _items.add(item);
    // This call tells the widgets that are listening to this model to rebuild.
    notifyListeners();
  }

  void removeAll() {
    _items.clear();
    // This call tells the widgets that are listening to this model to rebuild.
    notifyListeners();
  }

  bool update(BrokerageUser item) {
    var index = _items.indexWhere((element) =>
        element.userName == item.userName && element.source == item.source);
    if (index == -1) {
      return false;
    }
    _items[index] = item;
    notifyListeners();
    return true;
  }

  void addOrUpdate(BrokerageUser item) {
    if (!update(item)) {
      add(item);
    }
  }

  void remove(BrokerageUser item) {
    var index =
        _items.indexWhere((element) => element.userName == item.userName);
    if (index != -1) {
      _items.removeAt(index);
      notifyListeners();
    }
  }

  BrokerageUser? get currentUser =>
      _items.isNotEmpty && currentUserIndex < _items.length
          ? _items[currentUserIndex]
          : null;

  void setCurrentUserIndex(int userIndex) {
    currentUserIndex = userIndex;
    notifyListeners();
  }

  void setAggregateAllAccounts(bool enabled) {
    if (aggregateAllAccounts != enabled) {
      aggregateAllAccounts = enabled;
      notifyListeners();
    }
  }

  BrokerageUserStore.fromJson(Map<String, dynamic> json)
      : currentUserIndex = json['currentUserIndex'],
        aggregateAllAccounts = json['aggregateAllAccounts'] ?? false,
        _items = BrokerageUser.fromJsonArray(json['users']);

  Map<String, dynamic> toJson() {
    return {
      'currentUserIndex': currentUserIndex,
      'aggregateAllAccounts': aggregateAllAccounts,
      'users': items.map((e) => e.toJson()).toList(),
    };
  }

  Future save() async {
    var contents = jsonEncode(toJson(), toEncodable: Constants.toEncodable);
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(Constants.preferencesUserKey, contents);
  }

  Future<List<BrokerageUser>> load() async {
    // await Store.deleteFile(Constants.cacheFilename);
    debugPrint('Loading cache.');

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? contents = prefs.getString(Constants.preferencesUserKey);
    //String? contents = await Store.readFile(Constants.cacheFilename);
    if (contents == null) {
      debugPrint('No cache file found.');
      return [];
    }
    try {
      var storeData = jsonDecode(contents);
      if (storeData is Map<String, dynamic>) {
        var userStore = BrokerageUserStore.fromJson(storeData);
        _items.clear();
        currentUserIndex = userStore.currentUserIndex;
        aggregateAllAccounts = userStore.aggregateAllAccounts;
        _items.addAll(userStore.items);
        notifyListeners();
      }
      return items;
    } catch (e, stackTrace) {
      debugPrint('Error loading brokerage user store: $e\n$stackTrace');
      return [];
    }
  }
}
