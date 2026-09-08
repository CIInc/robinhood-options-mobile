import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/brokerage_user_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('BrokerageUserStore loads cached user on initialization', () async {
    final cachedUser = BrokerageUser(
      BrokerageSource.demo,
      'Test Demo User',
      null,
      null,
    );

    final storeToSave = BrokerageUserStore([cachedUser], 0);
    final userJson =
        jsonEncode(storeToSave.toJson(), toEncodable: Constants.toEncodable);

    SharedPreferences.setMockInitialValues({
      Constants.preferencesUserKey: userJson,
    });

    final store = BrokerageUserStore([], 0);
    expect(store.items, isEmpty);
    expect(store.currentUser, isNull);

    final loaded = await store.load();

    expect(loaded.length, 1);
    expect(store.items.length, 1);
    expect(store.currentUser, isNotNull);
    expect(store.currentUser!.userName, 'Test Demo User');
    expect(store.currentUser!.source, BrokerageSource.demo);
  });

  test('BrokerageUserStore handles empty cache gracefully without throwing',
      () async {
    SharedPreferences.setMockInitialValues({});

    final store = BrokerageUserStore([], 0);
    final loaded = await store.load();

    expect(loaded, isEmpty);
    expect(store.items, isEmpty);
    expect(store.currentUser, isNull);
  });
}
