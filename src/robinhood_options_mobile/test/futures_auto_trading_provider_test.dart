import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:robinhood_options_mobile/model/futures_auto_trading_provider.dart';
import 'package:robinhood_options_mobile/model/futures_strategy_config.dart';
import 'firebase_mocks.dart';

void main() {
  group('FuturesAutoTradingProvider Tests', () {
    late FuturesAutoTradingProvider provider;
    late FakeFirebaseFirestore firestore;
    late FakeFirebaseAnalytics analytics;

    setUpAll(() async {
      await setupFirebaseMocks();
    });

    setUp(() {
      analytics = FakeFirebaseAnalytics();
      firestore = FakeFirebaseFirestore();
      provider = FuturesAutoTradingProvider(analytics: analytics);
    });

    test('Initial state should have correct default values', () {
      expect(provider.isAutoTrading, equals(false));
      expect(provider.autoTradeHistory, isEmpty);
      expect(provider.lastAutoTradeTime, isNull);
    });

    test('loadConfig should load configuration correctly', () async {
      final userDocRef = firestore.collection('users').doc('test-user');
      await userDocRef.set({'email': 'test@example.com'});

      final config = FuturesTradingConfig(
        strategyConfig: FuturesStrategyConfig(
          contractIds: ['ES', 'NQ'],
          tradeQuantity: 2,
          stopLossPct: 3.5,
          takeProfitPct: 7.0,
          trailingStopEnabled: true,
          trailingStopAtrMultiplier: 3.0,
          autoExitEnabled: true,
          autoExitBufferMinutes: 20,
          allowContractRollover: true,
          skipRiskGuard: true,
          multiIntervalAnalysis: true,
        ),
        autoTradeEnabled: true,
        paperTradingMode: true,
      );

      await provider.updateConfig(config, userDocRef);

      expect(provider.config.autoTradeEnabled, equals(true));
      expect(provider.config.paperTradingMode, equals(true));
      expect(provider.config.strategyConfig.contractIds, equals(['ES', 'NQ']));
      expect(provider.config.strategyConfig.tradeQuantity, equals(2));
      expect(provider.config.strategyConfig.stopLossPct, equals(3.5));
      expect(provider.config.strategyConfig.takeProfitPct, equals(7.0));
      expect(provider.config.strategyConfig.trailingStopEnabled, equals(true));
      expect(provider.config.strategyConfig.trailingStopAtrMultiplier,
          equals(3.0));
      expect(provider.config.strategyConfig.autoExitEnabled, equals(true));
      expect(provider.config.strategyConfig.autoExitBufferMinutes, equals(20));
      expect(
          provider.config.strategyConfig.allowContractRollover, equals(true));
      expect(provider.config.strategyConfig.skipRiskGuard, equals(true));
      expect(
          provider.config.strategyConfig.multiIntervalAnalysis, equals(true));

      // Verify Firestore update
      final doc = await userDocRef.get();
      expect(doc.data()!['futuresTradingConfig'], isNotNull);
      expect(doc.data()!['futuresTradingConfig']['autoTradeEnabled'],
          equals(true));
    });

    test('loadPendingOrdersFromFirestore deduplicates duplicate orders',
        () async {
      final userDocRef = firestore.collection('users').doc('test-user');
      final ordersCollection = userDocRef.collection('futures_pending_orders');

      // Add older duplicate
      await ordersCollection.add({
        'contractId': 'ES',
        'symbol': 'ES=F',
        'action': 'BUY',
        'quantity': 1,
        'price': 4500.0,
        'timestamp': DateTime(2023, 10, 25, 10, 0).toIso8601String(),
      });

      // Add newer duplicate
      await ordersCollection.add({
        'contractId': 'ES',
        'symbol': 'ES=F',
        'action': 'BUY',
        'quantity': 2,
        'price': 4510.0,
        'timestamp': DateTime(2023, 10, 25, 10, 30).toIso8601String(),
      });

      // Add distinct order
      await ordersCollection.add({
        'contractId': 'NQ',
        'symbol': 'NQ=F',
        'action': 'BUY',
        'quantity': 1,
        'price': 15000.0,
        'timestamp': DateTime(2023, 10, 25, 10, 15).toIso8601String(),
      });

      await provider.loadPendingOrdersFromFirestore(userDocRef);

      expect(provider.pendingOrders.length, equals(2));
      final esOrder =
          provider.pendingOrders.firstWhere((o) => o['contractId'] == 'ES');
      expect(esOrder['price'], equals(4510.0));
      expect(esOrder['quantity'], equals(2));

      // Older ES document should have been cleaned up from Firestore
      final remainingDocs = await ordersCollection.get();
      expect(remainingDocs.docs.length, equals(2));
    });
  });
}
