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
  BrokerageSource get source => BrokerageSource.schwab;
}

class FakePaperService extends Fake implements IBrokerageService {}

class FakeFidelityService extends Fake implements IBrokerageService {}

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

    testWidgets('Logged out state shows login reasons and snackbar on tap',
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

      // The inline reason stays visible without repeating it in a badge.
      expect(find.text('Login Required'), findsNothing);
      expect(find.text('Requires account login'), findsWidgets);

      // Tap on Backtesting (requires login)
      final backtestingFinder = find.widgetWithText(ListTile, 'Backtesting');
      expect(backtestingFinder, findsOneWidget);
      await tester.tap(backtestingFinder);
      await tester.pump();

      // Expect snackbar explaining login is required
      expect(find.text('Please sign in to your account to use Backtesting.'),
          findsOneWidget);
    });

    testWidgets(
        'Logged in without brokerage shows Brokerage Required badges and snackbar on tap',
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
      expect(
          find.widgetWithText(
              ListTile, 'Risk Circuit Breakers & Tilt Guardrails'),
          findsOneWidget);
      expect(find.text('Guarded & Active'), findsOneWidget);

      // Brokerage-only features should display 'Brokerage Required' badge
      expect(find.text('Brokerage Required'), findsWidgets);

      // Tap on Banking & Transfers (requires brokerage)
      final bankingFinder =
          find.widgetWithText(ListTile, 'Banking & Transfers');
      expect(bankingFinder, findsOneWidget);
      await tester.tap(bankingFinder);
      await tester.pump();

      // Expect snackbar explaining brokerage connection is required
      expect(
          find.text(
              'Please link a brokerage account to use Banking & Transfers.'),
          findsOneWidget);
    });

    testWidgets(
        'Connected with Charles Schwab hides unsupported features and empty categories',
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

      // Supported features for Schwab are displayed
      expect(find.widgetWithText(ListTile, 'Automated Trading'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Backtesting'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Margin Health & Collateral'),
          findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Day Trade & PDT Monitor'),
          findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Automated DRIP with Threshold'),
          findsOneWidget);
      expect(
          find.widgetWithText(
              ListTile, 'Risk Circuit Breakers & Tilt Guardrails'),
          findsOneWidget);

      // Unsupported features are hidden for Schwab
      expect(find.widgetWithText(ListTile, 'Banking & Transfers'), findsNothing);
      expect(find.widgetWithText(ListTile, 'Tax Documents'), findsNothing);
      expect(
          find.widgetWithText(ListTile, 'Corporate Actions & Splits'), findsNothing);
      expect(
          find.widgetWithText(ListTile, 'Stock Lending & Sweeps'), findsNothing);
      expect(find.widgetWithText(ListTile, 'Retirement & IRA'), findsNothing);
      expect(find.widgetWithText(ListTile, 'Connected Agents'), findsNothing);
      expect(find.widgetWithText(ListTile, 'Notification Center'), findsNothing);
      expect(find.widgetWithText(ListTile, 'Shareholder Q&A (Say)'), findsNothing);

      // Banking & Documents category header is hidden since all its features are unsupported
      expect(find.text('BANKING & DOCUMENTS'), findsNothing);
      expect(find.text('Not supported by Charles Schwab'), findsNothing);
    });

    testWidgets(
        'Connected with Paper hides banking, margin health, PDT, DRIP, and Say Q&A',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final loggedInAuth = MockFirebaseAuthWithUser(mockUser);
      final paperUser = BrokerageUser(
        BrokerageSource.paper,
        'PaperUser',
        'credentials',
        null,
      );
      final paperService = FakePaperService();

      await tester.pumpWidget(createTestApp(
        auth: loggedInAuth,
        brokerageUser: paperUser,
        service: paperService,
      ));
      await tester.pumpAndSettle();

      // Supported features for Paper
      expect(find.widgetWithText(ListTile, 'Automated Trading'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Backtesting'), findsOneWidget);
      expect(
          find.widgetWithText(
              ListTile, 'Risk Circuit Breakers & Tilt Guardrails'),
          findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Investment Profile'), findsOneWidget);

      // Unsupported features are hidden for Paper
      expect(find.widgetWithText(ListTile, 'Margin Health & Collateral'),
          findsNothing);
      expect(find.widgetWithText(ListTile, 'Day Trade & PDT Monitor'),
          findsNothing);
      expect(find.widgetWithText(ListTile, 'Automated DRIP with Threshold'),
          findsNothing);
      expect(find.widgetWithText(ListTile, 'Banking & Transfers'), findsNothing);
      expect(find.widgetWithText(ListTile, 'Tax Documents'), findsNothing);
      expect(find.widgetWithText(ListTile, 'Shareholder Q&A (Say)'), findsNothing);
      expect(find.text('BANKING & DOCUMENTS'), findsNothing);
    });

    testWidgets(
        'Connected with Fidelity hides automated trading, margin health, PDT, DRIP, banking, and Say Q&A',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final loggedInAuth = MockFirebaseAuthWithUser(mockUser);
      final fidelityUser = BrokerageUser(
        BrokerageSource.fidelity,
        'FidelityUser',
        'credentials',
        null,
      );
      final fidelityService = FakeFidelityService();

      await tester.pumpWidget(createTestApp(
        auth: loggedInAuth,
        brokerageUser: fidelityUser,
        service: fidelityService,
      ));
      await tester.pumpAndSettle();

      // Supported generic features
      expect(find.widgetWithText(ListTile, 'Backtesting'), findsOneWidget);
      expect(
          find.widgetWithText(
              ListTile, 'Risk Circuit Breakers & Tilt Guardrails'),
          findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Trade Signal Notifications'),
          findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Custom Alerts'), findsOneWidget);

      // Hidden features for Fidelity
      expect(find.widgetWithText(ListTile, 'Automated Trading'), findsNothing);
      expect(find.widgetWithText(ListTile, 'Margin Health & Collateral'),
          findsNothing);
      expect(find.widgetWithText(ListTile, 'Day Trade & PDT Monitor'),
          findsNothing);
      expect(find.widgetWithText(ListTile, 'Automated DRIP with Threshold'),
          findsNothing);
      expect(find.widgetWithText(ListTile, 'Banking & Transfers'), findsNothing);
      expect(find.widgetWithText(ListTile, 'Tax Documents'), findsNothing);
      expect(find.widgetWithText(ListTile, 'Shareholder Q&A (Say)'), findsNothing);
      expect(find.text('BANKING & DOCUMENTS'), findsNothing);
    });

    testWidgets(
        'Connected with Demo / Robinhood enables all supported features without error badges',
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

      // All categories and features are visible
      expect(find.text('BANKING & DOCUMENTS'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Automated Trading'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Backtesting'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Margin Health & Collateral'),
          findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Day Trade & PDT Monitor'),
          findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Automated DRIP with Threshold'),
          findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Banking & Transfers'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Tax Documents & Statements'),
          findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Corporate Actions & Splits'),
          findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Stock Lending & Cash Sweeps'),
          findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Retirement & IRA'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Connected Agents & Apps'),
          findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Notification Center'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Shareholder Q&A (Say)'), findsOneWidget);
    });
  });
}
