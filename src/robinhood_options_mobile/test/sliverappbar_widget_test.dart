import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_config.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_provider.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/brokerage_user_store.dart';
import 'package:robinhood_options_mobile/model/forex_holding_store.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/option_position_store.dart';
import 'package:robinhood_options_mobile/model/portfolio_historicals_store.dart';
import 'package:robinhood_options_mobile/model/portfolio_store.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/utils/auth.dart';
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
  final bool anonymous;
  MockFirebaseUser({this.anonymous = false});

  @override
  String get uid => 'test_uid';

  @override
  bool get isAnonymous => anonymous;

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

  test('anonymous Firebase sessions are treated as guests', () {
    expect(AuthUtil.isSignedIn(null), isFalse);
    expect(AuthUtil.isSignedIn(MockFirebaseUser(anonymous: true)), isFalse);
    expect(AuthUtil.isSignedIn(MockFirebaseUser()), isTrue);
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
        ChangeNotifierProvider(create: (_) => PortfolioStore()),
        ChangeNotifierProvider(create: (_) => PortfolioHistoricalsStore()),
        ChangeNotifierProvider(create: (_) => ForexHoldingStore()),
        ChangeNotifierProvider(create: (_) => OptionPositionStore()),
        ChangeNotifierProvider(create: (_) => InstrumentPositionStore()),
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

  testWidgets(
      'warns and stays on the current account when cancelling a live switch',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final robinhoodUser =
        BrokerageUser(BrokerageSource.robinhood, 'rh-account', null, null);
    final schwabUser =
        BrokerageUser(BrokerageSource.schwab, 'schwab-account', null, null);
    mockBrokerageUserStore = BrokerageUserStore([
      robinhoodUser,
      schwabUser,
    ], 0);
    mockAgenticProvider.config = AgenticTradingConfig(
      strategyConfig: TradeStrategyConfig(),
      autoTradeEnabled: true,
      paperTradingMode: false,
    );

    await tester.pumpWidget(
      buildWidget(auth: MockFirebaseAuth(user: MockFirebaseUser())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Robinhood'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('schwab-account'));
    await tester.pumpAndSettle();

    expect(find.text('Live auto-trading is enabled'), findsOneWidget);
    expect(find.textContaining('will not place an order now'), findsOneWidget);

    await tester.tap(find.text('Keep current account'));
    await tester.pumpAndSettle();

    expect(mockBrokerageUserStore.currentUser, same(robinhoodUser));
    expect(find.text('Switch Account'), findsOneWidget);

    await tester.tap(find.text('schwab-account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Switch account'));
    await tester.pumpAndSettle();

    expect(mockBrokerageUserStore.currentUser, same(schwabUser));
  });

  testWidgets(
      'switching from paper trading to Robinhood clears paper_account from AccountStore',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final paperUser =
        BrokerageUser(BrokerageSource.paper, 'paper-user', null, null);
    final robinhoodUser =
        BrokerageUser(BrokerageSource.robinhood, 'rh-account', null, null);
    mockBrokerageUserStore = BrokerageUserStore([
      paperUser,
      robinhoodUser,
    ], 0);
    mockAccountStore.add(Account(
      'paper_account',
      10000.0,
      'paper_account',
      'Paper Account',
      10000.0,
      'Level 3',
      0.0,
      0.0,
      0.0,
    ));
    mockAccountStore.setSelectedAccountNumber('paper_account');

    await tester.pumpWidget(
      buildWidget(auth: MockFirebaseAuth(user: MockFirebaseUser())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Paper • paper_account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('rh-account'));
    await tester.pumpAndSettle();

    expect(mockBrokerageUserStore.currentUser, same(robinhoodUser));
    expect(mockAccountStore.items, isEmpty);
    expect(mockAccountStore.selectedAccountNumber, isNull);
    expect(mockAccountStore.selectedAccount, isNull);
  });
}
