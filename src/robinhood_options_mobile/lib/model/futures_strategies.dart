import 'package:robinhood_options_mobile/model/futures_strategy_config.dart';

class FuturesStrategyTemplate {
  final String id;
  final String name;
  final String description;
  final FuturesStrategyConfig config;
  final DateTime createdAt;
  final DateTime? lastUsedAt;

  FuturesStrategyTemplate({
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

  factory FuturesStrategyTemplate.fromJson(Map<String, dynamic> json) {
    return FuturesStrategyTemplate(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      config: FuturesStrategyConfig.fromJson(
        Map<String, dynamic>.from(json['config'] as Map),
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastUsedAt: json['lastUsedAt'] != null
          ? DateTime.parse(json['lastUsedAt'] as String)
          : null,
    );
  }
}

class FuturesStrategyDefaults {
  static List<FuturesStrategyTemplate> defaultTemplates = [
    FuturesStrategyTemplate(
      id: 'futures_trend_following',
      name: 'Trend Following',
      description:
          'Follows sustained directional moves using MACD and trend strength.',
      config: FuturesStrategyConfig(
        interval: '1h',
        minSignalStrength: 70.0,
        enabledIndicators: {
          'priceMovement': true,
          'marketDirection': true,
          'macd': true,
          'adx': true,
          'atr': true,
        },
        indicatorReasons: {
          'macd': 'Trend momentum confirmation.',
          'adx': 'Avoid weak trends.',
        },
        enableDynamicPositionSizing: true,
        riskPerTrade: 0.01,
      ),
      createdAt: DateTime.now(),
    ),
    FuturesStrategyTemplate(
      id: 'futures_breakout',
      name: 'Breakout',
      description:
          'Targets volatility breakouts with volume confirmation and ATR.',
      config: FuturesStrategyConfig(
        interval: '30m',
        minSignalStrength: 65.0,
        enabledIndicators: {
          'priceMovement': true,
          'volume': true,
          'bollingerBands': true,
          'atr': true,
        },
        indicatorReasons: {
          'priceMovement': 'Detects breakout patterns.',
          'volume': 'Confirms participation.',
        },
        maxContracts: 2,
      ),
      createdAt: DateTime.now(),
    ),
    FuturesStrategyTemplate(
      id: 'futures_mean_reversion',
      name: 'Mean Reversion',
      description: 'Looks for oversold/overbought snaps back to the mean.',
      config: FuturesStrategyConfig(
        interval: '1h',
        minSignalStrength: 60.0,
        enabledIndicators: {
          'bollingerBands': true,
          'momentum': true,
        },
        indicatorReasons: {
          'bollingerBands': 'Mean reversion bands.',
          'momentum': 'RSI oversold/overbought confirmation.',
        },
        maxContracts: 2,
      ),
      createdAt: DateTime.now(),
    ),
    FuturesStrategyTemplate(
      id: 'futures_momentum_reversal',
      name: 'Momentum Reversal',
      description: 'Catches momentum fade using RSI and ROC shifts.',
      config: FuturesStrategyConfig(
        interval: '30m',
        minSignalStrength: 68.0,
        enabledIndicators: {
          'momentum': true,
          'roc': true,
          'macd': true,
        },
        indicatorReasons: {
          'momentum': 'RSI reversal signal.',
          'roc': 'Rate-of-change slowdown.',
        },
      ),
      createdAt: DateTime.now(),
    ),
    FuturesStrategyTemplate(
      id: 'futures_time_of_day',
      name: 'Seasonality / Time-of-Day',
      description:
          'Limits trades to a defined window to capture session patterns.',
      config: FuturesStrategyConfig(
        interval: '15m',
        minSignalStrength: 62.0,
        sessionRules: const FuturesSessionRules(
          enforceTradingWindow: true,
          tradingWindowStart: '09:30',
          tradingWindowEnd: '11:30',
          allowOvernight: false,
          allowWeekend: false,
        ),
        enabledIndicators: {
          'priceMovement': true,
          'volume': true,
          'vwap': true,
        },
      ),
      createdAt: DateTime.now(),
    ),
    FuturesStrategyTemplate(
      id: 'futures_conservative_multi',
      name: 'Conservative Multi-Confirm',
      description:
          'High confidence trades requiring multi-interval confirmation across all indicators.',
      config: FuturesStrategyConfig(
        interval: '1h',
        minSignalStrength: 85.0,
        requireAllIndicatorsGreen: true,
        multiIntervalAnalysis: true,
        enabledIndicators: {
          'priceMovement': true,
          'marketDirection': true,
          'momentum': true,
          'macd': true,
          'atr': true,
          'vwap': true,
          'adx': true,
        },
        indicatorReasons: {
          'macd': 'Strong confirmation required.',
          'adx': 'High trend threshold.',
        },
        maxContracts: 1,
        stopLossPct: 1.5,
        takeProfitPct: 5.0,
      ),
      createdAt: DateTime.now(),
    ),
  ];
}
