import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccountStore extends ChangeNotifier {
  static const _selectedAccountPrefPrefix = 'selected_account_number';

  /// Internal, private state of the store.
  final List<Account> _items = [];
  String? _selectedAccountNumber;

  static String selectionStorageKey(
      {required String source, String? userName}) {
    final normalizedUser =
        (userName == null || userName.isEmpty) ? 'unknown' : userName;
    return '$_selectedAccountPrefPrefix::$source::$normalizedUser';
  }

  /// An unmodifiable view of the items in the store.
  UnmodifiableListView<Account> get items => UnmodifiableListView(_items);

  String? get selectedAccountNumber => _selectedAccountNumber;

  Account? get selectedAccount {
    if (_items.isEmpty) return null;
    if (_selectedAccountNumber != null) {
      try {
        return _items
            .firstWhere((a) => a.accountNumber == _selectedAccountNumber);
      } catch (_) {}
    }
    // Default to the first account when no explicit selection exists.
    return _items.first;
  }

  void setSelectedAccountNumber(String? accountNumber) {
    if (_selectedAccountNumber != accountNumber) {
      _selectedAccountNumber = accountNumber;
      notifyListeners();
    }
  }

  Future<void> saveSelectedAccountNumber(String storageKey) async {
    final prefs = await SharedPreferences.getInstance();
    if (_selectedAccountNumber == null || _selectedAccountNumber!.isEmpty) {
      await prefs.remove(storageKey);
      return;
    }
    await prefs.setString(storageKey, _selectedAccountNumber!);
  }

  Future<void> loadSelectedAccountNumber(String storageKey) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(storageKey);
    if (_selectedAccountNumber != stored) {
      _selectedAccountNumber = stored;
      notifyListeners();
    }
  }

  /// The current total price of all items (assuming all items cost $42).
  //int get totalPrice => _items.length * 42;

  void add(Account item) {
    _items.add(item);
    // This call tells the widgets that are listening to this model to rebuild.
    notifyListeners();
  }

  void removeAll() {
    _items.clear();
    _selectedAccountNumber = null;
    // This call tells the widgets that are listening to this model to rebuild.
    notifyListeners();
  }

  bool update(Account item) {
    var index = _items
        .indexWhere((element) => element.accountNumber == item.accountNumber);
    if (index == -1) {
      return false;
    }
    _items[index] = item;
    notifyListeners();
    return true;
  }

  void addOrUpdate(Account item) {
    if (!update(item)) {
      add(item);
    }
  }
}
