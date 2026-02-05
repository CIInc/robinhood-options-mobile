import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:robinhood_options_mobile/services/remote_config_service.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:robinhood_options_mobile/main.dart' as app_main;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:robinhood_options_mobile/utils/auth.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:firebase_core/firebase_core.dart';

class MockFirebasePlatform extends FirebasePlatform {
  @override
  FirebaseAppPlatform app([String name = defaultFirebaseAppName]) {
    return FirebaseAppPlatform(
        name,
        const FirebaseOptions(
          apiKey: 'test',
          appId: 'test',
          messagingSenderId: 'test',
          projectId: 'test',
        ));
  }

  @override
  Future<FirebaseAppPlatform> initializeApp({
    String? name,
    FirebaseOptions? options,
  }) async {
    return FirebaseAppPlatform(
      name ?? defaultFirebaseAppName,
      options ??
          const FirebaseOptions(
            apiKey: 'test',
            appId: 'test',
            messagingSenderId: 'test',
            projectId: 'test',
          ),
    );
  }
}

class FakeFirebaseAuth extends Fake implements FirebaseAuth {
  @override
  User? get currentUser => null;

  @override
  Stream<User?> authStateChanges() {
    return Stream.value(currentUser);
  }
}

class MockRemoteConfig extends Fake implements FirebaseRemoteConfig {
  @override
  Future<void> setConfigSettings(RemoteConfigSettings settings) async {}

  @override
  Future<void> setDefaults(Map<String, dynamic> defaultParameters) async {}

  @override
  Future<bool> fetchAndActivate() async => true;

  @override
  String getString(String key) {
    if (key == 'ai_model_name') return 'gemini-2.0-flash-exp';
    return '';
  }

  @override
  bool getBool(String key) {
    if (key == 'show_personalized_ads') return false;
    return false;
  }
}

class MockRemoteConfigService extends RemoteConfigService {
  MockRemoteConfigService() : super(remoteConfig: MockRemoteConfig());
}

Future<void> setupFirebaseMocks() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  FirebasePlatform.instance = MockFirebasePlatform();
  RemoteConfigService.mockInstance = MockRemoteConfigService();

  // Initialize Firebase App
  final app = await Firebase.initializeApp();

  // Set globals in main.dart
  // Using try-catch regarding late final reassignment in case of shared isolate (rare in flutter test but possible)
  try {
    app_main.app = app;
  } catch (_) {}

  try {
    app_main.auth = FakeFirebaseAuth();
  } catch (_) {}

  try {
    app_main.authUtil = AuthUtil(app_main.auth);
  } catch (_) {}

  try {
    app_main.userRole = UserRole.user;
  } catch (_) {}
}
