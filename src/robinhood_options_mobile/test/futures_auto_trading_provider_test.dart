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

    test('highWaterMarks tracking', () {
      // Since high water marks are internal, we simulate cycles if we had more exposed methods
      // For now, testing config update is the priority.
    });
  });
}
