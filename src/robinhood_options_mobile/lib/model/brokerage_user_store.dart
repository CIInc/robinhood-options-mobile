import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/services/secure_token_storage.dart';
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

  final SecureTokenStorage _secureTokenStorage;

  BrokerageUserStore(this._items, this.currentUserIndex,
      {this.aggregateAllAccounts = false,
      SecureTokenStorage? secureTokenStorage})
      : _secureTokenStorage =
            secureTokenStorage ?? PlatformSecureTokenStorage();

  void add(BrokerageUser item) {
    _items.add(item);
    // This call tells the widgets that are listening to this model to rebuild.
    notifyListeners();
  }

  Future<void> removeAll() async {
    for (final item in _items) {
      await item.deleteCredentials();
    }
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
    final existingUser = _items[index];
    item.secureCredentialsKey = existingUser.secureCredentialsKey;
    if (item.credentials == null || item.credentials!.isEmpty) {
      item.credentials = existingUser.credentials;
    }
    item.ensureOAuth2Client();
    _items[index] = item;
    notifyListeners();
    return true;
  }

  void addOrUpdate(BrokerageUser item) {
    if (!update(item)) {
      add(item);
    }
  }

  Future<void> remove(BrokerageUser item) async {
    var index = _items.indexWhere((element) =>
        element.userName == item.userName && element.source == item.source);
    if (index != -1) {
      final user = _items[index];
      await user.deleteCredentials();
      _items.removeAt(index);
      notifyListeners();
    }
  }

  Future<bool> migrateLegacyCloudCredentials(
      Iterable<BrokerageUser> cloudUsers) async {
    final legacyUsers = cloudUsers
        .where((user) => user.credentials?.isNotEmpty == true)
        .toList();
    if (legacyUsers.isEmpty) return false;

    var changed = false;
    for (final cloudUser in legacyUsers) {
      final index = _items.indexWhere((localUser) =>
          localUser.userName == cloudUser.userName &&
          localUser.source == cloudUser.source);
      if (index == -1) {
        _items.add(cloudUser);
        changed = true;
      } else {
        final localUser = _items[index];
        if (localUser.credentials == null || localUser.credentials!.isEmpty) {
          localUser.credentials = cloudUser.credentials;
          changed = true;
        }
      }
    }

    if (changed) notifyListeners();
    await save();
    return true;
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
        _items = BrokerageUser.fromJsonArray(json['users']),
        _secureTokenStorage = PlatformSecureTokenStorage();

  Map<String, dynamic> toJson() {
    return {
      'currentUserIndex': currentUserIndex,
      'aggregateAllAccounts': aggregateAllAccounts,
      'users': items.map((e) => e.toJson()).toList(),
    };
  }

  Future<void> save() async {
    for (final user in _items) {
      await user.persistCredentials();
    }
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
    dynamic storeData;
    try {
      storeData = jsonDecode(contents);
    } catch (e, stackTrace) {
      debugPrint('Error loading brokerage user store: $e\n$stackTrace');
      return [];
    }
    if (storeData is! Map<String, dynamic> || storeData['users'] is! List) {
      debugPrint('Brokerage user cache has an unexpected format.');
      return [];
    }

    final loadedUsers = <BrokerageUser>[];
    try {
      for (final rawUser in storeData['users'] as List) {
        if (rawUser is! Map) {
          throw const FormatException('Invalid brokerage user record.');
        }
        final rawKey = rawUser['secureCredentialsKey'];
        final user = BrokerageUser.fromJson(
          Map<String, dynamic>.from(rawUser),
          secureTokenStorage: _secureTokenStorage,
        );
        if (user.credentials == null || user.credentials!.isEmpty) {
          if (rawKey is String && rawKey.isNotEmpty) {
            user.credentials = await _secureTokenStorage.read(key: rawKey);
          }
        } else {
          await user.persistCredentials();
        }
        user.ensureOAuth2Client();
        loadedUsers.add(user);
      }
    } catch (e, stackTrace) {
      debugPrint(
          'Could not securely load brokerage credentials: $e\n$stackTrace');
      rethrow;
    }

    _items
      ..clear()
      ..addAll(loadedUsers);
    currentUserIndex = storeData['currentUserIndex'] is int
        ? storeData['currentUserIndex'] as int
        : 0;
    aggregateAllAccounts = storeData['aggregateAllAccounts'] == true;
    notifyListeners();

    // Always rewrite the cache to remove any legacy plaintext credential fields.
    await save();
    return items;
  }
}
