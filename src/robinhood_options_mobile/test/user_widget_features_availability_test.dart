import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/brokerage_user_store.dart';
import 'package:robinhood_options_mobile/model/portfolio_privacy_settings.dart';
import 'package:robinhood_options_mobile/model/portfolio_store.dart';
import 'package:robinhood_options_mobile/model/risk_circuit_breaker_config.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/biometric_service.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/services/schwab_service.dart';
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

class MockFirebaseAuthLoggedOut extends Fake
    implements firebase_auth.FirebaseAuth {
  @override
  firebase_auth.User? get currentUser => null;

  @override
  Stream<firebase_auth.User?> authStateChanges() => Stream.value(null);
}

class FakeBiometricService extends Fake implements BiometricService {
  @override
  Future<bool> isBiometricAvailable() async => true;

  @override
  Future<bool> isBiometricEnabled() async => false;
}

class FakeSchwabService extends Fake implements SchwabService {
  @override
  BrokerageSource get source => BrokerageSource.schwab;
}

void main() {
  setUpAll(() async {
    await setupFirebaseMocks();
  });

  group('UserWidget Features Availability Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late FirestoreService firestoreService;
    late FakeBiometricService fakeBiometricService;
    late MockFirebaseUser mockUser;
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
      mockAnalytics = FakeFirebaseAnalytics();
      mockObserver = FakeObserver();
      userStore = BrokerageUserStore([], 0);
      accountStore = AccountStore();
      portfolioStore = PortfolioStore();

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

    Widget createTestApp({
      required firebase_auth.FirebaseAuth auth,
      BrokerageUser? brokerageUser,
      IBrokerageService? service,
    }) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<AccountStore>.value(value: accountStore),
          ChangeNotifierProvider<BrokerageUserStore>.value(value: userStore),
          ChangeNotifierProvider<PortfolioStore>.value(value: portfolioStore),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: UserWidget(
              auth,
              userId: testUid,
              isProfileView: true,
              analytics: mockAnalytics,
              observer: mockObserver,
              brokerageUser: brokerageUser,
              service: service,
              firestoreService: firestoreService,
              biometricService: fakeBiometricService,
            ),
          ),
        ),
      );
    }

    testWidgets('Logged out state shows Login Required badges and shows snackbar on tap',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final loggedOutAuth = MockFirebaseAuthLoggedOut();
      await tester.pumpWidget(createTestApp(
        auth: loggedOutAuth,
        brokerageUser: null,
        service: null,
      ));
      await tester.pumpAndSettle();

      // Features requiring login should display 'Login Required' badge
      expect(find.text('Login Required'), findsWidgets);

      // Tap on Following Activity Feed (requires login)
      final followingFinder = find.widgetWithText(ListTile, 'Following Activity Feed');
      expect(followingFinder, findsOneWidget);
      await tester.tap(followingFinder);
      await tester.pump();

      // Expect snackbar explaining login is required
      expect(find.text('Please sign in to your account to use Following Activity Feed.'), findsOneWidget);
    });

    testWidgets('Logged in without brokerage shows Brokerage Required badges and snackbar on tap',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final loggedInAuth = MockFirebaseAuthWithUser(mockUser);
      await tester.pumpWidget(createTestApp(
        auth: loggedInAuth,
        brokerageUser: null,
        service: null,
      ));
      await tester.pumpAndSettle();

      // Following Activity Feed and Risk Circuit Breakers should be enabled without badges
      expect(find.widgetWithText(ListTile, 'Risk Circuit Breakers'), findsOneWidget);
      expect(find.text('Guarded & Active'), findsOneWidget);

      // Brokerage-only features should display 'Brokerage Required' badge
      expect(find.text('Brokerage Required'), findsWidgets);

      // Tap on Banking & Transfers (requires brokerage)
      final bankingFinder = find.widgetWithText(ListTile, 'Banking & Transfers');
      expect(bankingFinder, findsOneWidget);
      await tester.tap(bankingFinder);
      await tester.pump();

      // Expect snackbar explaining brokerage connection is required
      expect(find.text('Please link a brokerage account to use Banking & Transfers.'), findsOneWidget);
    });

    testWidgets('Connected with Charles Schwab displays Unsupported badges for Robinhood-only features',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final loggedInAuth = MockFirebaseAuthWithUser(mockUser);
      final schwabUser = BrokerageUser(
        BrokerageSource.schwab,
        'SchwabUser',
        'credentials',
        null,
      );
      final schwabService = FakeSchwabService();

      await tester.pumpWidget(createTestApp(
        auth: loggedInAuth,
        brokerageUser: schwabUser,
        service: schwabService,
      ));
      await tester.pumpAndSettle();

      // Margin Health is supported by Schwab -> enabled, no badge
      expect(find.widgetWithText(ListTile, 'Margin Health & Collateral'), findsOneWidget);

      // Banking & Transfers is Robinhood-only -> shows 'Unsupported' badge and subtitle note
      expect(find.text('Unsupported'), findsWidgets);
      expect(find.text('Not supported by Charles Schwab'), findsWidgets);
      expect(find.text('Manage deposits, withdrawals & linked bank accounts'), findsOneWidget);

      // Tap on Banking & Transfers
      final bankingFinder = find.widgetWithText(ListTile, 'Banking & Transfers');
      expect(bankingFinder, findsOneWidget);
      await tester.tap(bankingFinder);
      await tester.pump();

      // Expect snackbar explaining Charles Schwab lack of support
      expect(find.text('Banking & Transfers is not supported by Charles Schwab.'), findsOneWidget);
    });

    testWidgets('Connected with Demo / Robinhood enables all supported features without error badges',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final loggedInAuth = MockFirebaseAuthWithUser(mockUser);
      final demoUser = BrokerageUser(
        BrokerageSource.demo,
        'DemoUser',
        'credentials',
        null,
      );
      final demoService = DemoService();

      await tester.pumpWidget(createTestApp(
        auth: loggedInAuth,
        brokerageUser: demoUser,
        service: demoService,
      ));
      await tester.pumpAndSettle();

      // No 'Login Required', 'Brokerage Required', or 'Unsupported' badges in Features
      expect(find.text('Login Required'), findsNothing);
      expect(find.text('Brokerage Required'), findsNothing);
      expect(find.text('Unsupported'), findsNothing);

      // Both Banking & Transfers and Margin Health should be available and display normal subtitles
      expect(find.text('Manage deposits, withdrawals & linked bank accounts'), findsOneWidget);
      expect(find.text('Margin buffer, buying power & collateral holds'), findsOneWidget);
    });
  });
}
