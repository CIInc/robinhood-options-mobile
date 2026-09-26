import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/services/secure_token_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('migrates a legacy token before removing its preference value',
      () async {
    SharedPreferences.setMockInitialValues({'legacy_token': 'access-token'});
    final preferences = await SharedPreferences.getInstance();
    final secureStorage = _FakeSecureTokenStorage();

    final token = await migratePreferenceToSecureStorage(
      preferences: preferences,
      secureStorage: secureStorage,
      preferenceKey: 'legacy_token',
      secureKey: 'access.token',
    );

    expect(token, 'access-token');
    expect(await secureStorage.read(key: 'access.token'), 'access-token');
    expect(preferences.containsKey('legacy_token'), isFalse);
  });

  test('prefers the secure token and still deletes a stale preference value',
      () async {
    SharedPreferences.setMockInitialValues({'legacy_token': 'stale-token'});
    final preferences = await SharedPreferences.getInstance();
    final secureStorage = _FakeSecureTokenStorage()
      ..values['access.token'] = 'secure-token';

    final token = await migratePreferenceToSecureStorage(
      preferences: preferences,
      secureStorage: secureStorage,
      preferenceKey: 'legacy_token',
      secureKey: 'access.token',
    );

    expect(token, 'secure-token');
    expect(await secureStorage.read(key: 'access.token'), 'secure-token');
    expect(preferences.containsKey('legacy_token'), isFalse);
  });

  test('keeps the legacy value if secure migration fails', () async {
    SharedPreferences.setMockInitialValues({'legacy_token': 'access-token'});
    final preferences = await SharedPreferences.getInstance();
    final secureStorage = _FakeSecureTokenStorage()..failWrites = true;

    await expectLater(
      migratePreferenceToSecureStorage(
        preferences: preferences,
        secureStorage: secureStorage,
        preferenceKey: 'legacy_token',
        secureKey: 'access.token',
      ),
      throwsStateError,
    );

    expect(preferences.getString('legacy_token'), 'access-token');
  });

  test('deletes secure and legacy MCP tokens and connection metadata',
      () async {
    SharedPreferences.setMockInitialValues({
      'mcp_access_token': 'legacy-access-token',
      'mcp_refresh_token': 'legacy-refresh-token',
      'mcp_token_expiry_ms': 123,
      'mcp_client_id': 'client',
      'mcp_redirect_uri': 'redirect',
      'mcp_registration_endpoint': 'registration',
      'mcp_authorization_endpoint': 'authorization',
      'mcp_token_endpoint': 'token',
    });
    final preferences = await SharedPreferences.getInstance();
    final secureStorage = _FakeSecureTokenStorage()
      ..values['mcp.access_token'] = 'secure-access-token'
      ..values['mcp.refresh_token'] = 'secure-refresh-token';

    await deleteMcpTokens(secureStorage: secureStorage);

    expect(secureStorage.values, isEmpty);
    expect(preferences.getKeys(), isEmpty);
  });
}

class _FakeSecureTokenStorage implements SecureTokenStorage {
  final Map<String, String> values = {};
  bool failWrites = false;

  @override
  Future<void> delete({required String key}) async {
    values.remove(key);
  }

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    if (failWrites) throw StateError('secure write failed');
    values[key] = value;
  }
}
