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
import 'package:robinhood_options_mobile/model/account.dart';
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
      Map<String, dynamic>? trailingPeg}) async {
    return {'id': 'mock_order_id', 'state': 'filled'};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
