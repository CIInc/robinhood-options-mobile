import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/brokerage_user_store.dart';
import 'package:robinhood_options_mobile/model/portfolio_privacy_settings.dart';
import 'package:robinhood_options_mobile/model/portfolio_store.dart';
import 'package:robinhood_options_mobile/model/risk_circuit_breaker_config.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/biometric_service.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/widgets/user_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_mocks.dart';

class FakeFirebaseAnalytics extends Fake implements FirebaseAnalytics {
  @override
  Future<void> logScreenView({
    String? screenClass,
    String? screenName,
    AnalyticsCallOptions? callOptions,
    Map<String, Object>? parameters,
  }) async {}

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
    List<AnalyticsEventItem>? items,
    AnalyticsCallOptions? callOptions,
  }) async {}
}

class FakeObserver extends Fake implements FirebaseAnalyticsObserver {}

class MockFirebaseUser extends Fake implements firebase_auth.User {
  @override
  String get uid => 'test_user_123';

  @override
  String? get displayName => 'Test User';

  @override
  String? get email => 'test@example.com';

  @override
  String? get photoURL => null;
}

class MockFirebaseAuthWithUser extends Fake
    implements firebase_auth.FirebaseAuth {
  final firebase_auth.User _user;
  MockFirebaseAuthWithUser(this._user);

  @override
  firebase_auth.User? get currentUser => _user;

  @override
  Stream<firebase_auth.User?> authStateChanges() => Stream.value(_user);
}

class FakeBiometricService extends Fake implements BiometricService {
  @override
  Future<bool> isBiometricAvailable() async => true;

  @override
  Future<bool> isBiometricEnabled() async => false;
}

void main() {
  setUpAll(() async {
    await setupFirebaseMocks();
  });

  group('UserWidget Features and App Settings Placement Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late FirestoreService firestoreService;
    late FakeBiometricService fakeBiometricService;
    late MockFirebaseUser mockUser;
    late MockFirebaseAuthWithUser mockAuth;
    late FakeFirebaseAnalytics mockAnalytics;
    late FakeObserver mockObserver;
    late BrokerageUserStore userStore;
    late AccountStore accountStore;
    late PortfolioStore portfolioStore;
    const testUid = 'test_user_123';

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      PackageInfo.setMockInitialValues(
        appName: 'Robinhood Options',
        packageName: 'com.ciinc.robinhood_options_mobile',
        version: '1.0.0',
        buildNumber: '1',
        buildSignature: '',
      );

      fakeFirestore = FakeFirebaseFirestore();
      firestoreService = FirestoreService(firestore: fakeFirestore);
      fakeBiometricService = FakeBiometricService();
      mockUser = MockFirebaseUser();
      mockAuth = MockFirebaseAuthWithUser(mockUser);
      mockAnalytics = FakeFirebaseAnalytics();
      mockObserver = FakeObserver();
      userStore = BrokerageUserStore([], 0);
      accountStore = AccountStore();
      portfolioStore = PortfolioStore();

      // Seed user document in Firestore with circuit breaker config and portfolio privacy
      final user = User(
        name: 'Test User',
        email: 'test@example.com',
        role: UserRole.user,
        devices: [],
        brokerageUsers: [],
        dateCreated: DateTime.now(),
        portfolioPrivacy: const PortfolioPrivacySettings(isPublic: true),
        riskCircuitBreakerConfig: RiskCircuitBreakerConfig(
          enabled: true,
          maxDailyLossAmount: 500,
        ),
      );
      await firestoreService.userCollection.doc(testUid).set(user);
    });

    testWidgets(
        'Features and App Settings cards display Biometric Authentication, Risk Circuit Breakers, Portfolio & Social Privacy, and Following Activity Feed',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AccountStore>.value(value: accountStore),
            ChangeNotifierProvider<BrokerageUserStore>.value(value: userStore),
            ChangeNotifierProvider<PortfolioStore>.value(value: portfolioStore),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: UserWidget(
                mockAuth,
                userId: testUid,
                isProfileView: true,
                analytics: mockAnalytics,
                observer: mockObserver,
                brokerageUser: null,
                service: DemoService(),
                firestoreService: firestoreService,
                biometricService: fakeBiometricService,
              ),
            ),
          ),
        ),
      );

      // Let streams and futures resolve
      await tester.pumpAndSettle();

      // Verify App Settings contains Biometric Authentication
      expect(find.text('App Settings'), findsOneWidget);
      expect(find.text('Biometric Authentication'), findsOneWidget);
      expect(find.text('Use FaceID/TouchID to access app'), findsOneWidget);

      // Verify the main Features header is present
      expect(find.text('Features'), findsOneWidget);
      expect(
          find.text('Trading tools, account operations & risk safeguards'),
          findsOneWidget);

      // Verify Risk Circuit Breakers is rendered under Features
      expect(find.text('Risk Circuit Breakers'), findsOneWidget);
      expect(find.text('Guarded & Active'), findsOneWidget);

      // Verify Portfolio & Social Privacy is rendered under Features
      expect(find.text('Portfolio & Social Privacy'), findsOneWidget);
      expect(find.text('Public Portfolio'), findsOneWidget);

      // Verify Following Activity Feed is rendered under Features
      expect(find.text('Following Activity Feed'), findsOneWidget);
      expect(find.text('Real-time trades from traders you follow'),
          findsOneWidget);

      // Verify they are within the Features card structure
      expect(find.text('RISK & MARGIN SAFEGUARDS'), findsOneWidget);
      expect(find.text('PROFILE & COMMUNITY'), findsOneWidget);
    });
  });
}
