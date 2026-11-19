import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_config.dart';
import 'package:robinhood_options_mobile/model/strategy_archetype.dart';

void main() {
  group('StrategyArchetype Model Tests', () {
    test('Curated archetypes contains exactly 4 distinct archetypes', () {
      expect(StrategyArchetypes.curated.length, 4);

      final ids = StrategyArchetypes.curated.map((a) => a.id).toSet();
      expect(ids.length, 4);

      expect(ids, contains('archetype_conservative_core'));
      expect(ids, contains('archetype_momentum_breakout'));
      expect(ids, contains('archetype_options_income_harvester'));
      expect(ids, contains('archetype_reasoning_ai_agent'));
    });

    test('findById returns the correct archetype or null for unknown', () {
      final core = StrategyArchetypes.findById('archetype_conservative_core');
      expect(core, isNotNull);
      expect(core?.name, 'Conservative Core');

      final unknown = StrategyArchetypes.findById('unknown_archetype');
      expect(unknown, isNull);
    });

    test('All archetypes have valid Walk-Forward performance metrics', () {
      for (final archetype in StrategyArchetypes.curated) {
        final wf = archetype.walkForwardMetrics;

        expect(wf.winRate, greaterThan(0));
        expect(wf.winRate, lessThanOrEqualTo(100));

        expect(wf.profitFactor, greaterThan(1.0),
            reason: '${archetype.name} should be profitable');

        expect(wf.maxDrawdownPercent, greaterThan(0));
        expect(wf.maxDrawdownPercent, lessThan(100));

        expect(wf.sharpeRatio, greaterThan(1.0));
        expect(wf.totalTrades, greaterThan(20));
        expect(wf.totalReturnPercent, greaterThan(0));
      }
    });

    test('Conservative Core invariants', () {
      final core = StrategyArchetypes.conservativeCore;
      expect(core.tradingMode, TradingMode.systematic);
      expect(core.config.riskPerTrade, 0.01);
      expect(core.config.maxPortfolioConcentration, 0.20);
      expect(core.config.maxDrawdown, 0.08);
      expect(core.config.enableGexStructuralStops, isTrue);
      expect(core.config.takeProfitPercent, 6.0);
      expect(core.config.stopLossPercent, 3.0);
      expect(core.walkForwardMetrics.winRate, 68.5);
      expect(core.walkForwardMetrics.maxDrawdownPercent, 5.4);
    });

    test('Momentum Breakout invariants', () {
      final breakout = StrategyArchetypes.momentumBreakout;
      expect(breakout.tradingMode, TradingMode.systematic);
      expect(breakout.config.riskPerTrade, 0.02);
      expect(breakout.config.takeProfitPercent, 12.0);
      expect(breakout.config.stopLossPercent, 4.5);
      expect(breakout.config.trailingStopEnabled, isTrue);
      expect(breakout.config.enableCatastrophicStop, isTrue);
      expect(breakout.walkForwardMetrics.profitFactor, 2.14);
      expect(breakout.config.enabledIndicators['macd'], isTrue);
      expect(breakout.config.enabledIndicators['vwap'], isTrue);
    });

    test('Options Income Harvester invariants', () {
      final options = StrategyArchetypes.optionsIncomeHarvester;
      expect(options.tradingMode, TradingMode.systematic);
      expect(options.config.riskPerTrade, 0.015);
      expect(options.config.enableGexStructuralStops, isTrue);
      expect(options.config.enableTimeThetaStop, isTrue);
      expect(options.config.minDteStopDays, 14);
      expect(options.config.stalledSessionsStopLimit, 5);
      expect(options.walkForwardMetrics.winRate, 76.2);
      expect(options.config.enabledIndicators['gammaExposure'], isTrue);
    });

    test('Reasoning AI Agent invariants', () {
      final ai = StrategyArchetypes.reasoningAiAgent;
      expect(ai.tradingMode, TradingMode.reasoning);
      expect(ai.config.minSignalStrength, 75.0);
      expect(ai.config.enableMacroRegimeStop, isTrue);
      expect(ai.walkForwardMetrics.winRate, 64.6);
      expect(ai.config.enabledIndicators['gammaExposure'], isTrue);
      expect(ai.config.enabledIndicators.values.where((v) => v).length,
          greaterThanOrEqualTo(19));
    });

    test(
        'toTemplate converts archetype into TradeStrategyTemplate with custom naming',
        () {
      final archetype = StrategyArchetypes.conservativeCore;
      final defaultTemplate = archetype.toTemplate();

      expect(defaultTemplate.id, 'default_archetype_conservative_core');
      expect(defaultTemplate.name, 'Conservative Core');
      expect(defaultTemplate.config.riskPerTrade, 0.01);

      final customTemplate = archetype.toTemplate(
        customName: 'My Custom Core',
        customId: 'custom_123',
      );
      expect(customTemplate.id, 'custom_123');
      expect(customTemplate.name, 'My Custom Core');
    });

    test('toJson and fromJson round-trip preserves all fields', () {
      for (final archetype in StrategyArchetypes.curated) {
        final json = archetype.toJson();
        final reconstructed = StrategyArchetype.fromJson(json);

        expect(reconstructed.id, archetype.id);
        expect(reconstructed.name, archetype.name);
        expect(reconstructed.tag, archetype.tag);
        expect(reconstructed.description, archetype.description);
        expect(reconstructed.detailedPhilosophy, archetype.detailedPhilosophy);
        expect(reconstructed.tradingMode, archetype.tradingMode);
        expect(reconstructed.targetMarketRegime, archetype.targetMarketRegime);
        expect(reconstructed.walkForwardMetrics.winRate,
            archetype.walkForwardMetrics.winRate);
        expect(reconstructed.walkForwardMetrics.profitFactor,
            archetype.walkForwardMetrics.profitFactor);
        expect(reconstructed.walkForwardMetrics.maxDrawdownPercent,
            archetype.walkForwardMetrics.maxDrawdownPercent);
        expect(reconstructed.config.takeProfitPercent,
            archetype.config.takeProfitPercent);
        expect(reconstructed.config.stopLossPercent,
            archetype.config.stopLossPercent);
      }
    });
  });
}
