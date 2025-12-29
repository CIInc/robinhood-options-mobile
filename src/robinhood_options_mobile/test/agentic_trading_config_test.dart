import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_config.dart';

void main() {
  group('AgenticTradingConfig Tests', () {
    test('AgenticTradingConfig should serialize and deserialize all fields',
        () {
      // Create a config with all fields set
      final config = AgenticTradingConfig(
        smaPeriodFast: 12,
        smaPeriodSlow: 26,
        tradeQuantity: 10,
        maxPositionSize: 200,
        maxPortfolioConcentration: 0.3,
        rsiPeriod: 14,
        marketIndexSymbol: 'QQQ',
        autoTradeEnabled: true,
        dailyTradeLimit: 10,
        autoTradeCooldownMinutes: 30,
        maxDailyLossPercent: 1.5,
        takeProfitPercent: 15.0,
        stopLossPercent: 7.5,
        enableDynamicPositionSizing: true,
        riskPerTrade: 0.02,
        atrMultiplier: 2.5,
        enabledIndicators: {
          'priceMovement': true,
          'momentum': false,
          'marketDirection': true,
          'volume': true,
          'macd': false,
          'bollingerBands': true,
          'stochastic': false,
          'atr': true,
          'obv': false,
        },
      );

      // Convert to JSON
      final json = config.toJson();

      // Verify JSON contains all fields
      expect(json['smaPeriodFast'], equals(12));
      expect(json['smaPeriodSlow'], equals(26));
      expect(json['tradeQuantity'], equals(10));
      expect(json['maxPositionSize'], equals(200));
      expect(json['maxPortfolioConcentration'], equals(0.3));
      expect(json['rsiPeriod'], equals(14));
      expect(json['marketIndexSymbol'], equals('QQQ'));
      expect(json['autoTradeEnabled'], equals(true));
      expect(json['dailyTradeLimit'], equals(10));
      expect(json['autoTradeCooldownMinutes'], equals(30));
      expect(json['maxDailyLossPercent'], equals(1.5));
      expect(json['enableDynamicPositionSizing'], equals(true));
      expect(json['riskPerTrade'], equals(0.02));
      expect(json['atrMultiplier'], equals(2.5));
      expect(json['takeProfitPercent'], equals(15.0));
      expect(json['stopLossPercent'], equals(7.5));
      expect(json['enabledIndicators']['priceMovement'], equals(true));
      expect(json['enabledIndicators']['momentum'], equals(false));

      // Deserialize from JSON
      final deserializedConfig = AgenticTradingConfig.fromJson(json);

      // Verify all fields are correctly deserialized
      expect(deserializedConfig.smaPeriodFast, equals(12));
      expect(deserializedConfig.smaPeriodSlow, equals(26));
      expect(deserializedConfig.tradeQuantity, equals(10));
      expect(deserializedConfig.maxPositionSize, equals(200));
      expect(deserializedConfig.maxPortfolioConcentration, equals(0.3));
      expect(deserializedConfig.enableDynamicPositionSizing, equals(true));
      expect(deserializedConfig.riskPerTrade, equals(0.02));
      expect(deserializedConfig.atrMultiplier, equals(2.5));
      expect(deserializedConfig.rsiPeriod, equals(14));
      expect(deserializedConfig.marketIndexSymbol, equals('QQQ'));
      expect(deserializedConfig.autoTradeEnabled, equals(true));
      expect(deserializedConfig.dailyTradeLimit, equals(10));
      expect(deserializedConfig.autoTradeCooldownMinutes, equals(30));
      expect(deserializedConfig.maxDailyLossPercent, equals(1.5));
      expect(deserializedConfig.takeProfitPercent, equals(15.0));
      expect(deserializedConfig.stopLossPercent, equals(7.5));
      expect(
          deserializedConfig.enabledIndicators['priceMovement'], equals(true));
      expect(deserializedConfig.enabledIndicators['momentum'], equals(false));
    });

    test('AgenticTradingConfig should have correct default values', () {
      final config = AgenticTradingConfig();

      // Verify default values
      expect(config.smaPeriodFast, equals(10));
      expect(config.smaPeriodSlow, equals(30));
      expect(config.tradeQuantity, equals(1));
      expect(config.maxPositionSize, equals(100));
      expect(config.maxPortfolioConcentration, equals(0.5));
      expect(config.rsiPeriod, equals(14));
      expect(config.marketIndexSymbol, equals('SPY'));
      expect(config.autoTradeEnabled, equals(false));
      expect(config.dailyTradeLimit, equals(5));
      expect(config.autoTradeCooldownMinutes, equals(60));
      expect(config.maxDailyLossPercent, equals(2.0));
      expect(config.takeProfitPercent, equals(10.0));
      expect(config.stopLossPercent, equals(5.0));

      // Verify all indicators are enabled by default
      expect(config.enabledIndicators['priceMovement'], equals(true));
      expect(config.enabledIndicators['momentum'], equals(true));
      expect(config.enabledIndicators['marketDirection'], equals(true));
      expect(config.enabledIndicators['volume'], equals(true));
      expect(config.enabledIndicators['macd'], equals(true));
      expect(config.enabledIndicators['bollingerBands'], equals(true));
      expect(config.enabledIndicators['stochastic'], equals(true));
      expect(config.enabledIndicators['atr'], equals(true));
      expect(config.enabledIndicators['obv'], equals(true));
    });

    test(
        'AgenticTradingConfig fromJson should handle missing auto-trade fields',
        () {
      // Create JSON without auto-trade fields (simulating old config)
      final json = {
        'smaPeriodFast': 10,
        'smaPeriodSlow': 30,
        'tradeQuantity': 5,
        'maxPositionSize': 150,
        'maxPortfolioConcentration': 0.4,
        'rsiPeriod': 14,
        'marketIndexSymbol': 'SPY',
        'enabledIndicators': {
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
      };

      final config = AgenticTradingConfig.fromJson(json);

      // Verify existing fields are preserved
      expect(config.tradeQuantity, equals(5));
      expect(config.maxPositionSize, equals(150));

      // Verify auto-trade fields use defaults when missing
      expect(config.autoTradeEnabled, equals(false));
      expect(config.dailyTradeLimit, equals(5));
      expect(config.autoTradeCooldownMinutes, equals(60));
      expect(config.maxDailyLossPercent, equals(2.0));
    });

    test('AgenticTradingConfig copyWith should work correctly', () {
      final original = AgenticTradingConfig(
        autoTradeEnabled: false,
        dailyTradeLimit: 5,
      );

      // Copy with some fields changed
      final updated = original.copyWith(
        autoTradeEnabled: true,
        dailyTradeLimit: 10,
      );

      // Verify changed fields
      expect(updated.autoTradeEnabled, equals(true));
      expect(updated.dailyTradeLimit, equals(10));

      // Verify unchanged fields remain the same
      expect(updated.smaPeriodFast, equals(original.smaPeriodFast));
      expect(updated.autoTradeCooldownMinutes,
          equals(original.autoTradeCooldownMinutes));
    });

    test('AgenticTradingConfig should validate risk management constraints',
        () {
      // Create config with various risk settings
      final config = AgenticTradingConfig(
        autoTradeEnabled: true,
        dailyTradeLimit: 5,
        maxDailyLossPercent: 2.0,
        maxPortfolioConcentration: 0.5,
      );

      // Verify risk management fields are set correctly
      expect(config.dailyTradeLimit, equals(5));
      expect(config.maxDailyLossPercent, equals(2.0));
      expect(config.maxPortfolioConcentration, equals(0.5));
    });
  });
}
