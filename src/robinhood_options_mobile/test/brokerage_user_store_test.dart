import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/brokerage_user_store.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/secure_token_storage.dart';
import 'package:oauth2/oauth2.dart' as oauth2;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('BrokerageUserStore loads cached user on initialization', () async {
    SharedPreferences.setMockInitialValues({
      Constants.preferencesUserKey: jsonEncode({
        'currentUserIndex': 0,
        'users': [
          {
            'source': 'BrokerageSource.demo',
            'userName': 'Test Demo User',
          }
        ],
      }),
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

  test('migrates legacy brokerage credentials into secure storage', () async {
    final legacyCredentials = oauth2.Credentials(
      'legacy-access-token',
      refreshToken: 'legacy-refresh-token',
      expiration: DateTime.now().add(const Duration(hours: 1)),
    ).toJson();
    SharedPreferences.setMockInitialValues({
      Constants.preferencesUserKey: jsonEncode({
        'currentUserIndex': 0,
        'users': [
          {
            'source': 'BrokerageSource.demo',
            'userName': 'legacy-user',
            'credentials': legacyCredentials,
          }
        ],
      }),
    });
    final secureStorage = _FakeSecureTokenStorage();
    final store = BrokerageUserStore(
      [],
      0,
      secureTokenStorage: secureStorage,
    );

    final loaded = await store.load();
    final user = loaded.single;
    final preferences = await SharedPreferences.getInstance();
    final savedData =
        jsonDecode(preferences.getString(Constants.preferencesUserKey)!)
            as Map<String, dynamic>;
    final savedUser = (savedData['users'] as List).single as Map;

    expect(user.credentials, legacyCredentials);
    expect(
      await secureStorage.read(key: user.secureCredentialsKey),
      legacyCredentials,
    );
    expect(savedUser.containsKey('credentials'), isFalse);
    expect(savedUser['secureCredentialsKey'], user.secureCredentialsKey);

    final reloaded = BrokerageUserStore(
      [],
      0,
      secureTokenStorage: secureStorage,
    );
    expect((await reloaded.load()).single.credentials, legacyCredentials);
  });

  test('removing a brokerage account securely deletes its credentials',
      () async {
    SharedPreferences.setMockInitialValues({});
    final secureStorage = _FakeSecureTokenStorage();
    final credentials = oauth2.Credentials(
      'active-access-token',
      refreshToken: 'active-refresh-token',
    ).toJson();
    final user = BrokerageUser(
      BrokerageSource.robinhood,
      'active-user',
      credentials,
      null,
      secureTokenStorage: secureStorage,
    );
    final store = BrokerageUserStore(
      [user],
      0,
      secureTokenStorage: secureStorage,
    );
    await store.save();
    expect(
        await secureStorage.read(key: user.secureCredentialsKey), credentials);

    await store.remove(user);
    await store.save();

    expect(await secureStorage.read(key: user.secureCredentialsKey), isNull);
    expect(store.items, isEmpty);
  });

  test('updating brokerage metadata preserves the secure credential key',
      () async {
    SharedPreferences.setMockInitialValues({});
    final secureStorage = _FakeSecureTokenStorage();
    final credentials = oauth2.Credentials('existing-token').toJson();
    final originalUser = BrokerageUser(
      BrokerageSource.demo,
      'same-user',
      credentials,
      null,
      secureTokenStorage: secureStorage,
    );
    final store = BrokerageUserStore(
      [originalUser],
      0,
      secureTokenStorage: secureStorage,
    );
    await store.save();
    final replacementUser = BrokerageUser(
      BrokerageSource.demo,
      'same-user',
      null,
      null,
      secureTokenStorage: secureStorage,
    );
    expect(store.update(replacementUser), isTrue);
    await store.save();

    expect(replacementUser.secureCredentialsKey,
        originalUser.secureCredentialsKey);
    expect(replacementUser.credentials, credentials);
    expect(
      await secureStorage.read(key: originalUser.secureCredentialsKey),
      credentials,
    );
  });

  test('credential deletion waits for an in-flight refresh write', () async {
    final secureStorage = _FakeSecureTokenStorage()
      ..writeStarted = Completer<void>()
      ..releaseWrite = Completer<void>();
    final user = BrokerageUser(
      BrokerageSource.robinhood,
      'refreshing-user',
      null,
      null,
      secureTokenStorage: secureStorage,
    );
    user.updateCredentials(
      oauth2.Credentials(
        'refreshed-access-token',
        refreshToken: 'refreshed-refresh-token',
      ),
    );
    await secureStorage.writeStarted!.future;

    var deletionComplete = false;
    final deletion = user.deleteCredentials().then((_) {
      deletionComplete = true;
    });
    await Future<void>.delayed(Duration.zero);
    expect(deletionComplete, isFalse);

    secureStorage.releaseWrite!.complete();
    await deletion;

    expect(user.credentials, isNull);
    expect(
      await secureStorage.read(key: user.secureCredentialsKey),
      isNull,
    );
  });

  test('clearing the brokerage user store deletes every secure credential',
      () async {
    SharedPreferences.setMockInitialValues({});
    final secureStorage = _FakeSecureTokenStorage();
    final users = [
      BrokerageUser(
        BrokerageSource.robinhood,
        'first-user',
        '{"accessToken":"first-token"}',
        null,
        secureTokenStorage: secureStorage,
      ),
      BrokerageUser(
        BrokerageSource.schwab,
        'second-user',
        '{"accessToken":"second-token"}',
        null,
        secureTokenStorage: secureStorage,
      ),
    ];
    final store = BrokerageUserStore(
      users,
      0,
      secureTokenStorage: secureStorage,
    );
    await store.save();

    await store.removeAll();
    await store.save();

    expect(store.items, isEmpty);
    for (final user in users) {
      expect(user.credentials, isNull);
      expect(
        await secureStorage.read(key: user.secureCredentialsKey),
        isNull,
      );
    }
  });

  test('migrates legacy Firestore credentials into the local secure store',
      () async {
    SharedPreferences.setMockInitialValues({});
    final secureStorage = _FakeSecureTokenStorage();
    const remoteRobinhoodCredentials = '{"accessToken":"remote-rh-token"}';
    const remoteSchwabCredentials = '{"accessToken":"remote-schwab-token"}';
    final localRobinhoodUser = BrokerageUser(
      BrokerageSource.robinhood,
      'same-user',
      null,
      null,
      secureTokenStorage: secureStorage,
    );
    final cloudRobinhoodUser = BrokerageUser(
      BrokerageSource.robinhood,
      'same-user',
      remoteRobinhoodCredentials,
      null,
      secureTokenStorage: secureStorage,
    );
    final cloudSchwabUser = BrokerageUser(
      BrokerageSource.schwab,
      'remote-user',
      remoteSchwabCredentials,
      null,
      secureTokenStorage: secureStorage,
    );
    final store = BrokerageUserStore(
      [localRobinhoodUser],
      0,
      secureTokenStorage: secureStorage,
    );

    expect(
      await store.migrateLegacyCloudCredentials(
        [cloudRobinhoodUser, cloudSchwabUser],
      ),
      isTrue,
    );

    expect(store.items, hasLength(2));
    expect(localRobinhoodUser.credentials, remoteRobinhoodCredentials);
    expect(
      await secureStorage.read(key: localRobinhoodUser.secureCredentialsKey),
      remoteRobinhoodCredentials,
    );
    final importedSchwabUser = store.items.singleWhere(
      (user) => user.source == BrokerageSource.schwab,
    );
    expect(
      await secureStorage.read(key: importedSchwabUser.secureCredentialsKey),
      remoteSchwabCredentials,
    );
  });

  test(
      'brokerage credentials and local storage keys are not serialized to Firestore',
      () {
    final brokerageUser = BrokerageUser(
      BrokerageSource.robinhood,
      'private-user',
      '{"accessToken":"private-access-token"}',
      null,
      secureCredentialsKey: 'local-key-reference',
    );
    final user = User(
      devices: [],
      dateCreated: DateTime.now(),
      brokerageUsers: [brokerageUser],
    );

    final persistedBrokerageUser =
        (user.toJson()['brokerageUsers'] as List).single as Map;
    expect(persistedBrokerageUser.containsKey('credentials'), isFalse);
    expect(persistedBrokerageUser.containsKey('secureCredentialsKey'), isFalse);
    expect(
      jsonEncode(persistedBrokerageUser),
      isNot(contains('private-access-token')),
    );
  });
}

class _FakeSecureTokenStorage implements SecureTokenStorage {
  final Map<String, String> values = {};
  Completer<void>? writeStarted;
  Completer<void>? releaseWrite;

  @override
  Future<void> delete({required String key}) async {
    values.remove(key);
  }

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
    if (writeStarted != null && !writeStarted!.isCompleted) {
      writeStarted!.complete();
    }
    if (releaseWrite != null) await releaseWrite!.future;
  }
}
