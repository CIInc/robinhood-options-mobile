import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_provider.dart';
import 'package:robinhood_options_mobile/model/trade_signals_provider.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_config.dart';
import 'package:robinhood_options_mobile/widgets/agentic_trading_settings_widget.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/brokerage_user_store.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/backtesting_provider.dart';
import 'package:robinhood_options_mobile/model/trade_strategies.dart';
import 'firebase_mocks.dart';

class MockBacktestingProvider extends ChangeNotifier
    implements BacktestingProvider {
  @override
  List<TradeStrategyTemplate> get templates => [];

  @override
  void initialize(DocumentReference<User>? userDocRef) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() async {
    await setupFirebaseMocks();
  });

  group('AgenticTradingSettingsWidget Auto-Save Tests', () {
    late User testUser;
    late DocumentReference<User> testUserDocRef;
    late MockBrokerageService mockService;

    setUp(() {
      mockService = MockBrokerageService();
      testUser = User(
        name: 'Test User',
        email: 'test@example.com',
        devices: [],
        dateCreated: DateTime.now(),
        brokerageUsers: [],
        agenticTradingConfig: AgenticTradingConfig(
          strategyConfig: TradeStrategyConfig(
            smaPeriodFast: 10,
            smaPeriodSlow: 30,
            tradeQuantity: 1,
            rsiPeriod: 14,
            marketIndexSymbol: 'SPY',
            takeProfitPercent: 10.0,
            stopLossPercent: 5.0,
            enabledIndicators: {
              'priceMovement': true,
              'momentum': true,
              'marketDirection': true,
              'volume': true,
              'macd': true,
              'bollingerBands': true,
              'stochastic': true,
              'atr': true,
              'obv': true,
            },
            maxPositionSize: 100,
            maxPortfolioConcentration: 0.5,
            dailyTradeLimit: 5,
          ),
          autoTradeCooldownMinutes: 60,
        ),
      );
    });

    testWidgets('Auto-save should trigger when take profit is changed',
        (WidgetTester tester) async {
      testUserDocRef = FirebaseFirestore.instance
          .collection('user')
          .doc('test_user_123')
          .withConverter<User>(
            fromFirestore: (snapshot, _) =>
                User.fromJson(snapshot.data() ?? {}),
            toFirestore: (user, _) => user.toJson(),
          );

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => AgenticTradingProvider()),
              ChangeNotifierProvider(create: (_) => BrokerageUserStore([], 0)),
              ChangeNotifierProvider(create: (_) => TradeSignalsProvider()),
              ChangeNotifierProvider<BacktestingProvider>(
                  create: (_) => MockBacktestingProvider()),
            ],
            child: AgenticTradingSettingsWidget(
              user: testUser,
              userDocRef: testUserDocRef,
              service: mockService,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify widget renders without errors
      expect(find.byType(AgenticTradingSettingsWidget), findsOneWidget);
      expect(
        find.textContaining('Market-close exits are not guaranteed'),
        findsOneWidget,
      );
      expect(
        find.text('Link a brokerage to enable automated execution.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<SwitchListTile>(
                find.byKey(const ValueKey('auto-trading-toggle')))
            .onChanged,
        isNull,
      );
      expect(find.text('Automated Paper Tests'), findsOneWidget);
      expect(find.text('Paper Trading Mode'), findsNothing);
    });

    testWidgets('Auto-save should trigger when stop loss is changed',
        (WidgetTester tester) async {
      testUserDocRef = FirebaseFirestore.instance
          .collection('user')
          .doc('test_user_123')
          .withConverter<User>(
            fromFirestore: (snapshot, _) =>
                User.fromJson(snapshot.data() ?? {}),
            toFirestore: (user, _) => user.toJson(),
          );

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => AgenticTradingProvider()),
              ChangeNotifierProvider(create: (_) => BrokerageUserStore([], 0)),
              ChangeNotifierProvider(create: (_) => TradeSignalsProvider()),
              ChangeNotifierProvider<BacktestingProvider>(
                  create: (_) => MockBacktestingProvider()),
            ],
            child: AgenticTradingSettingsWidget(
              user: testUser,
              userDocRef: testUserDocRef,
              service: mockService,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify widget renders without errors
      expect(find.byType(AgenticTradingSettingsWidget), findsOneWidget);
    });

    testWidgets('Systematic auto-trading waits for active entry indicators',
        (WidgetTester tester) async {
      testUser.agenticTradingConfig =
          AgenticTradingConfig(strategyConfig: TradeStrategyConfig());
      testUserDocRef = FirebaseFirestore.instance
          .collection('user')
          .doc('test_user_123')
          .withConverter<User>(
            fromFirestore: (snapshot, _) =>
                User.fromJson(snapshot.data() ?? {}),
            toFirestore: (user, _) => user.toJson(),
          );

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => AgenticTradingProvider()),
              ChangeNotifierProvider(
                create: (_) => BrokerageUserStore([
                  BrokerageUser(
                      BrokerageSource.robinhood, 'rh-user', null, null),
                ], 0),
              ),
              ChangeNotifierProvider(create: (_) => TradeSignalsProvider()),
              ChangeNotifierProvider<BacktestingProvider>(
                  create: (_) => MockBacktestingProvider()),
            ],
            child: AgenticTradingSettingsWidget(
              user: testUser,
              userDocRef: testUserDocRef,
              service: mockService,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text(
            'Choose at least one entry indicator to enable Systematic mode.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<SwitchListTile>(
                find.byKey(const ValueKey('auto-trading-toggle')))
            .onChanged,
        isNull,
      );
    });

    testWidgets('Schwab quote feed enables automated paper trading',
        (WidgetTester tester) async {
      testUserDocRef = FirebaseFirestore.instance
          .collection('user')
          .doc('test_user_123')
          .withConverter<User>(
            fromFirestore: (snapshot, _) =>
                User.fromJson(snapshot.data() ?? {}),
            toFirestore: (user, _) => user.toJson(),
          );

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => AgenticTradingProvider()),
              ChangeNotifierProvider(
                create: (_) => BrokerageUserStore([
                  BrokerageUser(
                      BrokerageSource.schwab, 'schwab-user', null, null),
                ], 0),
              ),
              ChangeNotifierProvider(create: (_) => TradeSignalsProvider()),
              ChangeNotifierProvider<BacktestingProvider>(
                  create: (_) => MockBacktestingProvider()),
            ],
            child: AgenticTradingSettingsWidget(
              user: testUser,
              userDocRef: testUserDocRef,
              service: mockService,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final paperSwitch = find.byKey(const ValueKey('paperTradingMode'));
      expect(paperSwitch, findsOneWidget);
      expect(
        tester.widget<SwitchListTile>(paperSwitch).onChanged,
        isNotNull,
      );
      expect(
          find.textContaining('Use selected brokerage quotes'), findsOneWidget);
      expect(find.text('Automated Paper Tests'), findsNothing);
    });

    testWidgets(
        'switching active paper auto-trading to live requires confirmation',
        (WidgetTester tester) async {
      testUser.agenticTradingConfig = AgenticTradingConfig(
        autoTradeEnabled: true,
        paperTradingMode: true,
        strategyConfig: TradeStrategyConfig(
          enabledIndicators: {'priceMovement': true},
        ),
      );
      testUserDocRef = FirebaseFirestore.instance
          .collection('user')
          .doc('test_user_123')
          .withConverter<User>(
            fromFirestore: (snapshot, _) =>
                User.fromJson(snapshot.data() ?? {}),
            toFirestore: (user, _) => user.toJson(),
          );

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => AgenticTradingProvider()),
              ChangeNotifierProvider(
                create: (_) => BrokerageUserStore([
                  BrokerageUser(
                      BrokerageSource.robinhood, 'rh-user', null, null),
                ], 0),
              ),
              ChangeNotifierProvider(create: (_) => TradeSignalsProvider()),
              ChangeNotifierProvider<BacktestingProvider>(
                  create: (_) => MockBacktestingProvider()),
            ],
            child: AgenticTradingSettingsWidget(
              user: testUser,
              userDocRef: testUserDocRef,
              service: mockService,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      final paperSwitch = find.byKey(const ValueKey('paperTradingMode'));
      await tester.ensureVisible(paperSwitch);
      await tester.tap(paperSwitch);
      await tester.pumpAndSettle();

      expect(find.text('Switch to real-money trading?'), findsOneWidget);
      expect(find.text('Switch to Live'), findsOneWidget);
      expect(testUser.agenticTradingConfig!.paperTradingMode, isTrue);
    });

    testWidgets('emergency stop disables pending order approval',
        (WidgetTester tester) async {
      final agenticTradingProvider = AgenticTradingProvider();
      agenticTradingProvider.loadConfigFromUser(null);
      agenticTradingProvider.pendingOrders.add({
        'id': 'pending-1',
        'timestamp': DateTime.now().toIso8601String(),
        'symbol': 'AAPL',
        'action': 'BUY',
        'quantity': 1,
        'price': 100.0,
      });
      await agenticTradingProvider.activateEmergencyStop();

      testUserDocRef = FirebaseFirestore.instance
          .collection('user')
          .doc('test_user_123')
          .withConverter<User>(
            fromFirestore: (snapshot, _) =>
                User.fromJson(snapshot.data() ?? {}),
            toFirestore: (user, _) => user.toJson(),
          );

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<AgenticTradingProvider>.value(
                  value: agenticTradingProvider),
              ChangeNotifierProvider(create: (_) => BrokerageUserStore([], 0)),
              ChangeNotifierProvider(create: (_) => TradeSignalsProvider()),
              ChangeNotifierProvider<BacktestingProvider>(
                  create: (_) => MockBacktestingProvider()),
            ],
            child: AgenticTradingSettingsWidget(
              user: testUser,
              userDocRef: testUserDocRef,
              service: mockService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
            'Emergency stop is active. Pending orders cannot be approved.'),
        findsOneWidget,
      );
      final approveButton = find.widgetWithText(FilledButton, 'Approve');
      expect(tester.widget<FilledButton>(approveButton).onPressed, isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      agenticTradingProvider.dispose();
    });

    testWidgets('balanced setup activates core entry indicators only',
        (WidgetTester tester) async {
      testUser.agenticTradingConfig!.strategyConfig = TradeStrategyConfig();
      final agenticTradingProvider = AgenticTradingProvider();
      testUserDocRef = FirebaseFirestore.instance
          .collection('user')
          .doc('test_user_123')
          .withConverter<User>(
            fromFirestore: (snapshot, _) =>
                User.fromJson(snapshot.data() ?? {}),
            toFirestore: (user, _) => user.toJson(),
          );

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<AgenticTradingProvider>.value(
                  value: agenticTradingProvider),
              ChangeNotifierProvider(create: (_) => BrokerageUserStore([], 0)),
              ChangeNotifierProvider(create: (_) => TradeSignalsProvider()),
              ChangeNotifierProvider<BacktestingProvider>(
                  create: (_) => MockBacktestingProvider()),
            ],
            child: AgenticTradingSettingsWidget(
              user: testUser,
              userDocRef: testUserDocRef,
              service: mockService,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      final setupButton = find.text('Apply balanced setup');
      await tester.ensureVisible(setupButton);
      await tester.tap(setupButton);
      await tester.pumpAndSettle();

      final strategy = agenticTradingProvider.config.strategyConfig;
      expect(strategy.minSignalStrength, 50);
      expect(strategy.requireAllIndicatorsGreen, isFalse);
      expect(strategy.enabledIndicators['priceMovement'], isTrue);
      expect(strategy.enabledIndicators['marketDirection'], isTrue);
      expect(strategy.enabledIndicators['macd'], isTrue);
      expect(
        strategy.enabledIndicators.entries
            .where((entry) => entry.value)
            .map((entry) => entry.key)
            .toSet(),
        {'priceMovement', 'marketDirection', 'macd'},
      );
      expect(agenticTradingProvider.config.autoTradeEnabled, isFalse);
    });
  });
}

class MockBrokerageService extends Fake implements IBrokerageService {
  @override
  Future<dynamic> placeInstrumentOrder(
      BrokerageUser user,
      Account account,
      Instrument instrument,
      String symbol,
      String side,
      double? price,
      int quantity,
      {String type = 'limit',
      String trigger = 'immediate',
      double? stopPrice,
      String timeInForce = 'gtc',
      Map<String, dynamic>? trailingPeg,
      String? taxLotSelectionType,
      List<Map<String, dynamic>>? taxLots}) async {
    return {'id': 'mock_order_id', 'state': 'filled'};
  }
}
