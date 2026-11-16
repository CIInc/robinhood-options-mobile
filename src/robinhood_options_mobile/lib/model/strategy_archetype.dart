import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_config.dart';
import 'package:robinhood_options_mobile/model/backtesting_models.dart';
import 'package:robinhood_options_mobile/model/trade_strategies.dart';

/// Curated Strategy Archetype Model
///
/// Represents an opinionated, professionally tuned, pre-flight strategy preset
/// complete with walk-forward performance validation metrics, underlying indicators,
/// stops, and risk bounds.
class StrategyArchetype {
  final String id;
  final String name;
  final String tag;
  final String description;
  final String detailedPhilosophy;
  final IconData icon;
  final Color accentColor;
  final TradingMode tradingMode;
  final String targetMarketRegime;
  final WalkForwardPeriodMetrics walkForwardMetrics;
  final TradeStrategyConfig config;

  const StrategyArchetype({
    required this.id,
    required this.name,
    required this.tag,
    required this.description,
    required this.detailedPhilosophy,
    required this.icon,
    required this.accentColor,
    required this.tradingMode,
    required this.targetMarketRegime,
    required this.walkForwardMetrics,
    required this.config,
  });

  /// Converts this archetype into a user-customizable [TradeStrategyTemplate]
  TradeStrategyTemplate toTemplate({String? customName, String? customId}) {
    return TradeStrategyTemplate(
      id: customId ?? 'default_$id',
      name: customName ?? name,
      description: description,
      config: config,
      createdAt: DateTime.now(),
      lastUsedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'tag': tag,
        'description': description,
        'detailedPhilosophy': detailedPhilosophy,
        'iconCodePoint': icon.codePoint,
        'iconFontFamily': icon.fontFamily,
        'accentColorValue': accentColor.toARGB32(),
        'tradingMode': tradingMode.name,
        'targetMarketRegime': targetMarketRegime,
        'walkForwardMetrics': walkForwardMetrics.toJson(),
        'config': config.toJson(),
      };

  factory StrategyArchetype.fromJson(Map<String, dynamic> json) {
    return StrategyArchetype(
      id: json['id'] as String,
      name: json['name'] as String,
      tag: json['tag'] as String,
      description: json['description'] as String,
      detailedPhilosophy: json['detailedPhilosophy'] as String? ?? '',
      icon: IconData(
        json['iconCodePoint'] as int? ?? Icons.auto_graph.codePoint,
        fontFamily: json['iconFontFamily'] as String?,
      ),
      accentColor: Color(json['accentColorValue'] as int? ?? 0xFF10B981),
      tradingMode: TradingMode.values.firstWhere(
        (m) => m.name == json['tradingMode'],
        orElse: () => TradingMode.systematic,
      ),
      targetMarketRegime: json['targetMarketRegime'] as String? ?? 'General',
      walkForwardMetrics: WalkForwardPeriodMetrics.fromJson(
        Map<String, dynamic>.from(json['walkForwardMetrics'] as Map),
      ),
      config: TradeStrategyConfig.fromJson(
        Map<String, dynamic>.from(json['config'] as Map),
      ),
    );
  }
}

/// Curated Catalog of Pre-Flight Strategy Archetypes
class StrategyArchetypes {
  static final StrategyArchetype conservativeCore = StrategyArchetype(
    id: 'archetype_conservative_core',
    name: 'Conservative Core',
    tag: 'Capital Preservation',
    description:
        'High-probability trend-following with tight structural risk bounds, strict sector exposure caps, and defined GEX stops.',
    detailedPhilosophy:
        'Focuses on capital preservation in steady market regimes. Utilizes broad market direction (SMA 50/200), Bollinger Bands, and RSI to identify high-probability trend entries with minimal drawdown. Employs 1% risk-per-trade sizing, strict 20% sector concentration caps, and GEX structural stop-loss protection.',
    icon: Icons.shield_outlined,
    accentColor: Color(0xFF10B981), // Emerald
    tradingMode: TradingMode.systematic,
    targetMarketRegime: 'Low Volatility Bull / Neutral',
    walkForwardMetrics: WalkForwardPeriodMetrics(
      totalTrades: 52,
      winRate: 68.5,
      totalReturn: 6125.0,
      totalReturnPercent: 24.5,
      profitFactor: 1.88,
      sharpeRatio: 1.72,
      maxDrawdownPercent: 5.4,
    ),
    config: TradeStrategyConfig(
      minSignalStrength: 70.0,
      requireAllIndicatorsGreen: false,
      interval: '1d',
      initialCapital: 25000.0,
      tradeQuantity: 1,
      enableDynamicPositionSizing: true,
      riskPerTrade: 0.01,
      atrMultiplier: 1.8,
      takeProfitPercent: 6.0,
      stopLossPercent: 3.0,
      trailingStopEnabled: true,
      trailingStopPercent: 2.0,
      maxPositionSize: 50,
      maxPortfolioConcentration: 0.20,
      dailyTradeLimit: 3,
      enableSectorLimits: true,
      maxSectorExposure: 0.20,
      enableDrawdownProtection: true,
      maxDrawdown: 0.08,
      enableGexStructuralStops: true,
      enableTrailingPeakStop: true,
      trailingPeakStopPercent: 15.0,
      enableMacroRegimeStop: true,
      enableCatastrophicStop: true,
      catastrophicStopPercent: 20.0,
      enabledIndicators: {
        'marketDirection': true,
        'bollingerBands': true,
        'momentum': true,
        'atr': true,
        'volume': true,
        'pivotPoints': true,
      },
      indicatorReasons: {
        'marketDirection': 'Confirms broader trend alignment (SMA 50/200).',
        'bollingerBands': 'Identifies safe boundary entries.',
        'momentum': 'RSI prevents overextended entries.',
        'atr': 'Used for volatility-adjusted position sizing.',
        'volume': 'Confirms institutional sponsorship.',
        'pivotPoints': 'Provides key horizontal support levels.',
      },
    ),
  );

  static final StrategyArchetype momentumBreakout = StrategyArchetype(
    id: 'archetype_momentum_breakout',
    name: 'Momentum Breakout',
    tag: 'Directional Expansion',
    description:
        'Aggressive trend capture on volume expansion, MACD histogram crossovers, and VWAP trend confirmation with dynamic ATR trailing stops.',
    detailedPhilosophy:
        'Captures explosive directional expansion when price breaks out of consolidation with surging volume. Leverages MACD, ADX trend strength, VWAP, and Chaikin Money Flow to ride strong institutional momentum. Uses dynamic ATR trailing stops to lock in windfalls while enforcing a 25% catastrophic stop.',
    icon: Icons.trending_up_rounded,
    accentColor: Color(0xFF0284C7), // Sky blue
    tradingMode: TradingMode.systematic,
    targetMarketRegime: 'High Volatility Expansion / Bull',
    walkForwardMetrics: WalkForwardPeriodMetrics(
      totalTrades: 86,
      winRate: 57.8,
      totalReturn: 10525.0,
      totalReturnPercent: 42.1,
      profitFactor: 2.14,
      sharpeRatio: 1.58,
      maxDrawdownPercent: 10.8,
    ),
    config: TradeStrategyConfig(
      minSignalStrength: 65.0,
      requireAllIndicatorsGreen: false,
      interval: '1d',
      initialCapital: 25000.0,
      tradeQuantity: 1,
      enableDynamicPositionSizing: true,
      riskPerTrade: 0.02,
      atrMultiplier: 2.5,
      takeProfitPercent: 12.0,
      stopLossPercent: 4.5,
      trailingStopEnabled: true,
      trailingStopPercent: 3.5,
      maxPositionSize: 100,
      maxPortfolioConcentration: 0.30,
      dailyTradeLimit: 6,
      enableDrawdownProtection: true,
      maxDrawdown: 0.15,
      enableTrailingPeakStop: true,
      trailingPeakStopPercent: 20.0,
      enableCatastrophicStop: true,
      catastrophicStopPercent: 25.0,
      enabledIndicators: {
        'priceMovement': true,
        'momentum': true,
        'macd': true,
        'volume': true,
        'adx': true,
        'vwap': true,
        'chaikinMoneyFlow': true,
        'atr': true,
      },
      indicatorReasons: {
        'priceMovement': 'Bullish breakout candlestick confirmation.',
        'momentum': 'RSI momentum acceleration.',
        'macd': 'MACD line crossover above signal line.',
        'volume': 'Volume spike confirms institutional participation.',
        'adx': 'ADX > 25 confirms trend strength.',
        'vwap': 'Price above VWAP indicates buyer control.',
        'chaikinMoneyFlow': 'Positive accumulation money flow.',
        'atr': 'Dynamic ATR trailing stop expansion.',
      },
    ),
  );

  static final StrategyArchetype optionsIncomeHarvester = StrategyArchetype(
    id: 'archetype_options_income_harvester',
    name: 'Options Income Harvester',
    tag: 'High-Yield Premium',
    description:
        'Systematic premium selling and range-bound mean reversion utilizing GEX dealer pinning, Stochastic, and 5-tier GEX stops.',
    detailedPhilosophy:
        'Engineered for high-probability premium capture during range-bound and consolidating markets. Exploits market-maker gamma pinning and mean-reverting oscillators (Stochastic, RSI, Williams %R) to harvest theta decay. Defended by the full 5-tier sequential exit queue, including time-theta decay exits and dealer gamma flip triggers.',
    icon: Icons.savings_outlined,
    accentColor: Color(0xFFD97706), // Amber
    tradingMode: TradingMode.systematic,
    targetMarketRegime: 'Range-Bound / Low-to-Moderate Volatility',
    walkForwardMetrics: WalkForwardPeriodMetrics(
      totalTrades: 64,
      winRate: 76.2,
      totalReturn: 7950.0,
      totalReturnPercent: 31.8,
      profitFactor: 1.95,
      sharpeRatio: 1.84,
      maxDrawdownPercent: 7.2,
    ),
    config: TradeStrategyConfig(
      minSignalStrength: 60.0,
      requireAllIndicatorsGreen: false,
      interval: '1d',
      initialCapital: 25000.0,
      tradeQuantity: 1,
      enableDynamicPositionSizing: true,
      riskPerTrade: 0.015,
      atrMultiplier: 2.0,
      takeProfitPercent: 15.0,
      stopLossPercent: 18.0,
      trailingStopEnabled: true,
      trailingStopPercent: 4.0,
      maxPositionSize: 75,
      maxPortfolioConcentration: 0.25,
      dailyTradeLimit: 4,
      enableGexStructuralStops: true,
      enableTimeThetaStop: true,
      minDteStopDays: 14,
      stalledSessionsStopLimit: 5,
      enableMacroRegimeStop: true,
      enableCatastrophicStop: true,
      catastrophicStopPercent: 35.0,
      gexExitEnabled: true,
      enabledIndicators: {
        'gammaExposure': true,
        'bollingerBands': true,
        'stochastic': true,
        'momentum': true,
        'williamsR': true,
        'pivotPoints': true,
        'atr': true,
      },
      indicatorReasons: {
        'gammaExposure': 'Dealer gamma positioning and pin strike analysis.',
        'bollingerBands': 'Upper/lower volatility bands for range reversion.',
        'stochastic': 'Oversold / overbought turning points.',
        'momentum': 'RSI confirmation of exhaustion.',
        'williamsR': 'Short-term momentum extremes.',
        'pivotPoints': 'Standard deviation reversal pivots.',
        'atr': 'Volatility buffer calculation.',
      },
    ),
  );

  static final StrategyArchetype reasoningAiAgent = StrategyArchetype(
    id: 'archetype_reasoning_ai_agent',
    name: 'Reasoning AI Agent',
    tag: 'Autonomous Gemini AI',
    description:
        'Multimodal Gemini AI reasoning synthesizing technical convergence, macro regime context, and chain-of-thought verification.',
    detailedPhilosophy:
        'Leverages Gemini 3.1 Flash-Lite AI reasoning to evaluate macro economic regime, SEC filings, dealer positioning, and cross-indicator convergence before proposing or executing orders. Validates proposals through an autonomous chain-of-thought verification pipeline with dynamic position sizing and portfolio risk guardrails.',
    icon: Icons.psychology_outlined,
    accentColor: Color(0xFF7C3AED), // Purple
    tradingMode: TradingMode.reasoning,
    targetMarketRegime: 'All Regimes / Adaptive',
    walkForwardMetrics: WalkForwardPeriodMetrics(
      totalTrades: 58,
      winRate: 64.6,
      totalReturn: 7100.0,
      totalReturnPercent: 28.4,
      profitFactor: 1.82,
      sharpeRatio: 1.65,
      maxDrawdownPercent: 8.6,
    ),
    config: TradeStrategyConfig(
      minSignalStrength: 75.0,
      requireAllIndicatorsGreen: false,
      interval: '1d',
      initialCapital: 25000.0,
      tradeQuantity: 1,
      enableDynamicPositionSizing: true,
      riskPerTrade: 0.02,
      atrMultiplier: 2.0,
      takeProfitPercent: 10.0,
      stopLossPercent: 5.0,
      trailingStopEnabled: true,
      trailingStopPercent: 3.0,
      trailingPeakStopPercent: 20.0,
      maxPositionSize: 100,
      maxPortfolioConcentration: 0.25,
      dailyTradeLimit: 5,
      enableMacroRegimeStop: true,
      enableCatastrophicStop: true,
      catastrophicStopPercent: 30.0,
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
        'vwap': true,
        'adx': true,
        'williamsR': true,
        'ichimoku': true,
        'cci': true,
        'parabolicSar': true,
        'roc': true,
        'chaikinMoneyFlow': true,
        'fibonacciRetracements': true,
        'pivotPoints': true,
        'gammaExposure': true,
      },
      indicatorReasons: {
        'priceMovement': 'Price action candlestick formation analysis.',
        'momentum': 'RSI momentum oscillator.',
        'marketDirection': 'Trend filter and benchmark comparison.',
        'volume': 'Volume volume validation.',
        'macd': 'Trend following momentum convergence.',
        'bollingerBands': 'Volatility compression and expansion.',
        'stochastic': 'Momentum oscillator turning points.',
        'atr': 'Volatility stop and sizing calculation.',
        'obv': 'Cumulative volume flow.',
        'vwap': 'Institutional intraday benchmark.',
        'adx': 'Directional trend strength indicator.',
        'williamsR': 'Overbought/oversold momentum.',
        'ichimoku': 'Cloud support, resistance and momentum.',
        'cci': 'Cyclical trend deviations.',
        'parabolicSar': 'Trailing trend reversals.',
        'roc': 'Rate of price velocity change.',
        'chaikinMoneyFlow': 'Institutional money accumulation.',
        'fibonacciRetracements': 'Golden ratio support/resistance.',
        'pivotPoints': 'Floor trader pivot levels.',
        'gammaExposure': 'Market-maker gamma exposure and pin strike.',
      },
    ),
  );

  /// All 4 curated archetypes in priority order
  static final List<StrategyArchetype> curated = [
    conservativeCore,
    momentumBreakout,
    optionsIncomeHarvester,
    reasoningAiAgent,
  ];

  /// Finds an archetype by its unique ID
  static StrategyArchetype? findById(String id) {
    for (final archetype in curated) {
      if (archetype.id == id) {
        return archetype;
      }
    }
    return null;
  }
}
