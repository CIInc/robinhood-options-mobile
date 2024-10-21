import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:oauth2/oauth2.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BrokerageUserStore extends ChangeNotifier {
  int currentUserIndex = 0;

  /// Internal, private state of the store.
  final List<BrokerageUser> _items = [];

  /// An unmodifiable view of the items in the store.
  UnmodifiableListView<BrokerageUser> get items => UnmodifiableListView(_items);

  /// The current total price of all items (assuming all items cost $42).
  //int get totalPrice => _items.length * 42;

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

  BrokerageUser get currentUser =>
      currentUserIndex >= 0 && currentUserIndex < _items.length
          ? _items[currentUserIndex]
          : _items[0];

  void setCurrentUserIndex(int userIndex) {
    currentUserIndex = userIndex;
    notifyListeners();
  }

  Future save() async {
    var contents = jsonEncode(items);
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
      removeAll();
      var users = jsonDecode(contents) as List<dynamic>;
      for (Map<String, dynamic> userMap in users) {
        var user = BrokerageUser.fromJson(userMap);
        if (user.credentials != null) {
          var credentials = Credentials.fromJson(user.credentials as String);
          var client = Client(credentials, identifier: Constants.rhClientId);
          user.oauth2Client = client;
        }
        debugPrint('Loaded cache.');
        add(user);
      }
      return items;
    } on FormatException catch (e) {
      debugPrint(
          'Cache provided is not valid JSON.\nError: $e\nContents: $contents');
      return [];
    }
  }
}
