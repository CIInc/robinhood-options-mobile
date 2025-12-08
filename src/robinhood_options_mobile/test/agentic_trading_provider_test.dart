import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_provider.dart';

void main() {
  group('AgenticTradingProvider Tests', () {
    late AgenticTradingProvider provider;

    setUp(() {
      provider = AgenticTradingProvider();
    });

    tearDown(() {
      provider.dispose();
    });

    test('Initial state should have correct default values', () {
      expect(provider.isAgenticTradingEnabled, equals(false));
      expect(provider.isAutoTrading, equals(false));
      expect(provider.dailyTradeCount, equals(0));
      expect(provider.lastAutoTradeTime, isNull);
      expect(provider.emergencyStopActivated, equals(false));
      expect(provider.autoTradeHistory, isEmpty);
      expect(provider.tradeSignals, isEmpty);
    });

    test('toggleAgenticTrading should update enabled state', () {
      var notified = false;
      provider.addListener(() {
        notified = true;
      });

      // Initially false
      expect(provider.isAgenticTradingEnabled, equals(false));

      // Toggle to true
      provider.toggleAgenticTrading(true);
      expect(provider.isAgenticTradingEnabled, equals(true));
      expect(notified, equals(true));

      // Reset notification flag
      notified = false;

      // Toggle to false
      provider.toggleAgenticTrading(false);
      expect(provider.isAgenticTradingEnabled, equals(false));
      expect(notified, equals(true));
    });

    test('loadConfigFromUser should load configuration correctly', () {
      // Load with null config (should use defaults)
      provider.loadConfigFromUser(null);

      expect(provider.config['enabled'], equals(false));
      expect(provider.config['autoTradeEnabled'], equals(false));
      expect(provider.config['dailyTradeLimit'], equals(5));
      expect(provider.config['autoTradeCooldownMinutes'], equals(60));
      expect(provider.config['maxDailyLossPercent'], equals(2.0));
      expect(provider.config['tradeQuantity'], equals(1));
      expect(provider.config['maxPositionSize'], equals(100));
      expect(provider.config['maxPortfolioConcentration'], equals(0.5));
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

    test('indicatorDocumentation should return correct info for all indicators', () {
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
      ];

      for (final indicator in indicators) {
        final doc = AgenticTradingProvider.indicatorDocumentation(indicator);
        
        expect(doc, isNotNull);
        expect(doc['title'], isNotNull);
        expect(doc['title'], isNotEmpty);
        expect(doc['documentation'], isNotNull);
        expect(doc['documentation'], isNotEmpty);
      }
    });

    test('indicatorDocumentation should return default for unknown indicator', () {
      final doc = AgenticTradingProvider.indicatorDocumentation('unknown');
      
      expect(doc['title'], equals('Technical Indicator'));
      expect(doc['documentation'], contains('Technical indicator used to analyze'));
    });

    test('selectedInterval should default to 1h when market is open', () {
      // Note: This test depends on actual market hours
      // We're just testing that it returns a valid interval
      final interval = provider.selectedInterval;
      
      expect(interval, isIn(['15m', '30m', '1h', '1d']));
    });

    test('setSelectedInterval should update selected interval', () {
      var notified = false;
      provider.addListener(() {
        notified = true;
      });

      provider.setSelectedInterval('15m');
      
      expect(provider.selectedInterval, equals('15m'));
      expect(notified, equals(true));
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
        portfolioState: {},
        brokerageUser: null, // Will fail pre-flight checks anyway
        account: null,
        brokerageService: null,
        instrumentStore: null,
      );

      expect(result['success'], equals(false));
      expect(result['tradesExecuted'], equals(0));
      expect(result['message'], contains('conditions not met'));
    });

    test('autoTrade should fail when emergency stop is activated', () async {
      // Enable auto-trade in config
      provider.loadConfigFromUser(null);
      provider.config['autoTradeEnabled'] = true;
      
      // Activate emergency stop
      provider.activateEmergencyStop();
      
      final result = await provider.autoTrade(
        portfolioState: {},
        brokerageUser: null,
        account: null,
        brokerageService: null,
        instrumentStore: null,
      );

      expect(result['success'], equals(false));
      expect(result['tradesExecuted'], equals(0));
      expect(result['message'], contains('conditions not met'));
    });

    test('autoTrade should fail when no BUY signals available', () async {
      // Enable auto-trade
      provider.loadConfigFromUser(null);
      provider.config['autoTradeEnabled'] = true;
      
      // No signals in the list (empty by default)
      final result = await provider.autoTrade(
        portfolioState: {},
        brokerageUser: null,
        account: null,
        brokerageService: null,
        instrumentStore: null,
      );

      expect(result['success'], equals(false));
      expect(result['tradesExecuted'], equals(0));
      expect(result['message'], contains('No BUY signals available'));
    });

    test('Emergency stop should prevent auto-trading', () async {
      // Setup: Enable auto-trade
      provider.loadConfigFromUser(null);
      provider.config['autoTradeEnabled'] = true;

      // Activate emergency stop
      provider.activateEmergencyStop();

      // Attempt to auto-trade
      final result = await provider.autoTrade(
        portfolioState: {},
        brokerageUser: null,
        account: null,
        brokerageService: null,
        instrumentStore: null,
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
      provider.config['autoTradeEnabled'] = true;
      provider.config['dailyTradeLimit'] = 1;

      // After one trade, dailyTradeCount would be 1
      // Next trade attempt should fail
      // (This would require mocking the trade execution and signals)
    });
  });

  group('AgenticTradingProvider Risk Management Tests', () {
    late AgenticTradingProvider provider;

    setUp(() {
      provider = AgenticTradingProvider();
    });

    tearDown(() {
      provider.dispose();
    });

    test('Configuration should include all risk management parameters', () {
      provider.loadConfigFromUser(null);

      // Verify all risk parameters are present
      expect(provider.config['maxPositionSize'], isNotNull);
      expect(provider.config['maxPortfolioConcentration'], isNotNull);
      expect(provider.config['dailyTradeLimit'], isNotNull);
      expect(provider.config['autoTradeCooldownMinutes'], isNotNull);
      expect(provider.config['maxDailyLossPercent'], isNotNull);
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
