import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class SecureTokenStorage {
  Future<String?> read({required String key});

  Future<void> write({required String key, required String value});

  Future<void> delete({required String key});
}

class PlatformSecureTokenStorage implements SecureTokenStorage {
  PlatformSecureTokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> write({required String key, required String value}) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete({required String key}) => _storage.delete(key: key);
}

Future<String?> migratePreferenceToSecureStorage({
  required SharedPreferences preferences,
  required SecureTokenStorage secureStorage,
  required String preferenceKey,
  required String secureKey,
}) async {
  final legacyValue = preferences.getString(preferenceKey);
  final secureValue = await secureStorage.read(key: secureKey);

  if (legacyValue != null) {
    if (secureValue == null && legacyValue.isNotEmpty) {
      await secureStorage.write(key: secureKey, value: legacyValue);
    }
    if (!await preferences.remove(preferenceKey)) {
      throw StateError('Could not remove a migrated token from preferences.');
    }
  }

  final value = secureValue ?? legacyValue;
  return value == null || value.isEmpty ? null : value;
}

Future<void> deleteMcpTokens({
  required SecureTokenStorage secureStorage,
}) async {
  final preferences = await SharedPreferences.getInstance();
  await secureStorage.delete(key: 'mcp.access_token');
  await secureStorage.delete(key: 'mcp.refresh_token');
  await preferences.remove('mcp_access_token');
  await preferences.remove('mcp_refresh_token');
  await preferences.remove('mcp_token_expiry_ms');
  await preferences.remove('mcp_client_id');
  await preferences.remove('mcp_redirect_uri');
  await preferences.remove('mcp_registration_endpoint');
  await preferences.remove('mcp_authorization_endpoint');
  await preferences.remove('mcp_token_endpoint');
}
