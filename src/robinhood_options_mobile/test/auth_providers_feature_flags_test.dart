import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/services/feature_access_service.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/services/remote_config_service.dart';
import 'package:robinhood_options_mobile/utils/auth.dart';

import 'firebase_mocks.dart';

class MockFirebaseUserInfo extends Fake implements firebase_auth.UserInfo {
  final String _providerId;
  MockFirebaseUserInfo(this._providerId);

  @override
  String get providerId => _providerId;
}

class FakeIdTokenResult extends Fake implements firebase_auth.IdTokenResult {
  final Map<String, dynamic>? _claims;
  FakeIdTokenResult([this._claims]);

  @override
  Map<String, dynamic>? get claims => _claims;
}

class MockFirebaseUserInstance extends Fake implements firebase_auth.User {
  final String _uid;
  final String? _displayName;
  final String? _email;
  final String? _phoneNumber;
  final bool _isAnonymous;
  final List<firebase_auth.UserInfo> _providerData;

  MockFirebaseUserInstance({
    required String uid,
    String? displayName,
    String? email,
    String? phoneNumber,
    bool isAnonymous = false,
    List<firebase_auth.UserInfo> providerData = const [],
  })  : _uid = uid,
        _displayName = displayName,
        _email = email,
        _phoneNumber = phoneNumber,
        _isAnonymous = isAnonymous,
        _providerData = providerData;

  @override
  String get uid => _uid;

  @override
  String? get displayName => _displayName;

  @override
  String? get email => _email;

  @override
  String? get phoneNumber => _phoneNumber;

  @override
  String? get photoURL => null;

  @override
  bool get isAnonymous => _isAnonymous;

  @override
  List<firebase_auth.UserInfo> get providerData => _providerData;

  @override
  Future<firebase_auth.IdTokenResult> getIdTokenResult(
      [bool forceRefresh = false]) async {
    return FakeIdTokenResult({'role': 'user'});
  }
}

class MockFirebaseAuthPlatformInstance extends Fake
    implements firebase_auth.FirebaseAuth {
  firebase_auth.User? _currentUser;
  MockFirebaseAuthPlatformInstance(this._currentUser);

  @override
  firebase_auth.User? get currentUser => _currentUser;

  void setCurrentUser(firebase_auth.User? user) {
    _currentUser = user;
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await setupFirebaseMocks();
    PackageInfo.setMockInitialValues(
      appName: 'Robinhood Options',
      packageName: 'com.robinhood.options',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/device_info'),
      (MethodCall methodCall) async {
        return <String, dynamic>{
          'name': 'iPhone',
          'systemName': 'iOS',
          'systemVersion': '17.0',
          'model': 'iPhone 15',
          'modelName': 'iPhone 15',
          'localizedModel': 'iPhone',
          'identifierForVendor': 'test_device_id',
          'freeDiskSize': 1000000000,
          'totalDiskSize': 2000000000,
          'physicalRamSize': 6000,
          'availableRamSize': 3000,
          'isiOSAppOnMac': false,
          'isiOSAppOnVision': false,
          'isPhysicalDevice': false,
          'utsname': <String, dynamic>{
            'sysname': 'Darwin',
            'nodename': 'localhost',
            'release': '23.0',
            'version': '1.0',
            'machine': 'arm64',
          },
        };
      },
    );
  });

  tearDownAll(() {
    debugDefaultTargetPlatformOverride = null;
  });

  group('Auth Providers & Feature Flag Synchronization Tests', () {
    late SharedPreferences prefs;
    late FakeFirebaseFirestore fakeFirestore;
    late FirestoreService firestoreService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      fakeFirestore = FakeFirebaseFirestore();
      firestoreService = FirestoreService(firestore: fakeFirestore);
    });

    test(
        'Phone authentication user sets up Firestore document and allows feature flag toggles',
        () async {
      final phoneUser = MockFirebaseUserInstance(
        uid: 'phone_user_abc',
        phoneNumber: '+15559876543',
        providerData: [MockFirebaseUserInfo('phone')],
      );

      final auth = MockFirebaseAuthPlatformInstance(phoneUser);
      final authUtil = AuthUtil(auth);

      // Save user to Firestore via AuthUtil
      final createdUser = await authUtil.setUser(
        firestoreService,
        brokerageUserStore: null,
      );

      expect(createdUser.phoneNumber, equals('+15559876543'));
      expect(createdUser.email, isNull);
      expect(createdUser.providerId, equals('phone'));
      expect(createdUser.featureFlags, isNotNull);

      // Verify Firestore stored document with non-null featureFlags map
      final docRef = firestoreService.userCollection.doc('phone_user_abc');
      final snapshot = await docRef.get();
      expect(snapshot.exists, isTrue);
      expect(snapshot.data()?.featureFlags, isNotNull);

      // Now toggle feature flags on this phone user
      final featureService = FeatureAccessService(
        prefs: prefs,
        remoteConfig: RemoteConfigService.instance,
        overrideModes: {
          FeatureBundle.advancedTrading: FeatureRolloutMode.betaOptIn,
          FeatureBundle.extendedBrokerages: FeatureRolloutMode.public,
        },
        overrideSelfOptIn: true,
      );

      // 1. Beta opt-in toggle
      await featureService.setUserPreference(
        FeatureBundle.advancedTrading,
        true,
        user: createdUser,
        userDocRef: docRef,
      );

      expect(createdUser.featureFlags!['advancedTrading'], isTrue);
      expect(
        featureService.isFeatureEnabled(FeatureBundle.advancedTrading,
            userRole: UserRole.user, user: createdUser),
        isTrue,
      );

      final updatedSnapshot = await docRef.get();
      expect(updatedSnapshot.data()?.featureFlags?['advancedTrading'], isTrue);

      // 2. Public feature opt-out toggle
      await featureService.setUserPreference(
        FeatureBundle.extendedBrokerages,
        false,
        user: createdUser,
        userDocRef: docRef,
      );

      expect(createdUser.featureFlags!['extendedBrokerages'], isFalse);
      expect(
        featureService.isFeatureEnabled(FeatureBundle.extendedBrokerages,
            userRole: UserRole.user, user: createdUser),
        isFalse,
      );

      final updatedSnapshot2 = await docRef.get();
      expect(updatedSnapshot2.data()?.featureFlags?['extendedBrokerages'],
          isFalse);

      // 3. Reset opt-ins
      await featureService.resetAllOptIns(
        user: createdUser,
        userDocRef: docRef,
      );

      expect(createdUser.featureFlags, isEmpty);
      final resetSnapshot = await docRef.get();
      expect(resetSnapshot.data()?.featureFlags, isEmpty);
    });

    test(
        'Feature flag persistence operates correctly across Google, Apple, Email, and Anonymous providers',
        () async {
      final testCases = [
        {
          'uid': 'google_uid_1',
          'email': 'trader@gmail.com',
          'provider': 'google.com',
          'displayName': 'Google Trader',
          'isAnon': false,
        },
        {
          'uid': 'apple_uid_2',
          'email': 'trader@privaterelay.appleid.com',
          'provider': 'apple.com',
          'displayName': 'Apple Trader',
          'isAnon': false,
        },
        {
          'uid': 'email_uid_3',
          'email': 'trader@example.com',
          'provider': 'password',
          'displayName': 'Email Trader',
          'isAnon': false,
        },
        {
          'uid': 'anon_uid_4',
          'email': null,
          'provider': 'anonymous',
          'displayName': null,
          'isAnon': true,
        },
      ];

      for (final tc in testCases) {
        final mockFirebaseUser = MockFirebaseUserInstance(
          uid: tc['uid'] as String,
          email: tc['email'] as String?,
          displayName: tc['displayName'] as String?,
          isAnonymous: tc['isAnon'] as bool,
          providerData: tc['isAnon'] as bool
              ? []
              : [MockFirebaseUserInfo(tc['provider'] as String)],
        );

        final auth = MockFirebaseAuthPlatformInstance(mockFirebaseUser);
        final authUtil = AuthUtil(auth);

        final user = await authUtil.setUser(
          firestoreService,
          brokerageUserStore: null,
        );

        final docRef = firestoreService.userCollection.doc(tc['uid'] as String);

        final featureService = FeatureAccessService(
          prefs: prefs,
          remoteConfig: RemoteConfigService.instance,
          overrideModes: {
            FeatureBundle.agenticTrading: FeatureRolloutMode.betaOptIn,
          },
          overrideSelfOptIn: true,
        );

        // Toggle feature
        await featureService.setUserPreference(
          FeatureBundle.agenticTrading,
          true,
          user: user,
          userDocRef: docRef,
        );

        expect(user.featureFlags!['agenticTrading'], isTrue);
        expect(
          featureService.isFeatureEnabled(FeatureBundle.agenticTrading,
              userRole: UserRole.user, user: user),
          isTrue,
        );

        final firestoreDoc = await docRef.get();
        expect(firestoreDoc.data()?.featureFlags?['agenticTrading'], isTrue);
      }
    });
  });
}
