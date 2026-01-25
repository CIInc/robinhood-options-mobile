import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_config.dart';
import 'package:robinhood_options_mobile/model/trade_strategy_config.dart';

void main() {
  group('AgenticTradingConfig Tests', () {
    test('AgenticTradingConfig should serialize and deserialize all fields',
        () {
      // Create a config with all fields set
      final strategyConfig = TradeStrategyConfig(
        smaPeriodFast: 12,
        smaPeriodSlow: 26,
        tradeQuantity: 10,
        rsiPeriod: 14,
        marketIndexSymbol: 'QQQ',
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
        enableSectorLimits: true,
        maxSectorExposure: 0.15,
        enableCorrelationChecks: true,
        maxCorrelation: 0.75,
        enableVolatilityFilters: true,
        minVolatility: 0.05,
        maxVolatility: 0.45,
        enableDrawdownProtection: true,
        maxDrawdown: 0.08,
        rsiExitEnabled: true,
        rsiExitThreshold: 85.0,
        signalStrengthExitEnabled: true,
        signalStrengthExitThreshold: 45.0,
        maxPositionSize: 200,
        maxPortfolioConcentration: 0.3,
        dailyTradeLimit: 10,
      );

      final config = AgenticTradingConfig(
        strategyConfig: strategyConfig,
        autoTradeEnabled: true,
        autoTradeCooldownMinutes: 30,
      );

      // Convert to JSON
      final json = config.toJson();

      // Verify JSON contains all fields (nested strategy config)
      expect(json['strategyConfig']['smaPeriodFast'], equals(12));
      expect(json['strategyConfig']['smaPeriodSlow'], equals(26));
      expect(json['strategyConfig']['tradeQuantity'], equals(10));
      expect(json['strategyConfig']['maxPositionSize'], equals(200));
      expect(json['strategyConfig']['maxPortfolioConcentration'], equals(0.3));
      expect(json['strategyConfig']['rsiPeriod'], equals(14));
      expect(json['strategyConfig']['marketIndexSymbol'], equals('QQQ'));
      expect(json['autoTradeEnabled'], equals(true));
      expect(json['strategyConfig']['dailyTradeLimit'], equals(10));
      expect(json['autoTradeCooldownMinutes'], equals(30));
      expect(
          json['strategyConfig']['enableDynamicPositionSizing'], equals(true));
      expect(json['strategyConfig']['riskPerTrade'], equals(0.02));
      expect(json['strategyConfig']['atrMultiplier'], equals(2.5));
      expect(json['strategyConfig']['takeProfitPercent'], equals(15.0));
      expect(json['strategyConfig']['stopLossPercent'], equals(7.5));
      expect(json['strategyConfig']['enabledIndicators']['priceMovement'],
          equals(true));
      expect(json['strategyConfig']['enabledIndicators']['momentum'],
          equals(false));
      expect(json['strategyConfig']['enableSectorLimits'], equals(true));
      expect(json['strategyConfig']['maxSectorExposure'], equals(0.15));
      expect(json['strategyConfig']['enableCorrelationChecks'], equals(true));
      expect(json['strategyConfig']['maxCorrelation'], equals(0.75));
      expect(json['strategyConfig']['enableVolatilityFilters'], equals(true));
      expect(json['strategyConfig']['minVolatility'], equals(0.05));
      expect(json['strategyConfig']['maxVolatility'], equals(0.45));
      expect(json['strategyConfig']['enableDrawdownProtection'], equals(true));
      expect(json['strategyConfig']['maxDrawdown'], equals(0.08));
      expect(json['strategyConfig']['rsiExitEnabled'], equals(true));
      expect(json['strategyConfig']['rsiExitThreshold'], equals(85.0));
      expect(json['strategyConfig']['signalStrengthExitEnabled'], equals(true));
      expect(
          json['strategyConfig']['signalStrengthExitThreshold'], equals(45.0));

      // Deserialize from JSON
      final deserializedConfig = AgenticTradingConfig.fromJson(json);

      // Verify all fields are correctly deserialized
      expect(deserializedConfig.strategyConfig.smaPeriodFast, equals(12));
      expect(deserializedConfig.strategyConfig.smaPeriodSlow, equals(26));
      expect(deserializedConfig.strategyConfig.tradeQuantity, equals(10));
      expect(deserializedConfig.strategyConfig.maxPositionSize, equals(200));
      expect(deserializedConfig.strategyConfig.maxPortfolioConcentration,
          equals(0.3));
      expect(deserializedConfig.strategyConfig.enableDynamicPositionSizing,
          equals(true));
      expect(deserializedConfig.strategyConfig.riskPerTrade, equals(0.02));
      expect(deserializedConfig.strategyConfig.atrMultiplier, equals(2.5));
      expect(deserializedConfig.strategyConfig.rsiPeriod, equals(14));
      expect(
          deserializedConfig.strategyConfig.marketIndexSymbol, equals('QQQ'));
      expect(deserializedConfig.autoTradeEnabled, equals(true));
      expect(deserializedConfig.strategyConfig.dailyTradeLimit, equals(10));
      expect(deserializedConfig.autoTradeCooldownMinutes, equals(30));
      expect(deserializedConfig.strategyConfig.takeProfitPercent, equals(15.0));
      expect(deserializedConfig.strategyConfig.stopLossPercent, equals(7.5));
      expect(
          deserializedConfig.strategyConfig.enabledIndicators['priceMovement'],
          equals(true));
      expect(deserializedConfig.strategyConfig.enabledIndicators['momentum'],
          equals(false));
      expect(
          deserializedConfig.strategyConfig.enableSectorLimits, equals(true));
      expect(deserializedConfig.strategyConfig.maxSectorExposure, equals(0.15));
      expect(deserializedConfig.strategyConfig.enableCorrelationChecks,
          equals(true));
      expect(deserializedConfig.strategyConfig.maxCorrelation, equals(0.75));
      expect(deserializedConfig.strategyConfig.enableVolatilityFilters,
          equals(true));
      expect(deserializedConfig.strategyConfig.minVolatility, equals(0.05));
      expect(deserializedConfig.strategyConfig.maxVolatility, equals(0.45));
      expect(deserializedConfig.strategyConfig.enableDrawdownProtection,
          equals(true));
      expect(deserializedConfig.strategyConfig.maxDrawdown, equals(0.08));
      expect(deserializedConfig.strategyConfig.rsiExitEnabled, equals(true));
      expect(deserializedConfig.strategyConfig.rsiExitThreshold, equals(85.0));
      expect(deserializedConfig.strategyConfig.signalStrengthExitEnabled,
          equals(true));
      expect(deserializedConfig.strategyConfig.signalStrengthExitThreshold,
          equals(45.0));
    });

    test('AgenticTradingConfig should have correct default values', () {
      final config =
          AgenticTradingConfig(strategyConfig: TradeStrategyConfig());

      // Verify default values
      expect(config.strategyConfig.smaPeriodFast, equals(10));
      expect(config.strategyConfig.smaPeriodSlow, equals(30));
      expect(config.strategyConfig.tradeQuantity, equals(1));
      expect(config.strategyConfig.maxPositionSize, equals(100));
      expect(config.strategyConfig.maxPortfolioConcentration, equals(0.5));
      expect(config.strategyConfig.rsiPeriod, equals(14));
      expect(config.strategyConfig.marketIndexSymbol, equals('SPY'));
      expect(config.autoTradeEnabled, equals(false));
      expect(config.strategyConfig.dailyTradeLimit, equals(5));
      expect(config.autoTradeCooldownMinutes, equals(60));
      expect(config.strategyConfig.takeProfitPercent, equals(10.0));
      expect(config.strategyConfig.stopLossPercent, equals(5.0));

      // Verify all indicators are enabled by default
      expect(config.strategyConfig.enabledIndicators['priceMovement'],
          equals(true));
      expect(config.strategyConfig.enabledIndicators['momentum'], equals(true));
      expect(config.strategyConfig.enabledIndicators['marketDirection'],
          equals(true));
      expect(config.strategyConfig.enabledIndicators['volume'], equals(true));
      expect(config.strategyConfig.enabledIndicators['macd'], equals(true));
      expect(config.strategyConfig.enabledIndicators['bollingerBands'],
          equals(true));
      expect(
          config.strategyConfig.enabledIndicators['stochastic'], equals(true));
      expect(config.strategyConfig.enabledIndicators['atr'], equals(true));
      expect(config.strategyConfig.enabledIndicators['obv'], equals(true));
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
      expect(config.strategyConfig.tradeQuantity, equals(5));
      expect(config.strategyConfig.maxPositionSize, equals(150));

      // Verify auto-trade fields use defaults when missing
      expect(config.autoTradeEnabled, equals(false));
      expect(config.strategyConfig.dailyTradeLimit, equals(5));
      expect(config.autoTradeCooldownMinutes, equals(60));
    });

    test('AgenticTradingConfig copyWith should work correctly', () {
      final original = AgenticTradingConfig(
        strategyConfig: TradeStrategyConfig(
          dailyTradeLimit: 5,
        ),
        autoTradeEnabled: false,
      );

      // Copy with some fields changed
      final updated = original.copyWith(
        autoTradeEnabled: true,
        strategyConfig: original.strategyConfig.copyWith(dailyTradeLimit: 10),
      );

      // Verify changed fields
      expect(updated.autoTradeEnabled, equals(true));
      expect(updated.strategyConfig.dailyTradeLimit, equals(10));

      // Verify unchanged fields remain the same
      expect(updated.strategyConfig.smaPeriodFast,
          equals(original.strategyConfig.smaPeriodFast));
      expect(updated.autoTradeCooldownMinutes,
          equals(original.autoTradeCooldownMinutes));
    });

    test('AgenticTradingConfig should validate risk management constraints',
        () {
      // Create config with various risk settings
      final config = AgenticTradingConfig(
        strategyConfig: TradeStrategyConfig(
          dailyTradeLimit: 5,
          maxPortfolioConcentration: 0.5,
        ),
        autoTradeEnabled: true,
      );

      // Verify risk management fields are set correctly
      expect(config.strategyConfig.dailyTradeLimit, equals(5));
      expect(config.strategyConfig.maxPortfolioConcentration, equals(0.5));
    });
  });
}
