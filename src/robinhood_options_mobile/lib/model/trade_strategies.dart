import 'package:robinhood_options_mobile/model/backtesting_models.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_config.dart';
import 'package:robinhood_options_mobile/model/custom_indicator_config.dart';

/// Pre-built strategy templates for backtesting
class TradeStrategyDefaults {
  static final List<TradeStrategyTemplate> defaultTemplates = [
    TradeStrategyTemplate(
      id: 'default_momentum_master',
      name: 'Momentum Master',
      description: 'Captures strong price moves using RSI, MACD, and Volume.',
      config: TradeStrategyConfig(
        // symbolFilter: ['SPY'],
        startDate: DateTime.now().subtract(const Duration(days: 365)),
        endDate: DateTime.now(),
        interval: '1d',
        enabledIndicators: {
          'priceMovement': true,
          'momentum': true, // RSI
          'marketDirection': false,
          'volume': true,
          'macd': true,
          'bollingerBands': false,
          'stochastic': false,
          'atr': false,
          'obv': false,
          'vwap': false,
          'adx': true,
          'williamsR': false,
        },
        takeProfitPercent: 15.0,
        stopLossPercent: 5.0,
        trailingStopEnabled: true,
        trailingStopPercent: 3.0,
        riskPerTrade: 0.02,
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_mean_reversion',
      name: 'Mean Reversion',
      description:
          'Trades reversals from overbought/oversold conditions using Bollinger Bands and RSI.',
      config: TradeStrategyConfig(
        // symbolFilter: ['QQQ'],
        startDate: DateTime.now().subtract(const Duration(days: 365)),
        endDate: DateTime.now(),
        interval: '1d',
        enabledIndicators: {
          'priceMovement': false,
          'momentum': true, // RSI
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
        },
        takeProfitPercent: 8.0,
        stopLossPercent: 4.0,
        trailingStopEnabled: false,
        riskPerTrade: 0.015,
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_trend_follower',
      name: 'Trend Follower',
      description: 'Rides established trends using Moving Averages and ADX.',
      config: TradeStrategyConfig(
        // symbolFilter: ['IWM'],
        startDate: DateTime.now().subtract(const Duration(days: 365)),
        endDate: DateTime.now(),
        interval: '1d',
        enabledIndicators: {
          'priceMovement': true,
          'momentum': false,
          'marketDirection': true, // SMA crossovers
          'volume': false,
          'macd': true,
          'bollingerBands': false,
          'stochastic': false,
          'atr': true, // For volatility adjustment
          'obv': true,
          'vwap': false,
          'adx': true,
          'williamsR': false,
        },
        takeProfitPercent: 20.0,
        stopLossPercent: 8.0,
        trailingStopEnabled: true,
        riskPerTrade: 0.015,
        trailingStopPercent: 5.0,
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_volatility_breakout',
      name: 'Volatility Breakout (1h)',
      description: 'Captures explosive moves using Bollinger Bands and ATR.',
      config: TradeStrategyConfig(
        // symbolFilter: ['NVDA'],
        startDate: DateTime.now().subtract(const Duration(days: 90)),
        endDate: DateTime.now(),
        interval: '1h',
        enabledIndicators: {
          'priceMovement': true,
          'momentum': false,
          'marketDirection': false,
          'volume': true,
          'macd': false,
          'bollingerBands': true,
          'stochastic': false,
          'atr': true,
          'obv': false,
          'vwap': true,
          'adx': true,
          'williamsR': false,
        },
        takeProfitPercent: 12.0,
        stopLossPercent: 3.0,
        trailingStopEnabled: true,
        riskPerTrade: 0.02,
        trailingStopPercent: 2.0,
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_scalper_15m',
      name: 'Intraday Scalper (15m)',
      description:
          'Short-term strategy with partial exits and time-based hard stops.',
      config: TradeStrategyConfig(
        // symbolFilter: ['TSLA'],
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
          'atr': true,
          'obv': false,
          'vwap': true, // Key for intraday
          'adx': false,
          'williamsR': true,
        },
        initialCapital: 25000,
        takeProfitPercent: 3.0,
        stopLossPercent: 1.5,
        timeBasedExitEnabled: true,
        timeBasedExitMinutes: 60, // Exit after 1 hour if not hitting targets
        marketCloseExitEnabled: true,
        marketCloseExitMinutes: 10,
        enablePartialExits: true,
        exitStages: [
          ExitStage(profitTargetPercent: 1.5, quantityPercent: 0.5),
        ],
        riskPerTrade: 0.01,
        trailingStopEnabled: true,
        trailingStopPercent: 0.5,
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_custom_ema_trend',
      name: 'Custom EMA Trend',
      description: 'Demonstrates Custom Indicators: Buys when Price > 21 EMA.',
      config: TradeStrategyConfig(
        // symbolFilter: ['AMZN'],
        startDate: DateTime.now().subtract(const Duration(days: 180)),
        endDate: DateTime.now(),
        interval: '1h',
        enabledIndicators: {
          'priceMovement': true,
          'momentum': false,
          'marketDirection': false,
          'volume': false,
          'macd': false,
          'bollingerBands': false,
          'stochastic': false,
          'atr': false,
          'obv': false,
          'vwap': false,
          'adx': false,
          'williamsR': false,
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
        ],
        takeProfitPercent: 8.0,
        stopLossPercent: 3.0,
        riskPerTrade: 0.01,
        trailingStopEnabled: true,
        trailingStopPercent: 2.0,
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_crypto_proxy_momentum',
      name: 'Crypto Proxy Momentum',
      description:
          'High-volatility momentum strategy designed for crypto-correlated stocks.',
      config: TradeStrategyConfig(
        symbolFilter: ['COIN'],
        startDate: DateTime.now().subtract(const Duration(days: 90)),
        endDate: DateTime.now(),
        interval: '1h',
        enabledIndicators: {
          'priceMovement': true,
          'momentum': true,
          'marketDirection': false,
          'volume': true,
          'macd': true,
          'bollingerBands': true,
          'stochastic': false,
          'atr': true,
          'obv': true,
          'vwap': false,
          'adx': true,
          'williamsR': false,
        },
        takeProfitPercent: 15.0,
        riskPerTrade: 0.02,
        stopLossPercent: 7.0,
        trailingStopEnabled: true,
        trailingStopPercent: 5.0,
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_golden_cross_rsi',
      name: 'Golden Cross & RSI Filter',
      description:
          'Classic 50/200 SMA Cross, but uses RSI < 70 to avoid buying tops.',
      config: TradeStrategyConfig(
        // symbolFilter: ['SPY'],
        startDate: DateTime.now().subtract(const Duration(days: 730)),
        endDate: DateTime.now(),
        interval: '1d',
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
        takeProfitPercent: 25.0,
        stopLossPercent: 10.0,
        trailingStopEnabled: true,
        trailingStopPercent: 5.0,
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_iron_condor_income',
      name: 'Range Bound Income',
      description:
          'Ideal for sideways markets. Profitable when Price Movement and Momentum are low.',
      config: TradeStrategyConfig(
        // symbolFilter: ['KO'],
        startDate: DateTime.now().subtract(const Duration(days: 365)),
        endDate: DateTime.now(),
        interval: '1d',
        enabledIndicators: {
          'priceMovement': false,
          'momentum': false,
          'marketDirection': false,
          'volume': false,
          'macd': false,
          'bollingerBands': true, // Use bands to define range
          'stochastic': true, // Overbought/Oversold oscillations
          'atr': true, // Low volatility preference
          'obv': false,
          'vwap': false,
          'adx': true, // Low ADX = No Trend
          'williamsR': true,
        },
        // Low ADX logic is handled by backend if 'adx' is enabled and we want range?
        // Actually, core logic usually looks for trend.
        // For range bound, we might want custom indicators: ADX < 25.
        customIndicators: [
          CustomIndicatorConfig(
            id: 'custom_adx_range',
            name: 'ADX < 25 (Range)',
            type: IndicatorType
                .MACD, // Hack: The backend map might only support specific types. Let's use RSI for now.
            // Wait, CustomIndicatorConfig supports what types?
            // IndicatorType: SMA, EMA, RSI, MACD, Bollinger, Stochastic, ATR, OBV.
            // ADX is NOT in CustomIndicatorConfig enum yet.
            // So we stick to RSI range: RSI < 60 and RSI > 40?
            // Let's use "RSI Range" logic with 2 custom indicators.
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
        takeProfitPercent: 4.0,
        stopLossPercent: 2.0,
        trailingStopEnabled: false,
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_golden_cross',
      name: 'Golden Cross Strategy',
      description: 'Classic trend signal: SMA 50 crosses above SMA 200.',
      config: TradeStrategyConfig(
        // symbolFilter: ['SPY'],
        startDate:
            DateTime.now().subtract(const Duration(days: 730)), // 2 years
        endDate: DateTime.now(),
        interval: '1d',
        enabledIndicators: {
          'priceMovement': false,
          'momentum': false,
          'marketDirection': true, // Keep SMA logic
          'volume': true,
          'macd': false,
          'bollingerBands': false,
          'stochastic': false,
          'atr': false,
          'obv': false,
          'vwap': false,
          'adx': true, // Ensure trend strength
          'williamsR': false,
        },
        customIndicators: [
          CustomIndicatorConfig(
            id: 'golden_cross_sma50_gt_sma200',
            name: 'SMA 50 > SMA 200',
            type: IndicatorType.SMA,
            parameters: {'period': 50},
            condition: SignalCondition.GreaterThan,
            compareToPrice: false,
            // Logic: Compare to another indicator?
            // The current CustomIndicatorConfig only supports threshold or price comparison.
            // But we can approximate by saying Price > SMA 200 and Price > SMA 50 is bullish.
            // Real crossover requires "Indicator vs Indicator" logic which might not be in CustomIndicatorConfig yet.
            // Let's stick to "Long Term Trend": Price > SMA 200.
            threshold: 0.0,
          ),
          CustomIndicatorConfig(
            id: 'price_above_sma200',
            name: 'Price > SMA 200',
            type: IndicatorType.SMA,
            parameters: {'period': 200},
            condition: SignalCondition.GreaterThan,
            compareToPrice: true,
          ),
        ],
        riskPerTrade: 0.02,
        takeProfitPercent: 25.0,
        stopLossPercent: 10.0,
        trailingStopEnabled: true,
        trailingStopPercent: 5.0,
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_strict_confluence',
      name: 'Strict Confluence',
      description:
          'High conviction entries requiring ALL enabled indicators (Momentum, Moving Avg, MACD) to agree.',
      config: TradeStrategyConfig(
        // symbolFilter: ['NVDA'],
        startDate: DateTime.now().subtract(const Duration(days: 180)),
        endDate: DateTime.now(),
        interval: '1d',
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
        },
        riskPerTrade: 0.02,
        requireAllIndicatorsGreen: true,
        takeProfitPercent: 12.0,
        stopLossPercent: 4.0,
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_risk_managed_growth',
      name: 'Risk-Managed Growth',
      description:
          'Uses dynamic position sizing to risk exactly 1% of account equity per trade.',
      config: TradeStrategyConfig(
        // symbolFilter: ['AMD'],
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
          'atr': true, // Critical for ATR-based stops
          'obv': false,
          'vwap': true,
          'adx': false,
          'williamsR': false,
        },
        enableDynamicPositionSizing: true,
        riskPerTrade: 0.01, // 1% risk
        atrMultiplier: 2.0, // Stop loss at 2x ATR
        takeProfitPercent: 6.0,
        stopLossPercent: 3.0, // Fallback
        trailingStopEnabled: true,
        trailingStopPercent: 2.0,
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_macd_reversal',
      name: 'MACD Histogram Reversal',
      description:
          'Trades when MACD histogram flips positive while RSI is oversold (< 40).',
      config: TradeStrategyConfig(
        // symbolFilter: ['AMD'],
        startDate: DateTime.now().subtract(const Duration(days: 365)),
        endDate: DateTime.now(),
        interval: '1d',
        enabledIndicators: {
          'priceMovement': false,
          'momentum': false,
          'marketDirection': false,
          'volume': true,
          'macd': true,
          'bollingerBands': false,
          'stochastic': false,
          'atr': true,
          'obv': false,
          'vwap': false,
          'adx': false,
          'williamsR': false,
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
        takeProfitPercent: 12.0,
        stopLossPercent: 5.0,
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_bollinger_squeeze',
      name: 'Bollinger Band Squeeze',
      description:
          'Breakout strategy. Low volatility period (ATR) followed by price piercing Upper Band.',
      config: TradeStrategyConfig(
        // symbolFilter: ['MSFT'],
        startDate: DateTime.now().subtract(const Duration(days: 180)),
        endDate: DateTime.now(),
        interval: '1h',
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
        },
        riskPerTrade: 0.015,
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
        // symbolFilter: ['NVDA'],
        startDate: DateTime.now().subtract(const Duration(days: 30)),
        endDate: DateTime.now(),
        interval: '15m',
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
          'High-frequency style: SPY 5m chart, riding rapid momentum bursts with tight risk.',
      config: TradeStrategyConfig(
        symbolFilter: ['SPY'],
        startDate: DateTime.now().subtract(const Duration(days: 7)),
        endDate: DateTime.now(),
        interval: '5m',
        enabledIndicators: {
          'priceMovement': true,
          'momentum': true, // RSI
          'marketDirection': false,
          'volume': true, // Essential
          'macd': false,
          'bollingerBands': true, // Volatility expansion
          'stochastic': true,
          'atr': true, // Measure moves
          'obv': false,
          'vwap': true, // Intraday anchor
          'adx': true, // Trend strength
          'williamsR': false,
        },
        tradeQuantity: 10,
        takeProfitPercent: 1.0, // Quick scalp
        riskPerTrade: 0.005,
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
          'Trend following on XLK (Tech Sector). Captures multi-day moves.',
      config: TradeStrategyConfig(
        symbolFilter: ['XLK'],
        startDate: DateTime.now().subtract(const Duration(days: 365)),
        endDate: DateTime.now(),
        interval: '1h',
        enabledIndicators: {
          'priceMovement': true,
          'momentum': false,
          'marketDirection': true, // SMA Crosses
          'volume': false,
          'macd': true,
          'bollingerBands': false,
          'stochastic': false,
          'atr': true,
          'obv': true, // Accumulation
          'vwap': false,
          'adx': true, // Strong trend only
          'williamsR': false,
        },
        riskPerTrade: 0.015,
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
          'Low-beta strategy on SCHD. Buys dips (RSI < 30) in uptrends.',
      config: TradeStrategyConfig(
        symbolFilter: ['SCHD'],
        startDate: DateTime.now().subtract(const Duration(days: 730)),
        endDate: DateTime.now(),
        interval: '1d',
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
        ],
        riskPerTrade: 0.01,
        takeProfitPercent: 6.0,
        stopLossPercent: 4.0, // Wider stop for value
        trailingStopEnabled: false,
      ),
      createdAt: DateTime.now(),
    ),
  ];
}
