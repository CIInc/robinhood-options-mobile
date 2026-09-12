import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_config.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_provider.dart';
import 'package:robinhood_options_mobile/model/brokerage_user_store.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/widgets/auto_trade_status_badge_widget.dart';
import 'package:robinhood_options_mobile/widgets/sliverappbar_widget.dart';

class MockFirebaseAuth extends Fake implements firebase_auth.FirebaseAuth {
  final firebase_auth.User? _user;
  MockFirebaseAuth({firebase_auth.User? user}) : _user = user;

  @override
  firebase_auth.User? get currentUser => _user;

  @override
  Stream<firebase_auth.User?> authStateChanges() => Stream.value(_user);
}

class MockFirebaseUser extends Fake implements firebase_auth.User {
  @override
  String get uid => 'test_uid';

  @override
  String? get photoURL => null;

  @override
  String? get displayName => 'Test User';
}

class MockAgenticTradingProvider extends ChangeNotifier
    implements AgenticTradingProvider {
  @override
  AgenticTradingConfig config = AgenticTradingConfig(
    strategyConfig: TradeStrategyConfig(),
    autoTradeEnabled: false,
  );

  @override
  bool showAutoTradingVisual = false;

  @override
  bool emergencyStopActivated = false;

  @override
  int dailyTradeCount = 0;

  @override
  int autoTradeCountdownSeconds = 300;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeFirestoreService extends Fake implements FirestoreService {}

class FakeFirebaseAnalytics extends Fake implements FirebaseAnalytics {}

void main() {
  late MockAgenticTradingProvider mockAgenticProvider;
  late BrokerageUserStore mockBrokerageUserStore;
  late AccountStore mockAccountStore;

  setUp(() {
    mockAgenticProvider = MockAgenticTradingProvider();
    mockBrokerageUserStore = BrokerageUserStore([], 0);
    mockAccountStore = AccountStore();
  });

  Widget buildWidget({required firebase_auth.FirebaseAuth auth}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AgenticTradingProvider>.value(
          value: mockAgenticProvider,
        ),
        ChangeNotifierProvider<BrokerageUserStore>.value(
          value: mockBrokerageUserStore,
        ),
        ChangeNotifierProvider<AccountStore>.value(
          value: mockAccountStore,
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              ExpandedSliverAppBar(
                auth: auth,
                firestoreService: FakeFirestoreService(),
                automaticallyImplyLeading: true,
                title: const Text('Home'),
                analytics: FakeFirebaseAnalytics(),
                observer: FirebaseAnalyticsObserver(
                  analytics: FakeFirebaseAnalytics(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets(
      'renders single profile button when logged in and auto-trade is disabled',
      (tester) async {
    mockAgenticProvider.config.autoTradeEnabled = false;
    final auth = MockFirebaseAuth(user: MockFirebaseUser());

    await tester.pumpWidget(buildWidget(auth: auth));
    await tester.pumpAndSettle();

    // AutoTradeStatusBadgeWidget combines the avatar and is present
    expect(find.byType(AutoTradeStatusBadgeWidget), findsOneWidget);
    // When disabled, it renders as a single IconButton (the user icon)
    expect(find.byType(IconButton), findsWidgets);
    expect(find.byIcon(Icons.account_circle), findsOneWidget);
  });

  testWidgets(
      'renders combined badge with avatar and countdown when auto-trade is enabled',
      (tester) async {
    mockAgenticProvider.config.autoTradeEnabled = true;
    mockAgenticProvider.autoTradeCountdownSeconds = 180; // 3:00
    final auth = MockFirebaseAuth(user: MockFirebaseUser());

    await tester.pumpWidget(buildWidget(auth: auth));
    await tester.pumpAndSettle();

    // The combined widget renders both the avatar and the countdown
    expect(find.byType(AutoTradeStatusBadgeWidget), findsOneWidget);
    expect(find.byIcon(Icons.account_circle), findsOneWidget);
    expect(find.text('3:00'), findsOneWidget);
  });

  testWidgets('renders login icon button when user is logged out',
      (tester) async {
    final auth = MockFirebaseAuth(user: null);

    await tester.pumpWidget(buildWidget(auth: auth));
    await tester.pumpAndSettle();

    expect(find.byType(AutoTradeStatusBadgeWidget), findsNothing);
    expect(find.byIcon(Icons.account_circle_outlined), findsOneWidget);
  });
}
