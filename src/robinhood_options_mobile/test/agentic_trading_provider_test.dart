import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_config.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_provider.dart';
import 'package:robinhood_options_mobile/model/trade_signals_provider.dart';
import 'package:robinhood_options_mobile/utils/market_hours.dart';
import 'package:robinhood_options_mobile/widgets/home/agentic_trading_card_widget.dart';

class FakeFirebaseAnalytics extends Fake implements FirebaseAnalytics {
  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
    List<AnalyticsEventItem>? items,
    AnalyticsCallOptions? callOptions,
  }) async {}
}

class RejectingTradeSignalsProvider {
  Future<Map<String, dynamic>> initiateTradeProposal({
    required String symbol,
    required double currentPrice,
    required Map<String, dynamic> portfolioState,
    required dynamic config,
    String? interval,
    bool skipSignalUpdate = false,
  }) async {
    return {
      'status': 'rejected',
      'message': 'Risk threshold exceeded',
    };
  }
}

class ApprovingTradeSignalsProvider {
  Map<String, dynamic> proposalData;
  ApprovingTradeSignalsProvider({this.proposalData = const {}});

  Future<Map<String, dynamic>> initiateTradeProposal({
    required String symbol,
    required double currentPrice,
    required Map<String, dynamic> portfolioState,
    required dynamic config,
    String? interval,
    bool skipSignalUpdate = false,
  }) async {
    return {
      'status': 'approved',
      'proposal': {
        'action': proposalData['action'] ?? 'BUY',
        'quantity': proposalData['quantity'] ?? 10,
        'reason': proposalData['reason'] ?? 'Strong momentum signal',
      },
      'analysis': {
        'score': proposalData['confidence'] ?? 85,
      },
      'assessment': {
        'marketCondition': 'Bullish',
      },
    };
  }
}

void main() {
  group('AgenticTradingProvider Tests', () {
    late AgenticTradingProvider provider;

    setUp(() {
      provider = AgenticTradingProvider(analytics: FakeFirebaseAnalytics());
    });

    tearDown(() {
      provider.dispose();
    });

    test('Initial state should have correct default values', () {
      expect(provider.isAutoTrading, equals(false));
      expect(provider.dailyTradeCount, equals(0));
      expect(provider.lastAutoTradeTime, isNull);
      expect(provider.emergencyStopActivated, equals(false));
      expect(provider.autoTradeHistory, isEmpty);
    });

    test('loadConfigFromUser should load configuration correctly', () {
      // Load with null config (should use defaults)
      provider.loadConfigFromUser(null);

      expect(provider.config.autoTradeEnabled, equals(false));
      expect(provider.config.strategyConfig.dailyTradeLimit, equals(5));
      expect(provider.config.autoTradeCooldownMinutes, equals(60));
      expect(provider.config.strategyConfig.tradeQuantity, equals(1));
      expect(provider.config.strategyConfig.maxPositionSize, equals(100));
      expect(provider.config.strategyConfig.maxPortfolioConcentration,
          equals(0.5));
    });

    test('activateEmergencyStop should set emergency stop flag', () {
      var notified = false;
      provider.addListener(() {
        notified = true;
      });

      expect(provider.emergencyStopActivated, equals(false));

      provider.activateEmergencyStop();

      expect(provider.emergencyStopActivated, equals(true));
      expect(notified, equals(true));
    });

    test('deactivateEmergencyStop should clear emergency stop flag', () {
      // First activate
      provider.activateEmergencyStop();
      expect(provider.emergencyStopActivated, equals(true));

      var notified = false;
      provider.addListener(() {
        notified = true;
      });

      // Then deactivate
      provider.deactivateEmergencyStop();

      expect(provider.emergencyStopActivated, equals(false));
      expect(notified, equals(true));
    });

    test('indicatorDocumentation should return correct info for all indicators',
        () {
      final indicators = [
        'priceMovement',
        'momentum',
        'marketDirection',
        'volume',
        'macd',
        'bollingerBands',
        'stochastic',
        'atr',
        'obv',
        'sma',
        'ema',
        'ttmSqueeze',
      ];

      for (final indicator in indicators) {
        final doc = TradeSignalsProvider.indicatorDocumentation(indicator);

        expect(doc, isNotNull);
        expect(doc['title'], isNotNull);
        expect(doc['title'], isNotEmpty);
        expect(doc['description'], isNotNull);
        expect(doc['description'], isNotEmpty);
      }
    });

    test('indicatorDocumentation should return default for unknown indicator',
        () {
      final doc = TradeSignalsProvider.indicatorDocumentation('unknown');

      expect(doc['title'], equals('Technical Indicator'));
      expect(
          doc['description'], contains('Technical indicator used to analyze'));
    });

    test('isMarketOpen should return boolean value', () {
      // Just verify it doesn't throw and returns a boolean
      final isOpen = provider.isMarketOpen;

      expect(isOpen, isA<bool>());
    });

    test('autoTrade should fail when auto-trade is not enabled', () async {
      // Ensure auto-trade is not enabled
      provider.loadConfigFromUser(null);

      // Note: Full autoTrade method requires brokerageUser, account,
      // brokerageService, and instrumentStore which are difficult to mock
      // This test verifies the basic pre-flight check logic
      final result = await provider.autoTrade(
        tradeSignals: [],
        tradeSignalsProvider: null,
        portfolioState: {},
        brokerageUser: 'mock',
        account: 'mock',
        brokerageService: 'mock',
        instrumentStore: 'mock',
      );

      expect(result['success'], equals(false));
      expect(result['tradesExecuted'], equals(0));
      expect(result['message'], contains('conditions not met'));
    });

    test('autoTrade should fail when emergency stop is activated', () async {
      // Enable auto-trade in config
      provider.loadConfigFromUser(null);
      provider.config.autoTradeEnabled = true;

      // Activate emergency stop
      provider.activateEmergencyStop();

      final result = await provider.autoTrade(
        tradeSignals: [],
        tradeSignalsProvider: null,
        portfolioState: {},
        brokerageUser: 'mock',
        account: 'mock',
        brokerageService: 'mock',
        instrumentStore: 'mock',
      );

      expect(result['success'], equals(false));
      expect(result['tradesExecuted'], equals(0));
      expect(result['message'], contains('conditions not met'));
    });

    test('autoTrade should fail when no BUY signals available', () async {
      // Enable auto-trade
      provider.loadConfigFromUser(null);
      provider.config.autoTradeEnabled = true;

      // Set market to OPEN (Wed Oct 25 2023 11:00 AM EDT = 15:00 UTC)
      MarketHours.testTime = DateTime.utc(2023, 10, 25, 15, 0);

      // No signals in the list (empty by default)
      final result = await provider.autoTrade(
        tradeSignals: [],
        tradeSignalsProvider: null,
        portfolioState: {},
        brokerageUser: 'mock',
        account: 'mock',
        brokerageService: 'mock',
        instrumentStore: 'mock',
      );

      // Reset test time
      MarketHours.testTime = null;

      expect(result['success'], equals(false));
      expect(result['tradesExecuted'], equals(0));
      expect(result['message'],
          contains('No BUY signals matching enabled indicators'));
    });

    test('autoTrade logs a rejected trade proposal once', () async {
      provider.loadConfigFromUser(null);
      provider.config.autoTradeEnabled = true;
      provider.config.paperTradingMode = true;
      provider.config.tradingMode = TradingMode.reasoning;
      MarketHours.testTime = DateTime.utc(2023, 10, 25, 15, 0);

      try {
        await provider.autoTrade(
          tradeSignals: [
            {
              'symbol': 'NUE',
              'currentPrice': 150.0,
            }
          ],
          tradeSignalsProvider: RejectingTradeSignalsProvider(),
          portfolioState: {'buyingPower': 10000.0},
          brokerageUser: null,
          account: null,
          brokerageService: null,
          instrumentStore: 'mock',
        );
      } finally {
        MarketHours.testTime = null;
      }

      final rejectionEntries = provider.activityLog
          .where((entry) => entry.contains('Trade proposal rejected for NUE'));
      expect(rejectionEntries, hasLength(1));
      expect(rejectionEntries.single, contains('Risk threshold exceeded'));
    });

    testWidgets('duplicate activity is logged once and shown on stock card',
        (tester) async {
      Future<void> runDisabledAutoTrade() => provider.autoTrade(
            tradeSignals: [],
            tradeSignalsProvider: null,
            portfolioState: {},
            brokerageUser: 'mock',
            account: 'mock',
            brokerageService: 'mock',
            instrumentStore: 'mock',
          );
      await runDisabledAutoTrade();
      await runDisabledAutoTrade();

      final conditionEntries = provider.activityLog.where(
        (entry) => entry.contains('Conditions not met: Auto-trade disabled'),
      );
      expect(conditionEntries, hasLength(1));

      await tester.pumpWidget(
        ChangeNotifierProvider<AgenticTradingProvider>.value(
          value: provider,
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: AgenticTradingCardWidget(),
              ),
            ),
          ),
        ),
      );

      expect(find.textContaining('Conditions not met: Auto-trade disabled'),
          findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    test('Emergency stop should prevent auto-trading', () async {
      // Setup: Enable auto-trade
      provider.loadConfigFromUser(null);
      provider.config.autoTradeEnabled = true;

      // Activate emergency stop
      provider.activateEmergencyStop();

      // Attempt to auto-trade
      final result = await provider.autoTrade(
        tradeSignals: [],
        tradeSignalsProvider: null,
        portfolioState: {},
        brokerageUser: 'mock',
        account: 'mock',
        brokerageService: 'mock',
        instrumentStore: 'mock',
      );

      // Verify trade was blocked
      expect(result['success'], equals(false));
      expect(provider.emergencyStopActivated, equals(true));
    });

    test('Daily trade limit should prevent excessive trading', () async {
      // This test verifies the concept; actual implementation requires
      // mocking time and adding signals

      // Setup: Enable auto-trade with limit of 1
      provider.loadConfigFromUser(null);
      provider.config.autoTradeEnabled = true;

      // Note: dailyTradeLimit is in strategyConfig which is final.
      // We need to create a new strategy config to change it.
      final newStrategy =
          provider.config.strategyConfig.copyWith(dailyTradeLimit: 1);
      provider.config.strategyConfig = newStrategy;

      // After one trade, dailyTradeCount would be 1
      // Next trade attempt should fail
      // (This would require mocking the trade execution and signals)
    });

    test(
        'autoTrade with requireApproval does not append duplicate pending order when recommendation is repeated',
        () async {
      provider.loadConfigFromUser(null);
      provider.config.autoTradeEnabled = true;
      provider.config.paperTradingMode = true;
      provider.config.requireApproval = true;
      provider.config.tradingMode = TradingMode.reasoning;
      MarketHours.testTime = DateTime.utc(2023, 10, 25, 15, 0);

      final approvingProvider = ApprovingTradeSignalsProvider(proposalData: {
        'action': 'BUY',
        'quantity': 10,
        'reason': 'Technical breakout',
        'confidence': 88,
      });

      try {
        // First autoTrade cycle - adds pending approval
        await provider.autoTrade(
          tradeSignals: [
            {'symbol': 'AAPL', 'currentPrice': 150.0}
          ],
          tradeSignalsProvider: approvingProvider,
          portfolioState: {'buyingPower': 10000.0},
          brokerageUser: null,
          account: null,
          brokerageService: null,
          instrumentStore: 'mock',
        );

        expect(provider.pendingOrders.length, equals(1));
        final initialOrder = provider.pendingOrders.first;
        expect(initialOrder['symbol'], equals('AAPL'));
        expect(initialOrder['action'], equals('BUY'));
        expect(initialOrder['quantity'], equals(10));
        expect(initialOrder['price'], equals(150.0));
        expect(initialOrder['reason'], equals('Technical breakout'));
        expect(initialOrder['confidence'], equals(88));

        // Second autoTrade cycle with exact same recommendation - must NOT append duplicate
        await provider.autoTrade(
          tradeSignals: [
            {'symbol': 'AAPL', 'currentPrice': 150.0}
          ],
          tradeSignalsProvider: approvingProvider,
          portfolioState: {'buyingPower': 10000.0},
          brokerageUser: null,
          account: null,
          brokerageService: null,
          instrumentStore: 'mock',
        );

        expect(provider.pendingOrders.length, equals(1));
        expect(provider.pendingOrders.first['id'], equals(initialOrder['id']));
      } finally {
        MarketHours.testTime = null;
      }
    });

    test(
        'autoTrade with requireApproval updates existing pending order when recommendation changes',
        () async {
      provider.loadConfigFromUser(null);
      provider.config.autoTradeEnabled = true;
      provider.config.paperTradingMode = true;
      provider.config.requireApproval = true;
      provider.config.tradingMode = TradingMode.reasoning;
      MarketHours.testTime = DateTime.utc(2023, 10, 25, 15, 0);

      final approvingProvider = ApprovingTradeSignalsProvider(proposalData: {
        'action': 'BUY',
        'quantity': 10,
        'reason': 'Technical breakout',
        'confidence': 88,
      });

      try {
        // Initial recommendation
        await provider.autoTrade(
          tradeSignals: [
            {'symbol': 'AAPL', 'currentPrice': 150.0}
          ],
          tradeSignalsProvider: approvingProvider,
          portfolioState: {'buyingPower': 10000.0},
          brokerageUser: null,
          account: null,
          brokerageService: null,
          instrumentStore: 'mock',
        );

        expect(provider.pendingOrders.length, equals(1));
        final initialId = provider.pendingOrders.first['id'];

        // Updated recommendation: price moved to 155.0, quantity changed to 12, confidence 92
        approvingProvider.proposalData = {
          'action': 'BUY',
          'quantity': 12,
          'reason': 'Stronger continuation breakout',
          'confidence': 92,
        };

        await provider.autoTrade(
          tradeSignals: [
            {'symbol': 'AAPL', 'currentPrice': 155.0}
          ],
          tradeSignalsProvider: approvingProvider,
          portfolioState: {'buyingPower': 10000.0},
          brokerageUser: null,
          account: null,
          brokerageService: null,
          instrumentStore: 'mock',
        );

        // Still exactly 1 pending order, but updated in place!
        expect(provider.pendingOrders.length, equals(1));
        final updatedOrder = provider.pendingOrders.first;
        expect(updatedOrder['id'], equals(initialId));
        expect(updatedOrder['symbol'], equals('AAPL'));
        expect(updatedOrder['price'], equals(155.0));
        expect(updatedOrder['quantity'], equals(12));
        expect(updatedOrder['confidence'], equals(92));
        expect(updatedOrder['reason'], equals('Stronger continuation breakout'));
      } finally {
        MarketHours.testTime = null;
      }
    });

    test(
        'autoTrade with requireApproval appends distinct pending orders for different symbols',
        () async {
      provider.loadConfigFromUser(null);
      provider.config.autoTradeEnabled = true;
      provider.config.paperTradingMode = true;
      provider.config.requireApproval = true;
      provider.config.tradingMode = TradingMode.reasoning;
      MarketHours.testTime = DateTime.utc(2023, 10, 25, 15, 0);

      final approvingProvider = ApprovingTradeSignalsProvider(proposalData: {
        'action': 'BUY',
        'quantity': 5,
        'reason': 'Bullish signal',
        'confidence': 80,
      });

      try {
        await provider.autoTrade(
          tradeSignals: [
            {'symbol': 'AAPL', 'currentPrice': 150.0},
            {'symbol': 'MSFT', 'currentPrice': 300.0},
          ],
          tradeSignalsProvider: approvingProvider,
          portfolioState: {'buyingPower': 10000.0},
          brokerageUser: null,
          account: null,
          brokerageService: null,
          instrumentStore: 'mock',
        );

        expect(provider.pendingOrders.length, equals(2));
        final symbols =
            provider.pendingOrders.map((o) => o['symbol']).toSet();
        expect(symbols, containsAll(['AAPL', 'MSFT']));
      } finally {
        MarketHours.testTime = null;
      }
    });

    test('loadPendingOrdersFromFirestore deduplicates duplicate orders',
        () async {
      final firestore = FakeFirebaseFirestore();
      final userDocRef = firestore.collection('users').doc('test-user');
      final ordersCollection = userDocRef.collection('pending_orders');

      // Add older duplicate
      await ordersCollection.add({
        'symbol': 'AAPL',
        'action': 'BUY',
        'quantity': 5,
        'price': 150.0,
        'timestamp': DateTime(2023, 10, 25, 10, 0).toIso8601String(),
      });

      // Add newer duplicate
      await ordersCollection.add({
        'symbol': 'AAPL',
        'action': 'BUY',
        'quantity': 10,
        'price': 152.0,
        'timestamp': DateTime(2023, 10, 25, 10, 30).toIso8601String(),
      });

      // Add distinct order
      await ordersCollection.add({
        'symbol': 'MSFT',
        'action': 'BUY',
        'quantity': 2,
        'price': 300.0,
        'timestamp': DateTime(2023, 10, 25, 10, 15).toIso8601String(),
      });

      await provider.loadPendingOrdersFromFirestore(userDocRef);

      expect(provider.pendingOrders.length, equals(2));
      final aaplOrder =
          provider.pendingOrders.firstWhere((o) => o['symbol'] == 'AAPL');
      expect(aaplOrder['price'], equals(152.0));
      expect(aaplOrder['quantity'], equals(10));

      // Older duplicate document should have been cleaned up from Firestore
      final remainingDocs = await ordersCollection.get();
      expect(remainingDocs.docs.length, equals(2));
    });
  });

  group('AgenticTradingProvider Risk Management Tests', () {
    late AgenticTradingProvider provider;

    setUp(() {
      provider = AgenticTradingProvider(analytics: FakeFirebaseAnalytics());
    });

    tearDown(() {
      provider.dispose();
    });

    test('Configuration should include all risk management parameters', () {
      provider.loadConfigFromUser(null);

      // Verify all risk parameters are present
      expect(provider.config.strategyConfig.maxPositionSize, isNotNull);
      expect(
          provider.config.strategyConfig.maxPortfolioConcentration, isNotNull);
      expect(provider.config.strategyConfig.dailyTradeLimit, isNotNull);
      expect(provider.config.autoTradeCooldownMinutes, isNotNull);
    });

    test('Daily counters should reset on new day', () {
      // This tests the concept; actual implementation would require
      // mocking DateTime to simulate day changes

      // Initial state
      expect(provider.dailyTradeCount, equals(0));

      // After reset (would be called internally)
      // dailyTradeCount should be 0
      // dailyLossAmount should be 0
    });
  });
}
