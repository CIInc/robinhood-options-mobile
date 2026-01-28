import 'package:robinhood_options_mobile/model/backtesting_models.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_config.dart';
import 'package:robinhood_options_mobile/model/custom_indicator_config.dart';

/// Saved backtest configuration template
class TradeStrategyTemplate {
  final String id;
  final String name;
  final String description;
  final TradeStrategyConfig config;
  final DateTime createdAt;
  final DateTime? lastUsedAt;

  TradeStrategyTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.config,
    required this.createdAt,
    this.lastUsedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'config': config.toJson(),
        'createdAt': createdAt.toIso8601String(),
        'lastUsedAt': lastUsedAt?.toIso8601String(),
      };

  factory TradeStrategyTemplate.fromJson(Map<String, dynamic> json) =>
      TradeStrategyTemplate(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String,
        config: TradeStrategyConfig.fromJson(
          Map<String, dynamic>.from(json['config'] as Map),
        ),
        createdAt: DateTime.parse(json['createdAt'] as String),
        lastUsedAt: json['lastUsedAt'] != null
            ? DateTime.parse(json['lastUsedAt'] as String)
            : null,
      );
}

/// Pre-built strategy templates for backtesting
class TradeStrategyDefaults {
  static final List<TradeStrategyTemplate> defaultTemplates = [
    TradeStrategyTemplate(
      id: 'default_simple_price_movement',
      name: 'Simple Price Movement',
      description:
          'Basic price action strategy. Buys on bullish candlestick patterns (Engulfing, Hammer, Morning Star) with volume confirmation.',
      config: TradeStrategyConfig(
        minSignalStrength: 50.0,
        requireAllIndicatorsGreen: false,
        startDate: DateTime.now().subtract(const Duration(days: 365)),
        endDate: DateTime.now(),
        interval: '1d',
        initialCapital: 10000.0,
        enabledIndicators: {
          'priceMovement': true,
          'momentum': false,
          'marketDirection': false,
          'volume': true,
          'macd': false,
          'bollingerBands': false,
          'stochastic': false,
          'atr': false, // Only for sizing
          'obv': false,
          'vwap': false,
          'adx': false,
          'williamsR': false,
          'ichimoku': false,
          'cci': false,
          'parabolicSar': false,
        },
        indicatorReasons: {
          'priceMovement':
              'Detects bullish patterns like Engulfing, Hammer, or Morning Star',
          'volume': 'Volume spike confirms institutional participation',
          'atr': 'Calculates volatility-based stops and position sizing',
        },
        riskPerTrade: 0.02,
        enableDynamicPositionSizing: true,
        takeProfitPercent: 5.0,
        stopLossPercent: 2.0,
        trailingStopEnabled: true,
        trailingStopPercent: 1.5,
        maxSectorExposure: 0.20,
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_simple_rsi',
      name: 'Simple RSI',
      description:
          'Classic mean reversion strategy. Buy when RSI is below 30 (Oversold).',
      config: TradeStrategyConfig(
        minSignalStrength: 50.0,
        requireAllIndicatorsGreen: true,
        startDate: DateTime.now().subtract(const Duration(days: 365)),
        endDate: DateTime.now(),
        interval: '1d',
        initialCapital: 10000.0,
        enabledIndicators: {
          'momentum': true, // RSI
        },
        indicatorReasons: {
          'momentum':
              'Identifies oversold conditions (RSI < 30) for mean reversion.',
        },
        customIndicators: [
          CustomIndicatorConfig(
            id: 'simple_rsi_buy',
            name: 'RSI < 30',
            type: IndicatorType.RSI,
            parameters: {'period': 14},
            condition: SignalCondition.LessThan,
            threshold: 30.0,
            compareToPrice: false,
          ),
        ],
        takeProfitPercent: 5.0,
        stopLossPercent: 2.0,
        riskPerTrade: 0.02,
        enableDynamicPositionSizing: true,
        trailingStopEnabled: true,
        trailingStopPercent: 1.5,
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_simple_macd',
      name: 'Simple MACD',
      description:
          'Trend following strategy. Buy when MACD line crosses above the Signal line.',
      config: TradeStrategyConfig(
        minSignalStrength: 50.0,
        requireAllIndicatorsGreen: true,
        startDate: DateTime.now().subtract(const Duration(days: 365)),
        endDate: DateTime.now(),
        interval: '1d',
        initialCapital: 10000.0,
        enabledIndicators: {
          'macd': true,
          'adx': false, // Using custom indicator for specific threshold
        },
        indicatorReasons: {
          'macd': 'Detects bullish trend reversals via crossover events.',
          'adx': 'Ensures sufficient trend strength (ADX > 20).',
        },
        customIndicators: [
          CustomIndicatorConfig(
            id: 'simple_macd_adx',
            name: 'ADX > 20',
            type: IndicatorType.ADX,
            parameters: {'period': 14},
            condition: SignalCondition.GreaterThan,
            threshold: 20.0,
            compareToPrice: false,
          ),
        ],
        takeProfitPercent: 8.0,
        stopLossPercent: 4.0,
        riskPerTrade: 0.02,
        enableDynamicPositionSizing: true,
        trailingStopEnabled: true,
        trailingStopPercent: 2.0,
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_simple_bollinger',
      name: 'Simple Bollinger',
      description:
          'Mean reversion strategy. Buy when price closes near the Lower Bollinger Band.',
      config: TradeStrategyConfig(
        minSignalStrength: 50.0,
        requireAllIndicatorsGreen: true,
        startDate: DateTime.now().subtract(const Duration(days: 365)),
        endDate: DateTime.now(),
        interval: '1d',
        initialCapital: 10000.0,
        indicatorReasons: {
          'bollingerBands':
              'Signals buy opportunities near the lower band (oversold).',
        },
        enabledIndicators: {
          'bollingerBands': true,
        },
        takeProfitPercent: 5.0,
        stopLossPercent: 2.0,
        riskPerTrade: 0.02,
        enableDynamicPositionSizing: true,
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_momentum_master',
      name: 'Momentum Master',
      description:
          'Captures strong price moves by combining RSI and CCI momentum with ADX trend confirmation. Best for strong trends.',
      config: TradeStrategyConfig(
        minSignalStrength: 65.0,
        requireAllIndicatorsGreen: false,
        startDate: DateTime.now().subtract(const Duration(days: 365)),
        endDate: DateTime.now(),
        interval: '1d',
        initialCapital: 25000.0,
        enabledIndicators: {
          'priceMovement': true,
          'momentum': true, // RSI
          'marketDirection': false,
          'volume': true,
          'macd': true,
          'bollingerBands': false,
          'stochastic': false,
          'atr': false,
          'obv': true, // OBV
          'vwap': false,
          'adx': false, // Using custom indicator
          'williamsR': false,
          'ichimoku': false,
          'cci': true, // CCI
          'parabolicSar': false,
        },
        indicatorReasons: {
          'priceMovement': 'Confirms price is moving in the desired direction.',
          'momentum': 'RSI indicates strong momentum without being overbought.',
          'volume': 'High volume validates the strength of the move.',
          'obv': 'OBV confirms volume flow matches price action.',
          'macd': 'MACD histogram expansion confirms accelerating momentum.',
          'adx': 'ADX > 20 indicates a strong trending environment.',
          'cci': 'CCI helps detect the start of a new trend or cyclical turn.',
        },
        customIndicators: [
          CustomIndicatorConfig(
            id: 'adx_trend_confirm',
            name: 'ADX > 20',
            type: IndicatorType.ADX,
            parameters: {'period': 14},
            condition: SignalCondition.GreaterThan,
            threshold: 20.0,
            compareToPrice: false,
          ),
          CustomIndicatorConfig(
            id: 'cci_momentum_burst',
            name: 'CCI > 100',
            type: IndicatorType.CCI,
            parameters: {'period': 20},
            condition: SignalCondition.GreaterThan,
            threshold: 100.0,
            compareToPrice: false,
          ),
        ],
        takeProfitPercent: 15.0,
        stopLossPercent: 5.0,
        trailingStopEnabled: true,
        trailingStopPercent: 3.0,
        riskPerTrade: 0.02,
        enableDynamicPositionSizing: true,
        enableSectorLimits: true,
        maxSectorExposure: 0.25,
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_mean_reversion',
      name: 'Mean Reversion',
      description:
          'Identifies overbought/oversold reversals using Bollinger Bands and RSI extremes. Targets "snap-back" moves.',
      config: TradeStrategyConfig(
        minSignalStrength: 50.0,
        requireAllIndicatorsGreen: false,
        startDate: DateTime.now().subtract(const Duration(days: 365)),
        endDate: DateTime.now(),
        interval: '1d',
        initialCapital: 25000.0,
        enabledIndicators: {
          'priceMovement': false,
          'momentum': true, // RSIs
          'marketDirection': false,
          'volume': false,
          'macd': false,
          'bollingerBands': true,
          'stochastic': true,
          'atr': false,
          'obv': false,
          'vwap': false,
          'adx': false,
          'williamsR': true,
          'ichimoku': false,
          'cci': true,
          'parabolicSar': false,
        },
        indicatorReasons: {
          'momentum': 'RSI < 30 indicates oversold conditions.',
          'bollingerBands':
              'Price near lower band signals potential mean reversion.',
          'stochastic': 'Stochastic oscillator confirms oversold momentum.',
          'williamsR': 'Williams %R confirms extreme price levels.',
          'cci': 'CCI deviation hints at impending reversal.',
        },
        customIndicators: [
          CustomIndicatorConfig(
            id: 'rsi_oversold_check',
            name: 'RSI < 30 (Oversold)',
            type: IndicatorType.RSI,
            parameters: {'period': 14},
            condition: SignalCondition.LessThan,
            threshold: 30.0,
            compareToPrice: false,
          ),
        ],
        takeProfitPercent: 8.0,
        stopLossPercent: 4.0,
        trailingStopEnabled: false,
        timeBasedExitEnabled: true,
        timeBasedExitMinutes: 4320, // 3 days
        riskPerTrade: 0.015,
        enableDynamicPositionSizing: true,
        rsiExitEnabled: true,
        rsiExitThreshold: 70.0,
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_trend_follower',
      name: 'Trend Follower',
      description:
          'Rides established trends using Moving Averages, Ichimoku Cloud, and ADX trend strength (> 25).',
      config: TradeStrategyConfig(
        minSignalStrength: 60.0,
        requireAllIndicatorsGreen: false,
        startDate: DateTime.now().subtract(const Duration(days: 365)),
        endDate: DateTime.now(),
        interval: '1d',
        initialCapital: 25000.0,
        enabledIndicators: {
          'priceMovement': true,
          'momentum': false,
          'marketDirection': true,
          'volume': true, // Added volume
          'macd': true,
          'bollingerBands': false,
          'stochastic': false,
          'atr': false,
          'obv': true,
          'vwap': false,
          'adx': false, // Using custom indicator
          'williamsR': false,
          'ichimoku': true,
          'cci': false,
          'parabolicSar': true,
        },
        indicatorReasons: {
          'priceMovement': 'Price action confirms the established trend.',
          'marketDirection': 'Moving averages provide support in uptrends.',
          'volume': 'Volume confirms the validity of the trend.',
          'macd': 'MACD confirms trend strength and direction.',
          'atr': 'ATR measures volatility for stop-loss placement.',
          'obv': 'OBV confirms volume backing the trend.',
          'adx': 'ADX > 25 indicates a strong trend is present.',
          'ichimoku': 'Ichimoku Cloud establishes the trend baseline.',
          'parabolicSar': 'Parabolic SAR trails price to protect gains.',
        },
        customIndicators: [
          CustomIndicatorConfig(
            id: 'adx_strong_trend',
            name: 'ADX > 25',
            type: IndicatorType.ADX,
            parameters: {'period': 14},
            condition: SignalCondition.GreaterThan,
            threshold: 25.0,
            compareToPrice: false,
          ),
        ],
        takeProfitPercent: 20.0,
        stopLossPercent: 8.0,
        trailingStopEnabled: true,
        riskPerTrade: 0.015,
        enableDynamicPositionSizing: true,
        trailingStopPercent: 5.0,
        rsiExitEnabled: true,
        rsiExitThreshold: 75.0,
        signalStrengthExitEnabled: true,
        signalStrengthExitThreshold: 40.0,
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_volatility_breakout',
      name: 'Volatility Breakout (1h)',
      description:
          'Exploits explosive moves from squeeze conditions using Bollinger Bands, CCI (> 100), and VWAP. High-risk, high-reward intraday strategy.',
      config: TradeStrategyConfig(
        minSignalStrength: 70.0,
        requireAllIndicatorsGreen: false,
        startDate: DateTime.now().subtract(const Duration(days: 90)),
        endDate: DateTime.now(),
        interval: '1h',
        initialCapital: 25000.0,
        enabledIndicators: {
          'priceMovement': true,
          'momentum': false,
          'marketDirection': false,
          'volume': true,
          'macd': false,
          'bollingerBands': true, // Squeeze
          'stochastic': false,
          'atr': true,
          'obv': false,
          'vwap': true, // Price > VWAP
          'adx': false, // Using custom indicator
          'williamsR': false,
          'ichimoku': false,
          'cci': true, // CCI > 100
          'parabolicSar': false,
        },
        indicatorReasons: {
          'priceMovement': 'Price breakout from consolidation.',
          'volume': 'Volume spike validates the breakout.',
          'bollingerBands': 'Band squeeze often precedes explosive moves.',
          'atr': 'Increased ATR signals volatility expansion.',
          'vwap': 'Price holding above VWAP confirms intraday bullishness.',
          'adx': 'Rising ADX confirms the new trend strength.',
          'cci': 'CCI > 100 identifies the momentum surge.',
        },
        customIndicators: [
          CustomIndicatorConfig(
            id: 'cci_breakout_strong',
            name: 'CCI > 100',
            type: IndicatorType.CCI,
            parameters: {'period': 20},
            condition: SignalCondition.GreaterThan,
            threshold: 100.0,
            compareToPrice: false,
          ),
          CustomIndicatorConfig(
            id: 'adx_trend_start',
            name: 'ADX > 25',
            type: IndicatorType.ADX,
            parameters: {'period': 14},
            condition: SignalCondition.GreaterThan,
            threshold: 25.0,
            compareToPrice: false,
          ),
        ],
        takeProfitPercent: 15.0,
        stopLossPercent: 3.0,
        trailingStopEnabled: true,
        riskPerTrade: 0.025,
        enableDynamicPositionSizing: true,
        trailingStopPercent: 2.0,
        enableVolatilityFilters: true,
        minVolatility: 0.5,
        maxVolatility: 3.0,
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_scalper_15m',
      name: 'Intraday Scalper (15m)',
      description:
          'Short-term scalping via CCI/Stochastic with strict risk management. Only trades when trend strength (ADX > 20) is sufficient.',
      config: TradeStrategyConfig(
        minSignalStrength: 60.0,
        requireAllIndicatorsGreen: false,
        startDate: DateTime.now().subtract(const Duration(days: 30)),
        endDate: DateTime.now(),
        interval: '15m',
        enabledIndicators: {
          'priceMovement': true,
          'momentum': true,
          'marketDirection': false,
          'volume': true,
          'macd': false,
          'bollingerBands': false,
          'stochastic': true,
          'atr': false,
          'obv': false,
          'vwap': true,
          'adx': false, // Using custom indicator
          'williamsR': true,
          'ichimoku': false,
          'cci': true,
          'parabolicSar': true,
        },
        indicatorReasons: {
          'priceMovement': 'Short-term price action direction.',
          'momentum': 'Momentum confirms short-term moves.',
          'volume': 'Volume ensures sufficient liquidity for scalping.',
          'stochastic': 'Stochastic oscillator signals rapid reversals.',
          'atr': 'ATR defines tight stop-loss and profit targets.',
          'vwap': 'VWAP acts as dynamic support/resistance.',
          'adx': 'ADX > 20 filters out choppy markets.',
          'williamsR': 'Williams %R identifies extensive levels quickly.',
          'cci': 'CCI spots short-term cyclical turns.',
          'parabolicSar': 'Parabolic SAR manages trailing stops.',
        },
        customIndicators: [
          CustomIndicatorConfig(
            id: 'adx_scalp_filter',
            name: 'ADX > 20',
            type: IndicatorType.ADX,
            parameters: {'period': 14},
            condition: SignalCondition.GreaterThan,
            threshold: 20.0,
            compareToPrice: false,
          ),
        ],
        initialCapital: 25000,
        takeProfitPercent: 3.0,
        stopLossPercent: 1.5,
        timeBasedExitEnabled: true,
        timeBasedExitMinutes: 60,
        marketCloseExitEnabled: true,
        marketCloseExitMinutes: 10,
        enablePartialExits: true,
        exitStages: [
          ExitStage(profitTargetPercent: 1.5, quantityPercent: 0.5),
        ],
        riskPerTrade: 0.01,
        enableDynamicPositionSizing: true,
        trailingStopEnabled: true,
        trailingStopPercent: 0.5,
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_custom_ema_trend',
      name: 'EMA Trend & Momentum',
      description:
          'Advanced strategy combining trend following (Price > EMA 21) with momentum confirmation (RSI > 50) and Parabolic SAR stops.',
      config: TradeStrategyConfig(
        minSignalStrength: 50.0,
        requireAllIndicatorsGreen: false,
        startDate: DateTime.now().subtract(const Duration(days: 180)),
        endDate: DateTime.now(),
        interval: '1h',
        initialCapital: 25000.0,
        enabledIndicators: {
          'priceMovement': true,
          'momentum': false,
          'marketDirection': false,
          'volume': true, // Added volume
          'macd': false,
          'bollingerBands': false,
          'stochastic': false,
          'atr': false, // Only for sizing
          'obv': false,
          'vwap': false,
          'adx': false,
          'williamsR': false,
          'ichimoku': false,
          'cci': false,
          'parabolicSar': true, // Trailing stop source
        },
        indicatorReasons: {
          'priceMovement': 'Confirms trend alignment.',
          'volume': 'Volume validates the trend strength.',
          'atr': 'ATR assists in sizing and stop placement.',
          'parabolicSar': 'Parabolic SAR acts as the trailing stop mechanism.',
        },
        customIndicators: [
          CustomIndicatorConfig(
            id: 'custom_ema_21',
            name: 'Price > EMA 21',
            type: IndicatorType.EMA,
            parameters: {'period': 21},
            condition: SignalCondition.GreaterThan, // Price > EMA
            compareToPrice: true,
          ),
          CustomIndicatorConfig(
            id: 'custom_rsi_trend',
            name: 'RSI > 50 (Bullish Context)',
            type: IndicatorType.RSI,
            parameters: {'period': 14},
            condition: SignalCondition.GreaterThan,
            threshold: 50.0,
            compareToPrice: false,
          ),
        ],
        takeProfitPercent: 12.0,
        stopLossPercent: 4.0,
        riskPerTrade: 0.015,
        enableDynamicPositionSizing: true,
        trailingStopEnabled: true,
        trailingStopPercent: 3.0,
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_crypto_proxy_momentum',
      name: 'Crypto Proxy Momentum',
      description:
          'High-volatility momentum strategy (CCI > 100, RSI > 55) designed for crypto-correlated stocks (COIN, MSTR, MARA).',
      config: TradeStrategyConfig(
        minSignalStrength: 65.0,
        requireAllIndicatorsGreen: false,
        symbolFilter: ['COIN', 'MSTR', 'MARA', 'CLSK', 'RIOT', 'IBIT'],
        startDate: DateTime.now().subtract(const Duration(days: 90)),
        endDate: DateTime.now(),
        interval: '1h',
        initialCapital: 10000.0,
        enabledIndicators: {
          'priceMovement': true,
          'momentum': true,
          'marketDirection': false,
          'volume': true,
          'macd': true,
          'bollingerBands': true,
          'stochastic': false,
          'atr': false, // Managed by sizing
          'obv': true,
          'vwap': false,
          'adx': false, // Strong Trend
          'williamsR': false,
          'ichimoku': false,
          'cci': true, // Volatility sensitive
          'parabolicSar': true, // Trailing stop
        },
        indicatorReasons: {
          'priceMovement': 'Confirms explosive moves characteristic of crypto.',
          'momentum': 'RSI > 55 ensures existing momentum.',
          'volume': 'High volume required for crypto proxy moves.',
          'macd': 'MACD confirms the breakout momentum.',
          'bollingerBands': 'Captures volatility expansion.',
          'atr': 'Manages high volatility risk.',
          'obv': 'Volume flow precedes price moves.',
          'adx': 'ADX confirms trend strength.',
          'cci': 'CCI > 100 filters for high-velocity moves.',
          'parabolicSar': 'Tight trailing stop for volatile assets.',
        },
        customIndicators: [
          CustomIndicatorConfig(
            id: 'cci_high_momentum',
            name: 'CCI > 100',
            type: IndicatorType.CCI,
            parameters: {'period': 20},
            condition: SignalCondition.GreaterThan,
            threshold: 100.0,
            compareToPrice: false,
          ),
          CustomIndicatorConfig(
            id: 'rsi_bullish',
            name: 'RSI > 55',
            type: IndicatorType.RSI,
            parameters: {'period': 14},
            condition: SignalCondition.GreaterThan,
            threshold: 55.0,
            compareToPrice: false,
          ),
          CustomIndicatorConfig(
            id: 'adx_strong_trend',
            name: 'ADX > 25',
            type: IndicatorType.ADX,
            parameters: {'period': 14},
            condition: SignalCondition.GreaterThan,
            threshold: 25.0,
            compareToPrice: false,
          ),
        ],
        takeProfitPercent: 20.0, // Higher target for crypto volatility
        riskPerTrade: 0.02,
        enableDynamicPositionSizing: true,
        stopLossPercent: 8.0, // Wider stop for volatility
        trailingStopEnabled: true,
        trailingStopPercent: 5.0,
        enableVolatilityFilters: true,
        minVolatility: 0.5,
        enableCorrelationChecks: true,
        maxCorrelation: 0.85,
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_golden_cross_rsi',
      name: 'Golden Cross & RSI Filter',
      description:
          'Classic Long-Term Trend: Buys when SMA 50 is above SMA 200 (Golden Cross zone), filtered by RSI < 70 to avoid buying tops.',
      config: TradeStrategyConfig(
        minSignalStrength: 50.0,
        requireAllIndicatorsGreen: false,
        startDate: DateTime.now().subtract(const Duration(days: 730)),
        endDate: DateTime.now(),
        interval: '1d',
        initialCapital: 50000.0,
        enabledIndicators: {
          'priceMovement': false,
          'momentum': false,
          'marketDirection': true, // SMA
          'volume': true,
          'macd': false,
          'bollingerBands': false,
          'stochastic': false,
          'atr': false,
          'obv': false,
          'vwap': false,
          'adx': false,
          'williamsR': false,
          'ichimoku': false,
          'cci': false,
          'parabolicSar': false,
        },
        indicatorReasons: {
          'marketDirection':
              'SMA 50 > SMA 200 confirms the long-term bullish trend.',
          'volume': 'Volume confirms the validity of the trend.',
        },
        smaPeriodFast: 50,
        smaPeriodSlow: 200,
        customIndicators: [
          CustomIndicatorConfig(
            id: 'custom_rsi_filter',
            name: 'RSI < 70',
            type: IndicatorType.RSI,
            parameters: {'period': 14},
            condition: SignalCondition.LessThan,
            threshold: 70.0,
            compareToPrice: false,
          ),
        ],
        riskPerTrade: 0.02,
        enableDynamicPositionSizing: true,
        takeProfitPercent: 25.0,
        stopLossPercent: 10.0,
        trailingStopEnabled: true,
        trailingStopPercent: 5.0,
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_iron_condor_income',
      name: 'Range Bound (RSI 40-60)',
      description:
          'Ideal for choppy, sideways markets. Targets entries when RSI is in the neutral zone (40-60) indicating lack of strong trend.',
      config: TradeStrategyConfig(
        minSignalStrength: 50.0,
        requireAllIndicatorsGreen: false,
        startDate: DateTime.now().subtract(const Duration(days: 365)),
        endDate: DateTime.now(),
        interval: '1d',
        initialCapital: 25000.0,
        enabledIndicators: {
          'priceMovement': false,
          'momentum': false,
          'marketDirection': false,
          'volume': false,
          'macd': false,
          'bollingerBands': true, // Use bands to define range edges
          'stochastic': true, // Overbought/Oversold oscillations
          'atr': true, // Low volatility preference
          'obv': false,
          'vwap': false,
          'adx': false,
          'williamsR': true,
          'ichimoku': false,
          'cci': true, // Range confirmation
          'parabolicSar': false,
        },
        indicatorReasons: {
          'bollingerBands': 'Bands provide support/resistance limits.',
          'stochastic': 'Stochastic oscillations identify range extremities.',
          'atr': 'Monitor volatility for range stability.',
          'williamsR': 'Oscillator confirms overextended moves within range.',
          'cci': 'CCI helps identify cyclical turns within the range.',
        },
        customIndicators: [
          CustomIndicatorConfig(
            id: 'custom_rsi_ceiling',
            name: 'RSI < 60',
            type: IndicatorType.RSI,
            parameters: {'period': 14},
            condition: SignalCondition.LessThan,
            threshold: 60.0,
            compareToPrice: false,
          ),
          CustomIndicatorConfig(
            id: 'custom_rsi_floor',
            name: 'RSI > 40',
            type: IndicatorType.RSI,
            parameters: {'period': 14},
            condition: SignalCondition.GreaterThan,
            threshold: 40.0,
            compareToPrice: false,
          ),
        ],
        riskPerTrade: 0.01,
        enableDynamicPositionSizing: true,
        takeProfitPercent: 4.0,
        stopLossPercent: 2.0,
        trailingStopEnabled: false,
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_strict_confluence',
      name: 'Strict Confluence',
      description:
          'High conviction entries requiring ALL enabled indicators (Momentum, Moving Avg, MACD) to agree.',
      config: TradeStrategyConfig(
        requireAllIndicatorsGreen: true,
        minSignalStrength: 100.0,
        startDate: DateTime.now().subtract(const Duration(days: 180)),
        endDate: DateTime.now(),
        interval: '1d',
        initialCapital: 25000.0,
        enabledIndicators: {
          'priceMovement': true,
          'momentum': true, // RSI
          'marketDirection': true, // SMA
          'volume': false,
          'macd': true,
          'bollingerBands': false,
          'stochastic': false,
          'atr': false,
          'obv': false,
          'vwap': false,
          'adx': true,
          'williamsR': false,
          'ichimoku': false,
          'cci': false,
          'parabolicSar': false,
        },
        indicatorReasons: {
          'priceMovement': 'Price action must agree with all other signals.',
          'momentum': 'RSI indicates momentum without overbought readings.',
          'marketDirection': 'Moving averages confirm the primary trend.',
          'macd': 'MACD histogram confirms momentum direction.',
          'adx': 'ADX confirms trend existence.',
        },
        riskPerTrade: 0.02,
        enableDynamicPositionSizing: true,
        takeProfitPercent: 12.0,
        stopLossPercent: 4.0,
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_risk_managed_growth',
      name: 'Risk-Managed Growth',
      description:
          'Uses dynamic position sizing to risk exactly 1% of account equity per trade, managed by Parabolic SAR.',
      config: TradeStrategyConfig(
        minSignalStrength: 50.0,
        requireAllIndicatorsGreen: false,
        startDate: DateTime.now().subtract(const Duration(days: 365)),
        endDate: DateTime.now(),
        interval: '1h',
        initialCapital: 50000,
        enabledIndicators: {
          'priceMovement': true,
          'momentum': true,
          'marketDirection': true,
          'volume': true,
          'macd': false,
          'bollingerBands': true,
          'stochastic': true,
          'atr': false, // Critical for ATR-based stops (Sizing only)
          'obv': false,
          'vwap': true,
          'adx': false,
          'williamsR': false,
          'ichimoku': false,
          'cci': false,
          'parabolicSar': true, // Trailing stop support
        },
        indicatorReasons: {
          'priceMovement': 'Ensures price alignment with trade direction.',
          'momentum': 'RSI indicates healthy momentum.',
          'marketDirection': 'SMA identifies the broader market trend.',
          'volume': 'Volume confirms the liquidity and strength.',
          'bollingerBands': 'Bands provide volatility context.',
          'stochastic': 'Stochastic oscillator aids entry timing.',
          'atr': 'Critical for calculating position size and stops.',
          'vwap': 'VWAP acts as an execution benchmark.',
          'parabolicSar': 'Primary tool for trailing stop management.',
        },
        enableDynamicPositionSizing: true,
        riskPerTrade: 0.01, // 1% risk
        atrMultiplier: 2.0, // Stop loss at 2x ATR
        takeProfitPercent: 6.0,
        stopLossPercent: 3.0, // Fallback
        trailingStopEnabled: true,
        trailingStopPercent: 2.0,
        enableDrawdownProtection: true,
        maxDrawdown: 0.05,
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_macd_reversal',
      name: 'MACD Histogram Reversal',
      description:
          'Trades when MACD histogram flips positive while RSI is oversold (< 40), confirmed by CCI.',
      config: TradeStrategyConfig(
        minSignalStrength: 50.0,
        requireAllIndicatorsGreen: false,
        startDate: DateTime.now().subtract(const Duration(days: 365)),
        endDate: DateTime.now(),
        interval: '1d',
        initialCapital: 10000.0,
        enabledIndicators: {
          'priceMovement': false,
          'momentum': false,
          'marketDirection': false,
          'volume': true,
          'macd': true,
          'bollingerBands': false,
          'stochastic': false,
          'atr': false,
          'obv': false,
          'vwap': false,
          'adx': false,
          'williamsR': false,
          'ichimoku': false,
          'cci': true, // Confirm reversal
          'parabolicSar': false,
        },
        indicatorReasons: {
          'volume': 'Volume confirms the reversal validity.',
          'macd': 'Histogram flip signals momentum change.',
          'atr': 'ATR assists in stop-loss calibration.',
          'cci': 'CCI confirms the reversal momentum.',
        },
        customIndicators: [
          CustomIndicatorConfig(
            id: 'rsi_oversold',
            name: 'RSI < 40',
            type: IndicatorType.RSI,
            parameters: {'period': 14},
            condition: SignalCondition.LessThan,
            threshold: 40.0,
            compareToPrice: false,
          ),
        ],
        riskPerTrade: 0.015,
        enableDynamicPositionSizing: true,
        takeProfitPercent: 12.0,
        stopLossPercent: 5.0,
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_bollinger_squeeze',
      name: 'Bollinger Band Squeeze',
      description:
          'Breakout strategy. Low volatility period (ATR) followed by price piercing Upper Band with CCI momentum (> 100).',
      config: TradeStrategyConfig(
        minSignalStrength: 50.0,
        requireAllIndicatorsGreen: false,
        // symbolFilter: ['MSFT'],
        startDate: DateTime.now().subtract(const Duration(days: 180)),
        endDate: DateTime.now(),
        interval: '1h',
        initialCapital: 10000.0,
        enabledIndicators: {
          'priceMovement': true,
          'momentum': false,
          'marketDirection': false,
          'volume': true,
          'macd': false,
          'bollingerBands': true,
          'stochastic': false,
          'atr': true, // Essential for checking low vol context
          'obv': false,
          'vwap': false,
          'adx': true, // Confirm trend strength on breakout
          'williamsR': false,
          'ichimoku': false,
          'cci': true, // Breakout strength
          'parabolicSar': false,
        },
        indicatorReasons: {
          'priceMovement': 'Captures the breakout move.',
          'volume': 'High volume confirms the breakout validity.',
          'bollingerBands': 'Identifies the squeeze and subsequent expansion.',
          'atr': 'Low ATR confirms the pre-breakout squeeze.',
          'adx': 'Rising ADX confirms the new trend strength.',
          'cci': 'CCI > 100 signals strong breakout momentum.',
        },
        customIndicators: [
          CustomIndicatorConfig(
            id: 'cci_breakout_momentum',
            name: 'CCI > 100',
            type: IndicatorType.CCI,
            parameters: {'period': 20},
            condition: SignalCondition.GreaterThan,
            threshold: 100.0,
            compareToPrice: false,
          ),
          CustomIndicatorConfig(
            id: 'adx_breakout_trend',
            name: 'ADX > 20',
            type: IndicatorType.ADX,
            parameters: {'period': 14},
            condition: SignalCondition.GreaterThan,
            threshold: 20.0,
            compareToPrice: false,
          ),
        ],
        riskPerTrade: 0.015,
        enableDynamicPositionSizing: true,
        takeProfitPercent: 8.0,
        stopLossPercent: 3.0,
        trailingStopEnabled: true,
        trailingStopPercent: 1.5,
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_vwap_pullback',
      name: 'VWAP Pullback Entry',
      description:
          'Intraday: Trend is UP (Price > SMA), but entry is a pullback to VWAP.',
      config: TradeStrategyConfig(
        minSignalStrength: 50.0,
        requireAllIndicatorsGreen: false,
        startDate: DateTime.now().subtract(const Duration(days: 30)),
        endDate: DateTime.now(),
        interval: '15m',
        initialCapital: 25000.0,
        enabledIndicators: {
          'priceMovement': true,
          'momentum': false,
          'marketDirection': true, // SMA for trend context
          'volume': true,
          'macd': false,
          'bollingerBands': false,
          'stochastic': false,
          'atr': false,
          'obv': false,
          'vwap': true, // The primary signal generator here
          'adx': false,
          'williamsR': true, // Timing entry
          'ichimoku': false,
          'cci': false,
          'parabolicSar': false,
        },
        indicatorReasons: {
          'priceMovement': 'Aligns entry with recent price direction.',
          'marketDirection':
              'Approves trades only in direction of major trend (SMA).',
          'volume': 'Ensures liquidity during the pullback.',
          'vwap': 'Acts as the primary mean-reversion target for entry.',
          'williamsR': 'Times the entry at the precise oversold moment.',
        },
        customIndicators: [
          CustomIndicatorConfig(
            id: 'williams_oversold',
            name: 'Williams %R < -80',
            type: IndicatorType.WilliamsR,
            parameters: {'period': 14},
            condition: SignalCondition.LessThan,
            threshold: -80.0,
            compareToPrice: false,
          ),
        ],
        riskPerTrade: 0.01,
        enableDynamicPositionSizing: true,
        takeProfitPercent: 4.0,
        stopLossPercent: 1.5,
        trailingStopEnabled: true,
        trailingStopPercent: 1.0,
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_0dte_scalper',
      name: '0DTE Scalper (5m)',
      description:
          'High-frequency style: SPY 5m chart, riding rapid momentum (CCI > 100, RSI > 55) bursts with tight risk.',
      config: TradeStrategyConfig(
        minSignalStrength: 65.0,
        requireAllIndicatorsGreen: false,
        symbolFilter: ['SPY'],
        startDate: DateTime.now().subtract(const Duration(days: 7)),
        endDate: DateTime.now(),
        interval: '5m',
        initialCapital: 25000.0,
        enabledIndicators: {
          'priceMovement': true,
          'momentum': true, // RSI
          'marketDirection': false,
          'volume': true, // Essential
          'macd': false,
          'bollingerBands': true, // Volatility expansion
          'stochastic': true,
          'atr': false, // Measure moves (Stops only)
          'obv': false,
          'vwap': true, // Intraday anchor
          'adx': false, // Trend strength
          'williamsR': false,
          'ichimoku': false,
          'cci': true, // Speed
          'parabolicSar': true, // Trailing
        },
        indicatorReasons: {
          'priceMovement': 'Scalping requires immediate price agreement.',
          'momentum': 'RSI indicates burst capability.',
          'volume': 'High volume essential for instant execution.',
          'bollingerBands': 'Volatility expansion triggers entries.',
          'stochastic': 'Fast oscillator identifying quick pivots.',
          'atr': 'Measures immediate volatility for stops.',
          'vwap': 'Intraday anchor relative to price.',
          'adx': 'ADX confirms trend is strong enough to scalp.',
          'cci': 'CCI detects the momentum surge velocity.',
          'parabolicSar': 'Extremely tight trailing stop.',
        },
        customIndicators: [
          CustomIndicatorConfig(
            id: 'cci_scalp',
            name: 'CCI > 100',
            type: IndicatorType.CCI,
            parameters: {'period': 20},
            condition: SignalCondition.GreaterThan,
            threshold: 100.0,
            compareToPrice: false,
          ),
          CustomIndicatorConfig(
            id: 'adx_scalp_trend',
            name: 'ADX > 20',
            type: IndicatorType.ADX,
            parameters: {'period': 14},
            condition: SignalCondition.GreaterThan,
            threshold: 20.0,
            compareToPrice: false,
          ),
        ],
        tradeQuantity: 10,
        takeProfitPercent: 1.0, // Quick scalp
        riskPerTrade: 0.005,
        enableDynamicPositionSizing: true,
        stopLossPercent: 0.5,
        trailingStopEnabled: true,
        trailingStopPercent: 0.2,
        timeBasedExitEnabled: true,
        timeBasedExitMinutes: 30, // Don't hold long
        marketCloseExitEnabled: true,
        marketCloseExitMinutes: 5,
        enablePartialExits: true,
        exitStages: [
          ExitStage(profitTargetPercent: 0.5, quantityPercent: 0.5),
        ],
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_tech_sector_swing',
      name: 'Tech Sector Swing',
      description:
          'Trend following on XLK (Tech Sector). Captures multi-day moves confirmed by Ichimoku Cloud and strong ADX (> 25).',
      config: TradeStrategyConfig(
        minSignalStrength: 60.0,
        requireAllIndicatorsGreen: false,
        symbolFilter: ['XLK'],
        startDate: DateTime.now().subtract(const Duration(days: 365)),
        endDate: DateTime.now(),
        interval: '1h',
        initialCapital: 25000.0,
        enabledIndicators: {
          'priceMovement': true,
          'momentum': false,
          'marketDirection': true, // SMA Crosses
          'volume': false,
          'macd': true,
          'bollingerBands': false,
          'stochastic': false,
          'atr': false,
          'obv': true, // Accumulation
          'vwap': false,
          'adx': false, // Strong trend only
          'williamsR': false,
          'ichimoku': true, // Trend confirm
          'cci': false,
          'parabolicSar': true, // Trailing
        },
        indicatorReasons: {
          'priceMovement': 'Confirming the sector trend.',
          'marketDirection': 'SMA crosses signal broad trend changes.',
          'macd': 'MACD confirms the swing momentum.',
          'atr': 'Calculates appropriate swing stop distance.',
          'obv': 'Rising OBV confirms institutional accumulation.',
          'adx': 'ADX > 25 filters out choppy range-bound periods.',
          'ichimoku': 'Ichimoku cloud provides support for the swing.',
          'parabolicSar': 'Protects profits as the swing matures.',
        },
        customIndicators: [
          CustomIndicatorConfig(
            id: 'adx_strong_trend',
            name: 'ADX > 25',
            type: IndicatorType.ADX,
            parameters: {'period': 14},
            condition: SignalCondition.GreaterThan,
            threshold: 25.0,
            compareToPrice: false,
          ),
        ],
        riskPerTrade: 0.015,
        enableDynamicPositionSizing: true,
        takeProfitPercent: 10.0,
        stopLossPercent: 4.0,
        trailingStopEnabled: true,
        trailingStopPercent: 3.0,
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_defensive_dividend',
      name: 'Defensive Value',
      description:
          'Low-beta strategy on SCHD. Buys dips (RSI < 30) in uptrends with CCI oversold confirmation (CCI < -100).',
      config: TradeStrategyConfig(
        minSignalStrength: 50.0,
        requireAllIndicatorsGreen: false,
        symbolFilter: ['SCHD'],
        startDate: DateTime.now().subtract(const Duration(days: 730)),
        endDate: DateTime.now(),
        interval: '1d',
        initialCapital: 10000.0,
        enabledIndicators: {
          'priceMovement': false,
          'momentum': false,
          'marketDirection': true, // Ensure we are in a bull market
          'volume': false,
          'macd': false,
          'bollingerBands': true, // Buy lower band
          'stochastic': true, // Oversold
          'atr': false,
          'obv': false,
          'vwap': false,
          'adx': false,
          'williamsR': true,
          'ichimoku': false,
          'cci': true, // Oversold
          'parabolicSar': false,
        },
        indicatorReasons: {
          'marketDirection': 'Approves entries only when primary trend is up.',
          'bollingerBands': 'Lower band touch signals potential value entry.',
          'stochastic': 'Confirms the dip is oversold.',
          'williamsR': 'Oscillator confirms deep discount zones.',
          'cci': 'CCI < -100 filters for statistical anomalies to buy.',
        },
        customIndicators: [
          CustomIndicatorConfig(
            id: 'rsi_deep_oversold',
            name: 'RSI < 30',
            type: IndicatorType.RSI,
            parameters: {'period': 14},
            condition: SignalCondition.LessThan,
            threshold: 30.0,
            compareToPrice: false,
          ),
          CustomIndicatorConfig(
            id: 'cci_oversold_dip',
            name: 'CCI < -100',
            type: IndicatorType.CCI,
            parameters: {'period': 20},
            condition: SignalCondition.LessThan,
            threshold: -100.0,
            compareToPrice: false,
          ),
        ],
        riskPerTrade: 0.01,
        enableDynamicPositionSizing: true,
        takeProfitPercent: 6.0,
        stopLossPercent: 4.0, // Wider stop for value
        trailingStopEnabled: false,
        enableDrawdownProtection: true,
        maxDrawdown: 0.10,
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_cloud_breakout',
      name: 'Ichimoku Cloud Breakout',
      description:
          'Trend-following strategy utilizing the Ichimoku Cloud for support/resistance, Parabolic SAR for stops, and CCI > 100 for momentum.',
      config: TradeStrategyConfig(
        minSignalStrength: 65.0,
        requireAllIndicatorsGreen: false,
        startDate: DateTime.now().subtract(const Duration(days: 365)),
        endDate: DateTime.now(),
        interval: '1d',
        initialCapital: 25000.0,
        enabledIndicators: {
          'priceMovement': true,
          'momentum': false,
          'marketDirection': true,
          'volume': false,
          'macd': false,
          'bollingerBands': false,
          'stochastic': false,
          'atr': false,
          'obv': false,
          'vwap': false,
          'adx': true,
          'williamsR': false,
          'ichimoku': true,
          'cci': true,
          'parabolicSar': true,
        },
        indicatorReasons: {
          'priceMovement': 'Price action confirms the breakout.',
          'marketDirection': 'Trend alignment with moving averages.',
          'atr': 'ATR manages the stop placement distance.',
          'adx': 'ADX confirms the trend strength is sufficient.',
          'ichimoku': 'Cloud breakout is the primary signal.',
          'cci': 'CCI confirms the breakout momentum.',
          'parabolicSar': 'Trailing stop protects the new trend profits.',
        },
        customIndicators: [
          CustomIndicatorConfig(
            id: 'cci_cloud_breakout',
            name: 'CCI > 100',
            type: IndicatorType.CCI,
            parameters: {'period': 20},
            condition: SignalCondition.GreaterThan,
            threshold: 100.0,
            compareToPrice: false,
          ),
          CustomIndicatorConfig(
            id: 'adx_trend_cloud',
            name: 'ADX > 20',
            type: IndicatorType.ADX,
            parameters: {'period': 14},
            condition: SignalCondition.GreaterThan,
            threshold: 20.0,
            compareToPrice: false,
          ),
        ],
        takeProfitPercent: 18.0,
        stopLossPercent: 7.0,
        trailingStopEnabled: true,
        trailingStopPercent: 4.0,
        riskPerTrade: 0.02,
        enableDynamicPositionSizing: true,
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_triple_screen_sim',
      name: 'Triple Screen Simulation',
      description:
          'Simulates Elder\'s Triple Screen: Trend (MACD/SMA) + Oscillator (Stochastic < 20) + Breakout (Price).',
      config: TradeStrategyConfig(
        minSignalStrength: 60.0,
        requireAllIndicatorsGreen: false,
        startDate: DateTime.now().subtract(const Duration(days: 365)),
        endDate: DateTime.now(),
        interval: '1d',
        initialCapital: 25000.0,
        enabledIndicators: {
          'priceMovement': true, // Screen 3: Execution
          'momentum': false,
          'marketDirection': true, // Screen 1: Trend (SMA)
          'volume': false,
          'macd': true, // Screen 1: Trend (Momentum)
          'bollingerBands': false,
          'stochastic': true, // Screen 2: Value
          'atr': false,
          'obv': false,
          'vwap': false,
          'adx': true, // Trend strength
          'williamsR': true, // Screen 2: Value alternative
          'ichimoku': false,
          'cci': false,
          'parabolicSar': true, // Risk management
        },
        indicatorReasons: {
          'priceMovement': 'Screen 3: Execution trigger on breakout.',
          'marketDirection': 'Screen 1: Long-term trend direction check.',
          'macd': 'Screen 1: Momentum alignment with trend.',
          'stochastic': 'Screen 2: Identifies oversold pullbacks.',
          'atr': 'Manages risk sizing and stop levels.',
          'adx': 'Confirms trend presence.',
          'williamsR': 'Alternative value indicator for Screen 2.',
          'parabolicSar': 'Trailing stop for trade management.',
        },
        customIndicators: [
          CustomIndicatorConfig(
            id: 'stoch_pullback',
            name: 'Stochastic < 20',
            type: IndicatorType.Stochastic,
            parameters: {'period': 14},
            condition: SignalCondition.LessThan,
            threshold: 20.0,
            compareToPrice: false,
          ),
        ],
        riskPerTrade: 0.015,
        enableDynamicPositionSizing: true,
        takeProfitPercent: 12.0,
        stopLossPercent: 4.0,
        trailingStopEnabled: true,
        trailingStopPercent: 2.5,
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_opening_range_breakout',
      name: 'Opening Range Breakout',
      description:
          'Exploits early market volatility (9:30-10:30 AM). Uses VWAP as anchor and Volume/CCI (> 100) for confirmation.',
      config: TradeStrategyConfig(
        minSignalStrength: 75.0,
        requireAllIndicatorsGreen: false,
        startDate: DateTime.now().subtract(const Duration(days: 90)),
        endDate: DateTime.now(),
        interval: '5m',
        initialCapital: 25000.0,
        enabledIndicators: {
          'priceMovement': true, // Break high/low
          'momentum': true, // RSI
          'marketDirection': false,
          'volume': true, // Critical for ORB
          'macd': false,
          'bollingerBands': false,
          'stochastic': false,
          'atr': false, // Volatility check (Sizing)
          'obv': false,
          'vwap': true, // Anchor
          'adx': false,
          'williamsR': false,
          'ichimoku': false,
          'cci': true, // Momentum burst
          'parabolicSar': false,
        },
        indicatorReasons: {
          'priceMovement': 'Detects the breakout of the opening range.',
          'momentum': 'RSI confirms early momentum.',
          'volume': 'Volume spike validates the breakout move.',
          'atr': 'Measures morning volatility for risk management.',
          'vwap': 'VWAP serves as the anchor/support level.',
          'cci': 'CCI identifies the initial burst of speed.',
        },
        customIndicators: [
          CustomIndicatorConfig(
            id: 'cci_orb_burst',
            name: 'CCI > 100',
            type: IndicatorType.CCI,
            parameters: {'period': 20},
            condition: SignalCondition.GreaterThan,
            threshold: 100.0,
            compareToPrice: false,
          ),
        ],
        riskPerTrade: 0.015,
        enableDynamicPositionSizing: true,
        takeProfitPercent: 2.5,
        stopLossPercent: 1.0,
        trailingStopEnabled: true,
        trailingStopPercent: 0.8,
        timeBasedExitEnabled: true,
        timeBasedExitMinutes: 60, // Exit by 10:30/11:00 usually
        marketCloseExitEnabled: true,
        marketCloseExitMinutes: 5,
        enablePartialExits: true,
        exitStages: [
          ExitStage(profitTargetPercent: 1.0, quantityPercent: 0.5),
        ],
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_turtle_trend',
      name: 'Turtle Trend Follower',
      description:
          'Long-term breakout strategy inspired by Turtle Traders. Buys new highs with meaningful ATR-based volatility stops.',
      config: TradeStrategyConfig(
        minSignalStrength: 65.0,
        requireAllIndicatorsGreen: false,
        startDate:
            DateTime.now().subtract(const Duration(days: 1095)), // 3 years
        endDate: DateTime.now(),
        interval: '1d',
        initialCapital: 50000.0,
        enabledIndicators: {
          'priceMovement': true, // Breakout detection
          'momentum': false,
          'marketDirection': true, // SMA Trend
          'volume': false,
          'macd': false,
          'bollingerBands': false,
          'stochastic': false,
          'atr': false, // Volatility stops (Sizing)
          'obv': false,
          'vwap': false,
          'adx': true, // Trend strength
          'williamsR': false,
          'ichimoku': false,
          'cci': false,
          'parabolicSar': true, // Trailing stop
        },
        indicatorReasons: {
          'priceMovement': 'Identifies breakouts to new highs.',
          'marketDirection': 'Confirms long-term trend direction.',
          'atr': 'Critical for "N" volatility calculations and stops.',
          'adx': 'Ensures the trend is strong enough to follow.',
          'parabolicSar': 'Acts as the mechanical trailing stop.',
        },
        riskPerTrade: 0.02,
        takeProfitPercent: 30.0,
        stopLossPercent: 10.0,
        trailingStopEnabled: true,
        trailingStopPercent: 5.0,
        enableDynamicPositionSizing: true,
        atrMultiplier: 2.5,
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_rsi_fade',
      name: 'RSI Reversal (Long)',
      description:
          'Contrarian Mean Reversion. Buys when RSI < 30 (Oversold) and price hits Lower Bollinger Band while ADX suggests trend exhaustion.',
      config: TradeStrategyConfig(
        minSignalStrength: 50.0,
        requireAllIndicatorsGreen: false,
        startDate: DateTime.now().subtract(const Duration(days: 365)),
        endDate: DateTime.now(),
        interval: '1h',
        initialCapital: 25000.0,
        enabledIndicators: {
          'priceMovement': true,
          'momentum': true, // RSI
          'marketDirection': false,
          'volume': false,
          'macd': false,
          'bollingerBands':
              true, // Reversal zone (Lower Band implied by oversold)
          'stochastic': true, // Confirmation
          'atr': false,
          'obv': false,
          'vwap': false,
          'adx':
              false, // Ensure no strong trend (implied inverse logic if checked?)
          'williamsR': true,
          'ichimoku': false,
          'cci': true,
          'parabolicSar': false,
        },
        indicatorReasons: {
          'momentum': 'RSI < 30 signals extremely oversold conditions.',
          'bollingerBands':
              'Lower band touch indicates potential reversal point.',
          'stochastic': 'Confirms the oversold momentum status.',
          'adx': 'Lower ADX values imply a range where reversals are likely.',
          'williamsR': 'Oscillator confirms deep oversold readings.',
          'cci': 'CCI deviation hints at an imminent snap-back.',
        },
        customIndicators: [
          CustomIndicatorConfig(
            id: 'rsi_extreme_oversold',
            name: 'RSI < 30',
            type: IndicatorType.RSI,
            parameters: {'period': 14},
            condition: SignalCondition.LessThan,
            threshold: 30.0,
            compareToPrice: false,
          ),
          CustomIndicatorConfig(
            id: 'cci_oversold_reversal',
            name: 'CCI < -100',
            type: IndicatorType.CCI,
            parameters: {'period': 20},
            condition: SignalCondition.LessThan,
            threshold: -100.0,
            compareToPrice: false,
          ),
          CustomIndicatorConfig(
            id: 'adx_low_trend',
            name: 'ADX < 25',
            type: IndicatorType.ADX,
            parameters: {'period': 14},
            condition: SignalCondition.LessThan,
            threshold: 25.0,
            compareToPrice: false,
          ),
        ],
        riskPerTrade: 0.01,
        enableDynamicPositionSizing: true,
        takeProfitPercent: 5.0,
        stopLossPercent: 3.0,
        trailingStopEnabled: false,
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_swing_master_4h',
      name: 'Swing Master (4h)',
      description:
          'Balanced swing trading strategy on 4-hour charts. Captures multi-day trends using EMA crossovers (Market Dir), MACD, and ADX > 25.',
      config: TradeStrategyConfig(
        minSignalStrength: 60.0,
        requireAllIndicatorsGreen: false,
        startDate: DateTime.now().subtract(const Duration(days: 180)),
        endDate: DateTime.now(),
        interval: '4h', // Missing interval in defaults
        initialCapital: 25000.0,
        enabledIndicators: {
          'priceMovement': true,
          'momentum': true,
          'marketDirection': true, // Key for swings
          'volume': false,
          'macd': true,
          'bollingerBands': false,
          'stochastic': false,
          'atr': false,
          'obv': false,
          'vwap': false,
          'adx': false, // Using custom indicator
          'williamsR': false,
          'ichimoku': false,
          'cci': false,
          'parabolicSar': true, // Trailing stops
        },
        indicatorReasons: {
          'priceMovement': 'Price action alignment with swing direction.',
          'momentum': 'Momentum confirms the swing strength.',
          'marketDirection': 'Moving averages define the swing context.',
          'macd': 'MACD confirms the momentum behind the swing.',
          'atr': 'ATR sets adequate stops for 4h volatility.',
          'adx': 'ADX > 25 confirms the swing integrity.',
          'parabolicSar': 'Parabolic SAR manages the trailing stop.',
        },
        customIndicators: [
          CustomIndicatorConfig(
            id: 'adx_trend_swing',
            name: 'ADX > 25',
            type: IndicatorType.ADX,
            parameters: {'period': 14},
            condition: SignalCondition.GreaterThan,
            threshold: 25.0,
            compareToPrice: false,
          ),
        ],
        riskPerTrade: 0.015,
        enableDynamicPositionSizing: true,
        takeProfitPercent: 8.0,
        stopLossPercent: 3.0,
        trailingStopEnabled: true,
        trailingStopPercent: 2.0,
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_penny_stock_runner',
      name: 'Penny Stock Breakout',
      description:
          'High risk/reward strategy for volatile small-caps. Demands massive relative volume and strong momentum (RSI > 55, CCI > 100).',
      config: TradeStrategyConfig(
        minSignalStrength: 70.0,
        requireAllIndicatorsGreen: false,
        startDate: DateTime.now().subtract(const Duration(days: 60)),
        endDate: DateTime.now(),
        interval: '15m',
        initialCapital: 5000.0,
        enabledIndicators: {
          'priceMovement': true,
          'momentum': true,
          'marketDirection': false,
          'volume': true, // Critical
          'macd': false,
          'bollingerBands': true, // Squeeze breaks
          'stochastic': false,
          'atr': false, // Volatility check (Sizing)
          'obv': true, // Smart money flow
          'vwap': true, // Support
          'adx': true, // Trend strength
          'williamsR': false,
          'ichimoku': false,
          'cci': true, // Scalper
          'parabolicSar': false,
        },
        indicatorReasons: {
          'priceMovement': 'Breakout price action is king.',
          'momentum':
              'RSI > 55 signals bullish momentum without overextension.',
          'volume': 'Massive volume validates the move.',
          'bollingerBands': 'Breakout from band squeeze.',
          'atr': 'Risk management in high-volatility environment.',
          'obv': 'Smart money accumulation prior to the move.',
          'vwap': 'Intraday support/entry anchor.',
          'adx': 'Strong trend required for runners.',
          'cci': 'High velocity breakout signal.',
        },
        customIndicators: [
          CustomIndicatorConfig(
            id: 'rsi_bullish',
            name: 'RSI > 55',
            type: IndicatorType.RSI,
            parameters: {'period': 14},
            condition: SignalCondition.GreaterThan,
            threshold: 55.0,
            compareToPrice: false,
          ),
          CustomIndicatorConfig(
            id: 'cci_breakout_penny',
            name: 'CCI > 100',
            type: IndicatorType.CCI,
            parameters: {'period': 20},
            condition: SignalCondition.GreaterThan,
            threshold: 100.0,
            compareToPrice: false,
          ),
        ],
        riskPerTrade: 0.02, // Aggressive
        takeProfitPercent: 15.0, // Runners
        stopLossPercent: 5.0,
        trailingStopEnabled: true,
        trailingStopPercent: 3.0,
        enableDynamicPositionSizing: true,
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_energy_sector_drift',
      name: 'Energy Sector Drift',
      description:
          'Captures sustained trends in Energy (XLE). Uses OBV to confirm institutional accumulation alongside ADX > 25.',
      config: TradeStrategyConfig(
        minSignalStrength: 60.0,
        requireAllIndicatorsGreen: false,
        symbolFilter: ['XLE', 'VDE', 'OIH'],
        startDate: DateTime.now().subtract(const Duration(days: 365)),
        endDate: DateTime.now(),
        interval: '1d',
        initialCapital: 25000.0,
        enabledIndicators: {
          'priceMovement': true,
          'momentum': false,
          'marketDirection': true,
          'volume': true,
          'macd': false,
          'bollingerBands': false,
          'stochastic': false,
          'atr': false,
          'obv': true, // Critical
          'vwap': false,
          'adx': false, // Trend strength
          'williamsR': false,
          'ichimoku': false,
          'cci': false,
          'parabolicSar': true,
        },
        indicatorReasons: {
          'priceMovement': 'Price drift direction.',
          'marketDirection': 'Trend confirmation via SMAs.',
          'volume': 'Volume confirms the sector move.',
          'atr': 'ATR accounts for sector volatility.',
          'obv': 'OBV confirms institutional accumulation in the sector.',
          'adx': 'ADX measures the strength of the drift.',
          'parabolicSar': 'Trailing stop protects accumulated drift profits.',
        },
        customIndicators: [
          CustomIndicatorConfig(
            id: 'adx_trend_energy',
            name: 'ADX > 25',
            type: IndicatorType.ADX,
            parameters: {'period': 14},
            condition: SignalCondition.GreaterThan,
            threshold: 25.0,
            compareToPrice: false,
          ),
        ],
        riskPerTrade: 0.015,
        enableDynamicPositionSizing: true,
        takeProfitPercent: 12.0,
        stopLossPercent: 5.0,
        trailingStopEnabled: true,
        trailingStopPercent: 2.0,
        rsiExitEnabled: true,
        rsiExitThreshold: 75.0,
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_bear_market_raider',
      name: 'Bear Market Raider',
      description:
          'Bearish strategy for inverse ETFs (SQQQ, SPXU). Buys when market momentum breaks down (MACD Bearish, ADX > 25 on Inverse).',
      config: TradeStrategyConfig(
        minSignalStrength: 60.0,
        requireAllIndicatorsGreen: false,
        symbolFilter: ['SQQQ', 'SPXU', 'SOXS', 'SDOW', 'TZA'],
        startDate: DateTime.now().subtract(const Duration(days: 365)),
        endDate: DateTime.now(),
        interval: '1d',
        initialCapital: 25000.0,
        enabledIndicators: {
          'priceMovement': true,
          'momentum': true,
          'marketDirection':
              true, // SMA 200 Check (Must be "Bullish" on the Inverse ETF itself)
          'volume': true,
          'macd': true, // Momentum flip
          'bollingerBands': false,
          'stochastic': false,
          'atr': false, // Volatility (Sizing)
          'obv': false,
          'vwap': false,
          'adx': false, // Trend strength
          'williamsR': false,
          'ichimoku': false,
          'cci': false,
          'parabolicSar': true, // Trailing stop
        },
        indicatorReasons: {
          'priceMovement': 'Upside price action on Inverse ETF.',
          'momentum': 'Positive momentum on the inverse instrument.',
          'marketDirection': 'Trend alignment on the inverse ETF.',
          'volume': 'Volume confirms panic selling (buying of inverse).',
          'macd': 'MACD crossovers confirm the bearish market turn.',
          'atr': 'Increased volatility sizing.',
          'adx': 'Strong trend required for bear market moves.',
          'parabolicSar': 'Protect gains during volatile bear rallies.',
        },
        customIndicators: [
          CustomIndicatorConfig(
            id: 'adx_trend_inverse',
            name: 'ADX > 25',
            type: IndicatorType.ADX,
            parameters: {'period': 14},
            condition: SignalCondition.GreaterThan,
            threshold: 25.0,
            compareToPrice: false,
          ),
        ],
        riskPerTrade: 0.02,
        enableDynamicPositionSizing: true,
        takeProfitPercent: 15.0,
        stopLossPercent: 6.0,
        trailingStopEnabled: true,
        trailingStopPercent: 3.5,
        enableVolatilityFilters: true,
        minVolatility: 0.3,
        enableDrawdownProtection: true,
        maxDrawdown: 0.15,
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_biotech_catalyst',
      name: 'Biotech Catalyst Hunter',
      description:
          'Captures high-volatility moves in Biotech (XBI, IBB) driven by news/events. Uses Volume + OBV to spot accumulation.',
      config: TradeStrategyConfig(
        minSignalStrength: 65.0,
        requireAllIndicatorsGreen: false,
        symbolFilter: ['XBI', 'IBB', 'LABU'],
        startDate: DateTime.now().subtract(const Duration(days: 180)),
        endDate: DateTime.now(),
        interval: '1h',
        initialCapital: 10000.0,
        enabledIndicators: {
          'priceMovement': true,
          'momentum': false,
          'marketDirection': false,
          'volume': true, // Critical for catalysts
          'macd': false,
          'bollingerBands': true, // Expansion
          'stochastic': false,
          'atr': false,
          'obv': true, // Institutional flow
          'vwap': false,
          'adx': false, // Trend strength
          'williamsR': false,
          'ichimoku': false,
          'cci': true, // Impulse
          'parabolicSar': false,
        },
        indicatorReasons: {
          'priceMovement': 'Price reaction to catalyst.',
          'volume': 'Volume confirms the catalyst impact.',
          'bollingerBands': 'Volatility expansion post-news.',
          'atr': 'Manages high event volatility.',
          'obv': 'Flow indicates informed accumulation.',
          'adx': 'ADX confirms the new trend strength.',
          'cci': 'CCI identifies the initial impulse.',
        },
        customIndicators: [
          CustomIndicatorConfig(
            id: 'cci_impulse',
            name: 'CCI > 100',
            type: IndicatorType.CCI,
            parameters: {'period': 20},
            condition: SignalCondition.GreaterThan,
            threshold: 100.0,
            compareToPrice: false,
          ),
          CustomIndicatorConfig(
            id: 'adx_trend_start',
            name: 'ADX > 20',
            type: IndicatorType.ADX,
            parameters: {'period': 14},
            condition: SignalCondition.GreaterThan,
            threshold: 20.0,
            compareToPrice: false,
          ),
        ],
        riskPerTrade: 0.025,
        enableDynamicPositionSizing: true,
        takeProfitPercent: 20.0,
        stopLossPercent: 7.0,
        trailingStopEnabled: true,
        trailingStopPercent: 4.0,
        enableVolatilityFilters: true,
        minVolatility: 0.8,
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_gap_and_go',
      name: 'Gap & Go (15m)',
      description:
          'Intraday Strategy: Buys stocks gapping up that hold above VWAP with high relative volume. Quick profits.',
      config: TradeStrategyConfig(
        minSignalStrength: 75.0,
        requireAllIndicatorsGreen: false,
        startDate: DateTime.now().subtract(const Duration(days: 60)),
        endDate: DateTime.now(),
        interval: '15m',
        initialCapital: 25000.0,
        enabledIndicators: {
          'priceMovement': true, // Gap Up (Price > prev close implied)
          'momentum': true, // RSI > 60
          'marketDirection': false,
          'volume': true, // Must be high
          'macd': false,
          'bollingerBands': false,
          'stochastic': false,
          'atr': false,
          'obv': false,
          'vwap': true, // Price > VWAP is key
          'adx': false,
          'williamsR': false,
          'ichimoku': false,
          'cci': true, // Momentum kick
          'parabolicSar': false,
        },
        indicatorReasons: {
          'priceMovement': 'Detects the gap up and hold.',
          'momentum': 'RSI indicates strong buying pressure.',
          'volume': 'High relative volume validates the gap.',
          'atr': 'Manages the opening volatility.',
          'vwap': 'Hold above VWAP confirms bullish control.',
          'cci': 'CCI signaling a momentum ignition.',
        },
        customIndicators: [
          CustomIndicatorConfig(
            id: 'rsi_strong',
            name: 'RSI > 60',
            type: IndicatorType.RSI,
            parameters: {'period': 14},
            condition: SignalCondition.GreaterThan,
            threshold: 60.0,
            compareToPrice: false,
          ),
          CustomIndicatorConfig(
            id: 'cci_momentum_kick',
            name: 'CCI > 100',
            type: IndicatorType.CCI,
            parameters: {'period': 20},
            condition: SignalCondition.GreaterThan,
            threshold: 100.0,
            compareToPrice: false,
          ),
        ],
        riskPerTrade: 0.02,
        enableDynamicPositionSizing: true,
        takeProfitPercent: 5.0,
        stopLossPercent: 2.0,
        trailingStopEnabled: true,
        trailingStopPercent: 1.5,
        timeBasedExitEnabled: true,
        timeBasedExitMinutes: 120, // 2 hours max
        marketCloseExitEnabled: true,
        marketCloseExitMinutes: 10,
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_earnings_drift',
      name: 'Post-Earnings Drift',
      description:
          'Captures the continued move after a volatility event. Enters when Bands expand and ADX > 25 indicates a new trend.',
      config: TradeStrategyConfig(
        minSignalStrength: 70.0,
        requireAllIndicatorsGreen: false,
        startDate: DateTime.now().subtract(const Duration(days: 365)),
        endDate: DateTime.now(),
        interval: '4h',
        initialCapital: 25000.0,
        enabledIndicators: {
          'priceMovement': true,
          'momentum': false,
          'marketDirection': false,
          'volume': true, // Verification
          'macd': true,
          'bollingerBands': true, // Volatility Expansion
          'stochastic': false,
          'atr': false, // High Volatility (Sizing)
          'obv': false,
          'vwap': false,
          'adx': true, // Strong Trend (>25)
          'williamsR': false,
          'ichimoku': false,
          'cci': false,
          'parabolicSar': true, // Trailing
        },
        indicatorReasons: {
          'priceMovement': 'Captures the post-event drift.',
          'volume': 'Volume confirms the persistence of the move.',
          'macd': 'MACD confirms momentum direction.',
          'bollingerBands': 'Captures volatility expansion.',
          'atr': 'Adjusts sizing for post-earnings volatility.',
          'adx': 'ADX confirms the new trend is sticky.',
          'parabolicSar': 'Trails the drift to lock in gains.',
        },
        customIndicators: [
          CustomIndicatorConfig(
            id: 'adx_intense_trend',
            name: 'ADX > 25',
            type: IndicatorType.ADX,
            parameters: {'period': 14},
            condition: SignalCondition.GreaterThan,
            threshold: 25.0,
            compareToPrice: false,
          ),
        ],
        riskPerTrade: 0.02,
        enableDynamicPositionSizing: true,
        takeProfitPercent: 12.0,
        stopLossPercent: 5.0,
        trailingStopEnabled: true,
        trailingStopPercent: 3.0,
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_panic_dip_buyer',
      name: 'Panic Dip Buyer',
      description:
          'Contrarian strategy that buys extreme fear. Enters when RSI < 25 and price is far below Bollinger Bands in quality stocks.',
      config: TradeStrategyConfig(
        minSignalStrength: 60.0,
        requireAllIndicatorsGreen: false,
        symbolFilter: ['AAPL', 'MSFT', 'GOOGL', 'AMZN', 'NVDA', 'SPY', 'QQQ'],
        startDate: DateTime.now().subtract(const Duration(days: 730)),
        endDate: DateTime.now(),
        interval: '1d',
        initialCapital: 50000.0,
        enabledIndicators: {
          'priceMovement': false, // Looking for drops
          'momentum': true, // RSI
          'marketDirection': false,
          'volume': true, // Panic selling volume
          'macd': false,
          'bollingerBands': true, // Below lower band
          'stochastic': true, // Deep oversold
          'atr': false, // High volatility (Sizing)
          'obv': false,
          'vwap': false,
          'adx': false,
          'williamsR': true, // Ultra oversold
          'ichimoku': false,
          'cci': true,
          'parabolicSar': false,
        },
        indicatorReasons: {
          'momentum': 'RSI < 25 identifies panic conditions.',
          'volume': 'High washout volume confirms the bottoming process.',
          'bollingerBands':
              'Price well below bands signals statistical extremity.',
          'stochastic': 'Deep oversold readings support entry.',
          'atr': 'Accounts for high volatility during panic.',
          'williamsR': 'Oscillator confirms potential capitulation.',
          'cci': 'CCI identifies the snap-back potential.',
        },
        customIndicators: [
          CustomIndicatorConfig(
            id: 'rsi_panic',
            name: 'RSI < 25',
            type: IndicatorType.RSI,
            parameters: {'period': 14},
            condition: SignalCondition.LessThan,
            threshold: 25.0,
            compareToPrice: false,
          ),
        ],
        riskPerTrade: 0.02,
        enableDynamicPositionSizing: true,
        takeProfitPercent: 10.0, // Rebound target
        stopLossPercent: 8.0, // Wide stop for volatility
        trailingStopEnabled: false, // Let it run initially
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_trend_exhaustion_short',
      name: 'Trend Exhaustion Short',
      description:
          'Bearish Mean Reversion. Shorts when price extends too far above EMA/Bands and momentum wavers (RSI > 80, ADX < 20).',
      config: TradeStrategyConfig(
        minSignalStrength: 60.0,
        requireAllIndicatorsGreen: false,
        startDate: DateTime.now().subtract(const Duration(days: 365)),
        endDate: DateTime.now(),
        interval: '4h',
        initialCapital: 25000.0,
        enabledIndicators: {
          'priceMovement': false, // Contrarian
          'momentum': true, // RSI overbought
          'marketDirection': true, // Extended from SMA
          'volume': true, // Climax volume
          'macd': true, // Histogram ticking down
          'bollingerBands': true, // Outside upper band
          'stochastic': true, // Crossing down
          'atr': false,
          'obv': false,
          'vwap': false,
          'adx': false, // Trend weakening
          'williamsR': true,
          'ichimoku': false,
          'cci': true,
          'parabolicSar': false,
        },
        indicatorReasons: {
          'momentum': 'RSI > 80 signals unsustainable buying.',
          'marketDirection': 'Checks extension from mean (SMA).',
          'volume': 'Climax volume often marks tops.',
          'macd': 'MACD confirms momentum is stalling.',
          'bollingerBands': 'Price outside upper band invites mean reversion.',
          'stochastic': 'Bearish crossover signals immediate downturn.',
          'atr': 'Risk management for volatile tops.',
          'adx': 'Falling ADX signals trend exhaustion.',
          'williamsR': 'Overbought verification.',
          'cci': 'Extreme displacement from mean.',
        },
        customIndicators: [
          CustomIndicatorConfig(
            id: 'rsi_overbought_80',
            name: 'RSI > 80',
            type: IndicatorType.RSI,
            parameters: {'period': 14},
            condition: SignalCondition.GreaterThan,
            threshold: 80.0,
            compareToPrice: false,
          ),
          CustomIndicatorConfig(
            id: 'adx_weak_trend',
            name: 'ADX < 20',
            type: IndicatorType.ADX,
            parameters: {'period': 14},
            condition: SignalCondition.LessThan,
            threshold: 20.0,
            compareToPrice: false,
          ),
        ],
        riskPerTrade: 0.015,
        enableDynamicPositionSizing: true,
        takeProfitPercent: 6.0,
        stopLossPercent: 3.0,
        trailingStopEnabled: true,
        trailingStopPercent: 1.5,
        rsiExitEnabled: true,
        rsiExitThreshold: 40.0, // Exit when no longer oversold
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_low_vol_accumulation',
      name: 'Low Volatility Accumulation',
      description:
          'Pre-Breakout setup. Identifies periods of compression (Low ATR, Narrow Bands, ADX < 20) before a potential move.',
      config: TradeStrategyConfig(
        minSignalStrength: 50.0,
        requireAllIndicatorsGreen: false,
        startDate: DateTime.now().subtract(const Duration(days: 365)),
        endDate: DateTime.now(),
        interval: '1d',
        initialCapital: 25000.0,
        enabledIndicators: {
          'priceMovement': true,
          'momentum': false,
          'marketDirection': true, // Consolidated
          'volume': true, // Drying up?
          'macd': false,
          'bollingerBands': true, // Squeeze
          'stochastic': false,
          'atr': true, // CRITICAL: Low ATR
          'obv': true, // Accumulation hints
          'vwap': false,
          'adx': false, // Low ADX (No trend yet)
          'williamsR': false,
          'ichimoku': false,
          'cci': false,
          'parabolicSar': false,
        },
        indicatorReasons: {
          'priceMovement': 'Price action is range-bound prior to breakout.',
          'marketDirection': 'Flat moving averages confirm consolidation.',
          'volume': 'Dry volume indicates lack of sellers.',
          'bollingerBands': 'Band squeeze identifies volatility compression.',
          'atr': 'Low ATR confirms the quiet period.',
          'obv': 'Rising OBV amidst flat price signals accumulation.',
          'adx': 'Low ADX ensures no existing trend filters trades.',
        },
        customIndicators: [
          CustomIndicatorConfig(
            id: 'adx_consolidation',
            name: 'ADX < 20',
            type: IndicatorType.ADX,
            parameters: {'period': 14},
            condition: SignalCondition.LessThan,
            threshold: 20.0,
            compareToPrice: false,
          ),
        ],
        riskPerTrade: 0.015,
        enableDynamicPositionSizing: true,
        takeProfitPercent: 15.0,
        stopLossPercent: 4.0, // Tight stop possible in low vol
        trailingStopEnabled: true,
        trailingStopPercent: 3.0,
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_death_cross_short',
      name: 'Death Cross Short',
      description:
          'Major bearish trend signal. Enters short when SMA 50 crosses below SMA 200 with strong trend confirmation (ADX > 25).',
      config: TradeStrategyConfig(
        minSignalStrength: 50.0,
        requireAllIndicatorsGreen: false,
        startDate: DateTime.now().subtract(const Duration(days: 1095)),
        endDate: DateTime.now(),
        interval: '1d',
        initialCapital: 50000.0,
        enabledIndicators: {
          'priceMovement': false, // Bearish
          'momentum': false,
          'marketDirection': true, // SMA Crossover Key
          'volume': true,
          'macd': true,
          'bollingerBands': false,
          'stochastic': false,
          'atr': false, // Volatility check (Sizing)
          'obv': false,
          'vwap': false,
          'adx': false, // Confirm trend strength
          'williamsR': false,
          'ichimoku': true, // Cloud confirmation
          'cci': false,
          'parabolicSar': true, // Trailing stop
        },
        indicatorReasons: {
          'marketDirection':
              'SMA 50 crossing below SMA 200 confirms bear market.',
          'volume': 'Volume confirms the selling pressure.',
          'macd': 'MACD negativity confirms bearish momentum.',
          'atr': 'Adjusts stops for bear market volatility.',
          'adx': 'ADX confirms the strength of the downtrend.',
          'ichimoku': 'Price below Cloud confirms resistance.',
          'parabolicSar': 'Trailing stop mechanism.',
        },
        smaPeriodFast: 50,
        smaPeriodSlow: 200,
        customIndicators: [
          CustomIndicatorConfig(
            id: 'adx_trend_bear',
            name: 'ADX > 25',
            type: IndicatorType.ADX,
            parameters: {'period': 14},
            condition: SignalCondition.GreaterThan,
            threshold: 25.0,
            compareToPrice: false,
          ),
        ],
        riskPerTrade: 0.02,
        enableDynamicPositionSizing: true,
        takeProfitPercent: 25.0,
        stopLossPercent: 8.0,
        trailingStopEnabled: true,
        trailingStopPercent: 5.0,
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_inside_bar_breakout',
      name: 'Inside Bar Breakout',
      description:
          'Price Action Strategy: Identifies consolidation (Inside Bar) on the 1h chart and enters on the subsequent breakout.',
      config: TradeStrategyConfig(
        minSignalStrength: 60.0,
        requireAllIndicatorsGreen: false,
        startDate: DateTime.now().subtract(const Duration(days: 90)),
        endDate: DateTime.now(),
        interval: '1h',
        initialCapital: 25000.0,
        enabledIndicators: {
          'priceMovement': true, // Key: Candle patterns
          'momentum': false,
          'marketDirection': false,
          'volume': true, // Breakout volume
          'macd': false,
          'bollingerBands': true, // Squeeze context
          'stochastic': false,
          'atr': false, // Profit targets based on ATR (Sizing)
          'obv': false,
          'vwap': false,
          'adx': false,
          'williamsR': false,
          'ichimoku': false,
          'cci': false,
          'parabolicSar': false,
        },
        indicatorReasons: {
          'priceMovement': 'Identifies the Inside Bar consolidation pattern.',
          'volume': 'High volume required on the breakout candle.',
          'bollingerBands': 'Bands often squeeze during inside bars.',
          'atr': 'Calculates the breakout target distance.',
        },
        riskPerTrade: 0.01,
        enableDynamicPositionSizing: true,
        takeProfitPercent: 4.0,
        stopLossPercent: 1.5,
        trailingStopEnabled: true,
        trailingStopPercent: 1.0,
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_high_tight_flag',
      name: 'High & Tight Flag',
      description:
          'Aggressive Growth: Targets stocks that have doubled in 8 weeks. Buys breakout with RSI > 60 and ADX > 40.',
      config: TradeStrategyConfig(
        minSignalStrength: 75.0,
        requireAllIndicatorsGreen: false,
        startDate: DateTime.now().subtract(const Duration(days: 365)),
        endDate: DateTime.now(),
        interval: '1d',
        initialCapital: 25000.0,
        enabledIndicators: {
          'priceMovement': true, // Momentum
          'momentum': true, // RSI > 60-70 maintained
          'marketDirection': true, // Strong Uptrend
          'volume': true, // Low volume on flag, high on break
          'macd': false,
          'bollingerBands': false,
          'stochastic': false,
          'atr': false,
          'obv': true, // No distribution allowed
          'vwap': false,
          'adx': false, // ADX > 40 typically
          'williamsR': false,
          'ichimoku': false,
          'cci': true,
          'parabolicSar': true,
        },
        indicatorReasons: {
          'priceMovement': 'Confirms the flag breakout structure.',
          'momentum': 'RSI indicates sustained buying pressure.',
          'marketDirection': 'Approves only the strongest uptrends.',
          'volume': 'Volume analysis validates consolidation vs breakout.',
          'atr': 'Manages risk in high-beta setups.',
          'obv': 'Ensures no distribution during the flag.',
          'adx': 'ADX > 40 confirms a powerhouse trend.',
          'cci': 'CCI identifies the resumption of the move.',
          'parabolicSar': 'Trailing stop prevents giving back open profits.',
        },
        customIndicators: [
          CustomIndicatorConfig(
            id: 'rsi_strong_trend',
            name: 'RSI > 60',
            type: IndicatorType.RSI,
            parameters: {'period': 14},
            condition: SignalCondition.GreaterThan,
            threshold: 60.0,
            compareToPrice: false,
          ),
          CustomIndicatorConfig(
            id: 'adx_super_trend',
            name: 'ADX > 40',
            type: IndicatorType.ADX,
            parameters: {'period': 14},
            condition: SignalCondition.GreaterThan,
            threshold: 40.0,
            compareToPrice: false,
          ),
          CustomIndicatorConfig(
            id: 'cci_impulse_flag',
            name: 'CCI > 100',
            type: IndicatorType.CCI,
            parameters: {'period': 20},
            condition: SignalCondition.GreaterThan,
            threshold: 100.0,
            compareToPrice: false,
          ),
        ],
        riskPerTrade: 0.025,
        enableDynamicPositionSizing: true,
        takeProfitPercent: 40.0, // Multi-baggers
        stopLossPercent: 7.0,
        trailingStopEnabled: true,
        trailingStopPercent: 5.0,
        enableVolatilityFilters: true,
        minVolatility: 0.5, // Needs to move
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_triple_ema_growth',
      name: 'Triple EMA Trend',
      description:
          'Classic Trend Following: Enters when Price > EMA 9 > EMA 21 > EMA 50 on the 4-hour chart. Captures smooth trends.',
      config: TradeStrategyConfig(
        minSignalStrength: 65.0,
        requireAllIndicatorsGreen: false,
        startDate: DateTime.now().subtract(const Duration(days: 365)),
        endDate: DateTime.now(),
        interval: '4h',
        initialCapital: 25000.0,
        enabledIndicators: {
          'priceMovement': true,
          'momentum': true, // RSI
          'marketDirection': true,
          'volume': false,
          'macd': true,
          'bollingerBands': false,
          'stochastic': false,
          'atr': false,
          'obv': false,
          'vwap': false,
          'adx': false, // Trend strength
          'williamsR': false,
          'ichimoku': false,
          'cci': false,
          'parabolicSar': true, // Trailing stop
        },
        indicatorReasons: {
          'priceMovement': 'Price action aligns with the EMA stack.',
          'momentum': 'RSI indicates healthy trend momentum.',
          'marketDirection': 'Moving Average stack defines the trend.',
          'macd': 'MACD confirms directional strength.',
          'atr': 'Calculates stop distance for the trend.',
          'adx': 'ADX confirms trend is strong enough to follow.',
          'parabolicSar': 'Trailing stop mechanism.',
        },
        customIndicators: [
          CustomIndicatorConfig(
            id: 'ema_fast_check',
            name: 'Price > EMA 9',
            type: IndicatorType.EMA,
            parameters: {'period': 9},
            condition: SignalCondition.GreaterThan,
            compareToPrice: true,
          ),
          CustomIndicatorConfig(
            id: 'ema_mid_check',
            name: 'Price > EMA 21',
            type: IndicatorType.EMA,
            parameters: {'period': 21},
            condition: SignalCondition.GreaterThan,
            compareToPrice: true,
          ),
          CustomIndicatorConfig(
            id: 'ema_slow_check',
            name: 'Price > EMA 50',
            type: IndicatorType.EMA,
            parameters: {'period': 50},
            condition: SignalCondition.GreaterThan,
            compareToPrice: true,
          ),
          CustomIndicatorConfig(
            id: 'adx_trend_ema',
            name: 'ADX > 25',
            type: IndicatorType.ADX,
            parameters: {'period': 14},
            condition: SignalCondition.GreaterThan,
            threshold: 25.0,
            compareToPrice: false,
          ),
        ],
        riskPerTrade: 0.02,
        enableDynamicPositionSizing: true,
        takeProfitPercent: 15.0,
        stopLossPercent: 5.0,
        trailingStopEnabled: true,
        trailingStopPercent: 2.5,
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_vix_shock',
      name: 'VIX Volatility Shock',
      description:
          'Hedging Strategy: Buys Volatility (UVXY, VXX) when RSI explodes > 60 and CCI > 100 with price crossing above Bollinger Bands.',
      config: TradeStrategyConfig(
        minSignalStrength: 70.0,
        requireAllIndicatorsGreen: false,
        symbolFilter: ['UVXY', 'VXX', 'VIXY'],
        startDate: DateTime.now().subtract(const Duration(days: 180)),
        endDate: DateTime.now(),
        interval: '1h',
        initialCapital: 100000.0,
        enabledIndicators: {
          'priceMovement': true,
          'momentum': true, // RSI
          'marketDirection': false,
          'volume': true,
          'macd': true,
          'bollingerBands': true, // Breakout above upper band
          'stochastic': false,
          'atr': false,
          'obv': false,
          'vwap': false,
          'adx': true,
          'williamsR': false,
          'ichimoku': false,
          'cci': true,
          'parabolicSar': false,
        },
        indicatorReasons: {
          'priceMovement': 'Captures the volatility shock.',
          'momentum': 'RSI surge signals panic buying of vol.',
          'volume': 'High volume confirms the fear spike.',
          'macd': 'MACD confirms the momentum shift.',
          'bollingerBands': 'Breakout above bands confirms the shock.',
          'atr': 'Adjusts sizing for extreme volatility.',
          'adx': 'ADX confirms the new volatility trend.',
          'cci': 'CCI identifies the initial impulse.',
        },
        customIndicators: [
          CustomIndicatorConfig(
            id: 'rsi_spike',
            name: 'RSI > 60',
            type: IndicatorType.RSI,
            parameters: {'period': 14},
            condition: SignalCondition.GreaterThan,
            threshold: 60.0,
            compareToPrice: false,
          ),
          CustomIndicatorConfig(
            id: 'cci_volatility_surge',
            name: 'CCI > 100',
            type: IndicatorType.CCI,
            parameters: {'period': 20},
            condition: SignalCondition.GreaterThan,
            threshold: 100.0,
            compareToPrice: false,
          ),
        ],
        riskPerTrade: 0.02,
        enableDynamicPositionSizing: true,
        takeProfitPercent: 10.0,
        stopLossPercent: 4.0,
        trailingStopEnabled: true,
        trailingStopPercent: 2.0,
        enableVolatilityFilters: true,
        minVolatility: 1.0, // High volatility regime
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_oversold_aristocrats',
      name: 'Oversold Aristocrats',
      description:
          'Value Buying: Picks up blue-chip anomalies. Buys when long-term trend is UP (SMA 200) but short-term is deeply oversold (RSI < 30, Stoch < 20).',
      config: TradeStrategyConfig(
        minSignalStrength: 60.0,
        requireAllIndicatorsGreen: false,
        symbolFilter: [
          'JNJ',
          'PG',
          'KO',
          'PEP',
          'COST',
          'MCD',
          'WMT',
          'MMM',
          'CAT'
        ],
        startDate: DateTime.now().subtract(const Duration(days: 1095)),
        endDate: DateTime.now(),
        interval: '1d',
        initialCapital: 50000.0,
        enabledIndicators: {
          'priceMovement': false, // Buying the dip
          'momentum': true, // RSI
          'marketDirection': true, // SMA 200 Bullish
          'volume': false,
          'macd': false,
          'bollingerBands': false,
          'stochastic': true, // Oversold
          'atr': false,
          'obv': false,
          'vwap': false,
          'adx': false,
          'williamsR': true, // Deep oversold
          'ichimoku': false,
          'cci': true,
          'parabolicSar': false,
        },
        indicatorReasons: {
          'momentum': 'RSI < 30 identifies value vs the trend.',
          'marketDirection': 'Approves entries only when primary trend is up.',
          'stochastic': 'Stochastic < 20 confirms the dip.',
          'williamsR': 'Oscillator confirms deep discount zones.',
          'cci': 'CCI < -100 filters for statistical anomalies.',
        },
        customIndicators: [
          CustomIndicatorConfig(
            id: 'rsi_deep_value',
            name: 'RSI < 30',
            type: IndicatorType.RSI,
            parameters: {'period': 14},
            condition: SignalCondition.LessThan,
            threshold: 30.0,
            compareToPrice: false,
          ),
          CustomIndicatorConfig(
            id: 'stoch_oversold',
            name: 'Stochastic < 20',
            type: IndicatorType.Stochastic,
            parameters: {'period': 14},
            condition: SignalCondition.LessThan,
            threshold: 20.0,
            compareToPrice: false,
          ),
        ],
        riskPerTrade: 0.02,
        enableDynamicPositionSizing: true,
        takeProfitPercent: 8.0,
        stopLossPercent: 4.0,
        trailingStopEnabled: false,
        enableDrawdownProtection: true,
        maxDrawdown: 0.10,
        rsiExitEnabled: true,
        rsiExitThreshold: 60.0,
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_forex_major_trend',
      name: 'Forex Major Trend',
      description:
          'Macro Style: Follows sustained trends in Major Currencies (UUP, FXE, FXY). Uses slow SMA crossovers and ADX > 25.',
      config: TradeStrategyConfig(
        minSignalStrength: 60.0,
        requireAllIndicatorsGreen: false,
        symbolFilter: ['UUP', 'FXE', 'FXY', 'FXB', 'FXF'],
        startDate: DateTime.now().subtract(const Duration(days: 730)),
        endDate: DateTime.now(),
        interval: '1d',
        initialCapital: 25000.0,
        enabledIndicators: {
          'priceMovement': true,
          'momentum': false,
          'marketDirection': true, // SMA 50/200 Cross
          'volume': false, // Forex volume often less reliable in ETFs
          'macd': true,
          'bollingerBands': false,
          'stochastic': false,
          'atr': false, // Volatility (Sizing)
          'obv': false,
          'vwap': false,
          'adx': false, // Trend strength > 25
          'williamsR': false,
          'ichimoku': true, // Cloud confirmation
          'cci': false,
          'parabolicSar': true, // Trailing stop
        },
        indicatorReasons: {
          'priceMovement': 'Price action aligns with the macro trend.',
          'marketDirection': 'SMA crossovers signal major regime changes.',
          'macd': 'MACD confirms the directional momentum.',
          'atr': 'Adjusts stops for currency volatility characteristics.',
          'adx': 'ADX confirms the trend is strong enough to trade.',
          'ichimoku': 'Cloud checkout validates the long-term trend.',
          'parabolicSar': 'Trailing stop for trend following.',
        },
        customIndicators: [
          CustomIndicatorConfig(
            id: 'adx_trend_forex',
            name: 'ADX > 25',
            type: IndicatorType.ADX,
            parameters: {'period': 14},
            condition: SignalCondition.GreaterThan,
            threshold: 25.0,
            compareToPrice: false,
          ),
        ],
        riskPerTrade: 0.02,
        enableDynamicPositionSizing: true,
        takeProfitPercent: 6.0, // Currencies move slower
        stopLossPercent: 2.0,
        trailingStopEnabled: true,
        trailingStopPercent: 1.5,
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_precious_metals_swing',
      name: 'Gold & Silver Swing',
      description:
          'Reflation Trade: Swings GLD/SLV using Stochastic cycles and ADX > 25 within an established RSI trend.',
      config: TradeStrategyConfig(
        minSignalStrength: 65.0,
        requireAllIndicatorsGreen: false,
        symbolFilter: ['GLD', 'SLV', 'GDX', 'GDXJ', 'SIL'],
        startDate: DateTime.now().subtract(const Duration(days: 365)),
        endDate: DateTime.now(),
        interval: '4h',
        initialCapital: 25000.0,
        enabledIndicators: {
          'priceMovement': true,
          'momentum': true,
          'marketDirection': false,
          'volume': true,
          'macd': false,
          'bollingerBands': true, // Bounce off bands
          'stochastic': true, // Cycle lows
          'atr': false,
          'obv': true, // Accumulation check
          'vwap': false,
          'adx': false, // Using custom indicator
          'williamsR': false,
          'ichimoku': false,
          'cci': true, // Momentum
          'parabolicSar': false,
        },
        indicatorReasons: {
          'priceMovement': 'Aligns with swing direction.',
          'momentum': 'RSI indicates healthy trend context.',
          'volume': 'Volume confirms the swing move.',
          'bollingerBands': 'Bands identify swing low/high zones.',
          'stochastic': 'Stochastic identifies cycle turning points.',
          'atr': 'Risk management.',
          'obv': 'OBV confirms physical buying interest.',
          'adx': 'ADX ensures the swing is part of a trend.',
          'cci': 'CCI confirms momentum behind the swing.',
        },
        customIndicators: [
          CustomIndicatorConfig(
            id: 'adx_trend_metals',
            name: 'ADX > 25',
            type: IndicatorType.ADX,
            parameters: {'period': 14},
            condition: SignalCondition.GreaterThan,
            threshold: 25.0,
            compareToPrice: false,
          ),
          CustomIndicatorConfig(
            id: 'cci_swing',
            name: 'CCI > 100',
            type: IndicatorType.CCI,
            parameters: {'period': 20},
            condition: SignalCondition.GreaterThan,
            threshold: 100.0,
            compareToPrice: false,
          ),
        ],
        riskPerTrade: 0.02,
        enableDynamicPositionSizing: true,
        takeProfitPercent: 12.0,
        stopLossPercent: 4.0,
        trailingStopEnabled: true,
        trailingStopPercent: 2.5,
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_vwap_rejection_short',
      name: 'VWAP Rejection Short',
      description:
          'Intraday Short: Enters when price rallies to VWAP but fails to break through, resuming the downtrend (Stochastic > 80).',
      config: TradeStrategyConfig(
        minSignalStrength: 60.0,
        requireAllIndicatorsGreen: false,
        startDate: DateTime.now().subtract(const Duration(days: 60)),
        endDate: DateTime.now(),
        interval: '15m',
        initialCapital: 25000.0,
        enabledIndicators: {
          'priceMovement': false, // Shorting
          'momentum': true, // RSI turning down
          'marketDirection': false,
          'volume': true, // Volume on rejection
          'macd': false,
          'bollingerBands': false,
          'stochastic': true, // Overbought crossing down
          'atr': false,
          'obv': false,
          'vwap': true, // Key resistance level
          'adx': false,
          'williamsR': false,
          'ichimoku': false,
          'cci': false,
          'parabolicSar': true, // Tight stop
        },
        indicatorReasons: {
          'momentum': 'RSI reversal signals downside resumption.',
          'volume': 'Volume spike on rejection confirms resistance.',
          'stochastic': 'Overbought conditions suggest immediate downside.',
          'atr': 'Determines tight stop distance above VWAP.',
          'vwap': 'Acts as the primary resistance level to trade against.',
          'parabolicSar': 'Trails price closely to protect the short.',
        },
        customIndicators: [
          CustomIndicatorConfig(
            id: 'price_below_vwap',
            name: 'Price < VWAP',
            type: IndicatorType.VWAP,
            parameters: {},
            condition: SignalCondition.LessThan,
            compareToPrice: true,
          ),
          CustomIndicatorConfig(
            id: 'stoch_overbought',
            name: 'Stochastic > 80',
            type: IndicatorType.Stochastic,
            parameters: {'period': 14},
            condition: SignalCondition.GreaterThan,
            threshold: 80.0,
            compareToPrice: false,
          ),
        ],
        riskPerTrade: 0.015,
        enableDynamicPositionSizing: true,
        takeProfitPercent: 4.0,
        stopLossPercent: 1.5, // Stop just above VWAP
        trailingStopEnabled: true,
        trailingStopPercent: 1.0,
        timeBasedExitEnabled: true,
        timeBasedExitMinutes: 120,
        marketCloseExitEnabled: true,
        marketCloseExitMinutes: 10,
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_adx_trend_jumper',
      name: 'ADX Trend Jumper',
      description:
          'Trend Strength Strategy: Only enters trades when the trend is mathematically strong (ADX > 25) to avoid choppy "whipsaw" markets.',
      config: TradeStrategyConfig(
        minSignalStrength: 60.0,
        requireAllIndicatorsGreen: false,
        startDate: DateTime.now().subtract(const Duration(days: 365)),
        endDate: DateTime.now(),
        interval: '1d',
        initialCapital: 25000.0,
        enabledIndicators: {
          'priceMovement': true,
          'momentum': false,
          'marketDirection': true, // SMA Direction
          'volume': false,
          'macd': true,
          'bollingerBands': false,
          'stochastic': false,
          'atr': false,
          'obv': false,
          'vwap': false,
          'adx': true, // Primary filter
          'williamsR': false,
          'ichimoku': false,
          'cci': false,
          'parabolicSar': true,
        },
        indicatorReasons: {
          'priceMovement': 'Aligns with the strong trend.',
          'marketDirection': 'SMA direction ensures broad trend agreement.',
          'macd': 'MACD confirms the momentum behind the trend.',
          'atr': 'Adjusts stops for trend volatility.',
          'adx': 'ADX > 25 is the gatekeeper against choppy markets.',
          'parabolicSar': 'Trails the strong trend.',
        },
        customIndicators: [
          CustomIndicatorConfig(
            id: 'adx_strong',
            name: 'ADX > 25',
            type: IndicatorType.ADX,
            parameters: {'period': 14},
            condition: SignalCondition.GreaterThan,
            threshold: 25.0,
            compareToPrice: false,
          ),
        ],
        riskPerTrade: 0.02,
        enableDynamicPositionSizing: true,
        takeProfitPercent: 15.0,
        stopLossPercent: 5.0,
        trailingStopEnabled: true,
        trailingStopPercent: 3.0,
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_cci_turbo_breakout',
      name: 'CCI Turbo Breakout',
      description:
          'Momentum Burst: Captures explosive moves when CCI surges above +100. Best for fast-moving stocks.',
      config: TradeStrategyConfig(
        minSignalStrength: 70.0,
        requireAllIndicatorsGreen: false,
        startDate: DateTime.now().subtract(const Duration(days: 90)),
        endDate: DateTime.now(),
        interval: '1h',
        initialCapital: 25000.0,
        enabledIndicators: {
          'priceMovement': true,
          'momentum': false,
          'marketDirection': false,
          'volume': true,
          'macd': false,
          'bollingerBands': true, // Band expansion often accompanies CCI burst
          'stochastic': false,
          'atr': false,
          'obv': false,
          'vwap': false,
          'adx': true, // Trend acceleration
          'williamsR': false,
          'ichimoku': false,
          'cci': true, // Driver
          'parabolicSar': false,
        },
        indicatorReasons: {
          'priceMovement': 'Breakout price action.',
          'volume': 'High volume validates the turbo move.',
          'bollingerBands':
              'Volatility expansion typically accompanies CCI bursts.',
          'atr': 'Manages increased volatility risk.',
          'adx': 'ADX confirms trend acceleration.',
          'cci': 'CCI > 100 serves as the ignition signal.',
        },
        customIndicators: [
          CustomIndicatorConfig(
            id: 'cci_breakout',
            name: 'CCI > 100',
            type: IndicatorType.CCI,
            parameters: {'period': 20},
            condition: SignalCondition.GreaterThan,
            threshold: 100.0,
            compareToPrice: false,
          ),
          CustomIndicatorConfig(
            id: 'adx_acceleration',
            name: 'ADX > 25',
            type: IndicatorType.ADX,
            parameters: {'period': 14},
            condition: SignalCondition.GreaterThan,
            threshold: 25.0,
            compareToPrice: false,
          ),
        ],
        riskPerTrade: 0.02,
        enableDynamicPositionSizing: true,
        takeProfitPercent: 8.0,
        stopLossPercent: 3.0,
        trailingStopEnabled: true,
        trailingStopPercent: 2.0,
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_mfi_smart_money_dip',
      name: 'MFI Smart Money Dip',
      description:
          'Volume-Weighted RSI: Buys dips when Money Flow Index (MFI) is oversold (< 20) within a long-term uptrend. Detects "smart money" accumulation.',
      config: TradeStrategyConfig(
        minSignalStrength: 60.0,
        requireAllIndicatorsGreen: false,
        startDate: DateTime.now().subtract(const Duration(days: 730)),
        endDate: DateTime.now(),
        interval: '1d',
        initialCapital: 25000.0,
        enabledIndicators: {
          'priceMovement': false, // Buying dip
          'momentum': false,
          'marketDirection': true, // SMA 200 Uptrend
          'volume': true, // Essential for MFI
          'macd': false,
          'bollingerBands': false,
          'stochastic': false,
          'atr': false,
          'obv': true, // Additional volume confirm
          'vwap': false,
          'adx': false,
          'williamsR': false,
          'ichimoku': false,
          'cci': false,
          'parabolicSar': false,
        },
        indicatorReasons: {
          'marketDirection': 'Confirms long-term uptrend context.',
          'volume': 'Volume analysis critical for MFI calculation.',
          'atr': 'Risk adjustment for dip volatility.',
          'obv': 'OBV divergence confirms smart money accumulation.',
        },
        customIndicators: [
          CustomIndicatorConfig(
            id: 'mfi_oversold',
            name: 'MFI < 20',
            type: IndicatorType.MFI,
            parameters: {'period': 14},
            condition: SignalCondition.LessThan,
            threshold: 20.0,
            compareToPrice: false,
          ),
        ],
        riskPerTrade: 0.02,
        enableDynamicPositionSizing: true,
        takeProfitPercent: 8.0,
        stopLossPercent: 4.0,
        trailingStopEnabled: false,
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_roc_velocity_surge',
      name: 'ROC Velocity Surge',
      description:
          'Pure Momentum: Enters when Price Rate of Change (ROC) exceeds 5% in 10 bars, indicating a powerful volatility expansion.',
      config: TradeStrategyConfig(
        minSignalStrength: 70.0,
        requireAllIndicatorsGreen: false,
        startDate: DateTime.now().subtract(const Duration(days: 90)),
        endDate: DateTime.now(),
        interval: '1d',
        initialCapital: 25000.0,
        enabledIndicators: {
          'priceMovement': true,
          'momentum': true,
          'marketDirection': false,
          'volume': true,
          'macd': false,
          'bollingerBands': true, // Breakout
          'stochastic': false,
          'atr': false,
          'obv': false,
          'vwap': false,
          'adx': false, // Trend strength
          'williamsR': false,
          'ichimoku': false,
          'cci': false,
          'parabolicSar': true, // Trailing
        },
        indicatorReasons: {
          'priceMovement': 'Captures the velocity surge.',
          'momentum': 'ROC acceleration confirms impulse.',
          'volume': 'High participation validates the move.',
          'bollingerBands': 'Breakout signals volatility transition.',
          'atr': 'Manages increased velocity risk.',
          'adx': 'ADX confirms trend is establishing.',
          'parabolicSar': 'Trails fast moving prices.',
        },
        customIndicators: [
          CustomIndicatorConfig(
            id: 'roc_surge',
            name: 'ROC > 5%',
            type: IndicatorType.ROC,
            parameters: {'period': 10},
            condition: SignalCondition.GreaterThan,
            threshold: 5.0,
            compareToPrice: false,
          ),
          CustomIndicatorConfig(
            id: 'adx_trend_start',
            name: 'ADX > 20',
            type: IndicatorType.ADX,
            parameters: {'period': 14},
            condition: SignalCondition.GreaterThan,
            threshold: 20.0,
            compareToPrice: false,
          ),
        ],
        riskPerTrade: 0.02,
        enableDynamicPositionSizing: true,
        takeProfitPercent: 12.0,
        stopLossPercent: 4.0,
        trailingStopEnabled: true,
        trailingStopPercent: 3.0,
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_bbw_squeeze_play',
      name: 'Bollinger Band Squeeze',
      description:
          'Volatility Compression: Identifies extremely tight Bollinger Bands (Low Band Width, ADX < 20) anticipating a violent expansion.',
      config: TradeStrategyConfig(
        minSignalStrength: 50.0,
        requireAllIndicatorsGreen: false,
        startDate: DateTime.now().subtract(const Duration(days: 180)),
        endDate: DateTime.now(),
        interval: '1d',
        initialCapital: 25000.0,
        enabledIndicators: {
          'priceMovement': true,
          'momentum': false,
          'marketDirection': false,
          'volume': true, // Volume often dries up in squeeze
          'macd': false,
          'bollingerBands': true, // The primary context
          'stochastic': false,
          'atr': true, // Low ATR
          'obv': false,
          'vwap': false,
          'adx': false, // Low ADX likely
          'williamsR': false,
          'ichimoku': false,
          'cci': false,
          'parabolicSar': false,
        },
        indicatorReasons: {
          'priceMovement': 'Monitors for the eventual expansion.',
          'volume': 'Volume drying up confirms the squeeze.',
          'bollingerBands': 'Extremely narrow bands define the strategy.',
          'atr': 'Low ATR confirms potential energy build-up.',
          'adx': 'Low ADX signals non-trending consolidation.',
        },
        customIndicators: [
          CustomIndicatorConfig(
            id: 'bb_width_low',
            name: 'BB Width < 0.10',
            type: IndicatorType.BBW,
            parameters: {'period': 20, 'stdDev': 2},
            condition: SignalCondition.LessThan,
            threshold: 0.10, // 10% width is tight for many stocks
            compareToPrice: false,
          ),
          CustomIndicatorConfig(
            id: 'adx_consolidation',
            name: 'ADX < 20',
            type: IndicatorType.ADX,
            parameters: {'period': 14},
            condition: SignalCondition.LessThan,
            threshold: 20.0,
            compareToPrice: false,
          ),
        ],
        riskPerTrade: 0.015,
        enableDynamicPositionSizing: true,
        takeProfitPercent: 10.0,
        stopLossPercent: 4.0,
        trailingStopEnabled: true,
        trailingStopPercent: 2.0,
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_cmf_accumulation',
      name: 'Chaikin Money Flow',
      description:
          'Institutional Accumulation: Buys when Money Flow (CMF) is positive and rising while price is consolidating. Signals buying pressure.',
      config: TradeStrategyConfig(
        minSignalStrength: 60.0,
        requireAllIndicatorsGreen: false,
        startDate: DateTime.now().subtract(const Duration(days: 365)),
        endDate: DateTime.now(),
        interval: '1d',
        initialCapital: 25000.0,
        enabledIndicators: {
          'priceMovement': true,
          'momentum': false,
          'marketDirection': true, // Flat to Up
          'volume': true,
          'macd': false,
          'bollingerBands': false,
          'stochastic': false,
          'atr': false,
          'obv': true, // Correlated
          'vwap': false,
          'adx': false,
          'williamsR': false,
          'ichimoku': false,
          'cci': false,
          'parabolicSar': true,
        },
        indicatorReasons: {
          'priceMovement': 'Aligns with accumulation breakout.',
          'marketDirection':
              'Confirming uptrend or neutral (accumulation) bias.',
          'volume': 'CMF relies heavily on volume/price relationship.',
          'obv': 'Confirms CMF signals with cumulative volume.',
          'parabolicSar': 'Trailing stop protects the new trend.',
        },
        customIndicators: [
          CustomIndicatorConfig(
            id: 'cmf_positive',
            name: 'CMF > 0.05',
            type: IndicatorType.CMF,
            parameters: {'period': 20},
            condition: SignalCondition.GreaterThan,
            threshold: 0.05,
            compareToPrice: false,
          ),
        ],
        riskPerTrade: 0.02,
        enableDynamicPositionSizing: true,
        takeProfitPercent: 12.0,
        stopLossPercent: 5.0,
        trailingStopEnabled: true,
        trailingStopPercent: 3.0,
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_triple_screen_hybrid',
      name: 'Triple Screen Hybrid',
      description:
          'Alexander Elder inspired structure: Trends on daily (EMA 50), Pullbacks on Oscillators (Stochastic < 25), Trigger on Momentum.',
      config: TradeStrategyConfig(
        minSignalStrength: 70.0,
        requireAllIndicatorsGreen: false,
        startDate: DateTime.now().subtract(const Duration(days: 365)),
        endDate: DateTime.now(),
        interval: '1d',
        initialCapital: 25000.0,
        enabledIndicators: {
          'priceMovement': true,
          'momentum': false,
          'marketDirection': true, // EMA 50 Trend
          'volume': false,
          'macd': true, // Trend confirm
          'bollingerBands': false,
          'stochastic': true, // Pullback
          'atr': false, // Stop placement (Sizing)
          'obv': false,
          'vwap': false,
          'adx': true, // Trend strength
          'williamsR': true, // Trigger
          'ichimoku': false,
          'cci': false,
          'parabolicSar': false,
        },
        indicatorReasons: {
          'priceMovement': 'Screen 3: Execution on momentum.',
          'marketDirection': 'Screen 1: Long-term trend direction.',
          'macd': 'Screen 1: Momentum confirms trend.',
          'stochastic': 'Screen 2: Identifies pullback areas.',
          'atr': 'Risk management for stop placement.',
          'adx': 'Ensures sufficient trend strength.',
          'williamsR': 'Screen 3: Precision trigger.',
        },
        customIndicators: [
          CustomIndicatorConfig(
            id: 'ema_trend_filter',
            name: 'Price > EMA 50',
            type: IndicatorType.EMA,
            parameters: {'period': 50},
            condition: SignalCondition.GreaterThan,
            compareToPrice: true,
          ),
          CustomIndicatorConfig(
            id: 'stoch_pullback',
            name: 'Stoch < 25',
            type: IndicatorType.Stochastic,
            parameters: {'kPeriod': 14, 'dPeriod': 3},
            condition: SignalCondition.LessThan,
            threshold: 25.0,
            compareToPrice: false,
          ),
        ],
        riskPerTrade: 0.02,
        enableDynamicPositionSizing: true,
        takeProfitPercent: 15.0,
        stopLossPercent: 5.0,
        trailingStopEnabled: true,
        trailingStopPercent: 3.0,
      ),
      createdAt: DateTime.now(),
    ),
  ];
}
