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
import 'package:robinhood_options_mobile/model/portfolio_store.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/biometric_service.dart';
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

class MockUserInfo extends Fake implements firebase_auth.UserInfo {
  final String _providerId;
  MockUserInfo(this._providerId);

  @override
  String get providerId => _providerId;
}

class MockFirebaseUser extends Fake implements firebase_auth.User {
  final String _uid;
  final String? _displayName;
  final String? _email;
  final String? _phoneNumber;
  final bool _isAnonymous;
  final List<firebase_auth.UserInfo> _providerData;

  MockFirebaseUser({
    String uid = 'test_user_123',
    String? displayName = 'Test User',
    String? email = 'test@example.com',
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

  group('UserWidget Login Type Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late FirestoreService firestoreService;
    late FakeBiometricService fakeBiometricService;
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
      mockAnalytics = FakeFirebaseAnalytics();
      mockObserver = FakeObserver();
      userStore = BrokerageUserStore([], 0);
      accountStore = AccountStore();
      portfolioStore = PortfolioStore();
    });

    Widget createTestApp({
      required firebase_auth.FirebaseAuth auth,
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
              brokerageUser: null,
              service: null,
              firestoreService: firestoreService,
              biometricService: fakeBiometricService,
            ),
          ),
        ),
      );
    }

    testWidgets('Displays Google login type in subtitle and expanded ListTile',
        (WidgetTester tester) async {
      final user = User(
        name: 'Google User',
        email: 'google@gmail.com',
        providerId: 'google.com',
        role: UserRole.user,
        devices: [],
        brokerageUsers: [],
        dateCreated: DateTime.now(),
      );
      await firestoreService.userCollection.doc(testUid).set(user);

      final mockUser = MockFirebaseUser(
        email: 'google@gmail.com',
        providerData: [MockUserInfo('google.com')],
      );
      final auth = MockFirebaseAuthWithUser(mockUser);

      await tester.pumpWidget(createTestApp(auth: auth));
      await tester.pumpAndSettle();

      // Subtitle should show Google
      expect(find.text('Google'), findsOneWidget);

      // Expand ExpansionTile to reveal Login Type and Login Name ListTiles
      await tester.tap(find.text('Google User'));
      await tester.pumpAndSettle();

      expect(find.text('Email'), findsOneWidget);
      expect(find.text('google@gmail.com'), findsNWidgets(2)); // in subtitle and ListTile
      expect(find.text('Login Type'), findsOneWidget);
      // Now Google appears in both subtitle and ListTile
      expect(find.text('Google'), findsNWidgets(2));
    });

    testWidgets('Displays Apple login type in subtitle and expanded ListTile',
        (WidgetTester tester) async {
      final user = User(
        name: 'Apple User',
        email: 'apple@privaterelay.appleid.com',
        providerId: 'apple.com',
        role: UserRole.user,
        devices: [],
        brokerageUsers: [],
        dateCreated: DateTime.now(),
      );
      await firestoreService.userCollection.doc(testUid).set(user);

      final mockUser = MockFirebaseUser(
        email: 'apple@privaterelay.appleid.com',
        providerData: [MockUserInfo('apple.com')],
      );
      final auth = MockFirebaseAuthWithUser(mockUser);

      await tester.pumpWidget(createTestApp(auth: auth));
      await tester.pumpAndSettle();

      // Subtitle should show Apple
      expect(find.text('Apple'), findsOneWidget);

      // Expand ExpansionTile
      await tester.tap(find.text('Apple User'));
      await tester.pumpAndSettle();

      expect(find.text('Email'), findsOneWidget);
      expect(find.text('apple@privaterelay.appleid.com'), findsNWidgets(2));
      expect(find.text('Login Type'), findsOneWidget);
      expect(find.text('Apple'), findsNWidgets(2));
    });

    testWidgets('Displays Guest login type for anonymous user',
        (WidgetTester tester) async {
      final user = User(
        name: 'Guest User',
        providerId: 'anonymous',
        role: UserRole.user,
        devices: [],
        brokerageUsers: [],
        dateCreated: DateTime.now(),
      );
      await firestoreService.userCollection.doc(testUid).set(user);

      final mockUser = MockFirebaseUser(
        displayName: 'Guest User',
        email: null,
        isAnonymous: true,
      );
      final auth = MockFirebaseAuthWithUser(mockUser);

      await tester.pumpWidget(createTestApp(auth: auth));
      await tester.pumpAndSettle();

      expect(find.text('Guest'), findsOneWidget);

      // Expand ExpansionTile
      await tester.tap(find.text('Guest User'));
      await tester.pumpAndSettle();

      // Anonymous user without email has no Email or Phone Number tile
      expect(find.text('Email'), findsNothing);
      expect(find.text('Phone Number'), findsNothing);
      expect(find.text('Login Type'), findsOneWidget);
      expect(find.text('Guest'), findsNWidgets(2));
    });

    testWidgets('Displays Phone Number label for phone authentication',
        (WidgetTester tester) async {
      final user = User(
        name: 'Phone User',
        phoneNumber: '+15551234567',
        providerId: 'phone',
        role: UserRole.user,
        devices: [],
        brokerageUsers: [],
        dateCreated: DateTime.now(),
      );
      await firestoreService.userCollection.doc(testUid).set(user);

      final mockUser = MockFirebaseUser(
        displayName: 'Phone User',
        phoneNumber: '+15551234567',
        providerData: [MockUserInfo('phone')],
      );
      final auth = MockFirebaseAuthWithUser(mockUser);

      await tester.pumpWidget(createTestApp(auth: auth));
      await tester.pumpAndSettle();

      expect(find.text('Phone'), findsOneWidget);

      // Expand ExpansionTile
      await tester.tap(find.text('Phone User'));
      await tester.pumpAndSettle();

      expect(find.text('Phone Number'), findsOneWidget);
      expect(find.text('+15551234567'), findsNWidgets(2));
      expect(find.text('Login Type'), findsOneWidget);
      expect(find.text('Phone'), findsNWidgets(2));
    });
  });
}
