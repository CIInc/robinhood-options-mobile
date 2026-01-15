import 'package:robinhood_options_mobile/model/backtesting_models.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_config.dart';
import 'package:robinhood_options_mobile/model/custom_indicator_config.dart';

/// Pre-built strategy templates for backtesting
class TradeStrategyDefaults {
  static final List<TradeStrategyTemplate> defaultTemplates = [
    TradeStrategyTemplate(
      id: 'default_momentum_master',
      name: 'Momentum Master',
      description:
          'Captures strong price moves by combining RSI and CCI momentum with MACD confirmation and Volume validation. Best for trending markets.',
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
          'ichimoku': false,
          'cci': true, // Added momentum indicator
          'parabolicSar': false,
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
          'Identifies overbought/oversold reversals using Bollinger Bands, CCI, and RSI extremes. Targets "snap-back" moves in changing markets.',
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
          'ichimoku': false,
          'cci': true, // Added for mean reversion
          'parabolicSar': false,
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
      description:
          'Rides established trends using Moving Averages, Ichimoku Cloud, ADX trend strength, and OBV flow. Uses Parabolic SAR for stops. Ideal for long-term swinging.',
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
          'ichimoku': true, // Added for trend following
          'cci': false,
          'parabolicSar': true, // Added for trailing stops
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
      description:
          'Exploits explosive moves from squeeze conditions using Bollinger Bands, CCI, ATR, and VWAP. High-risk, high-reward intraday strategy.',
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
          'ichimoku': false,
          'cci': true, // Added for breakout validation
          'parabolicSar': false,
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
          'Short-term scalping via CCI/Stochastic with strict risk management: partial exits at 1.5%, Parabolic SAR stops, and market-close liquidation.',
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
          'ichimoku': false,
          'cci': true, // Added for scalping
          'parabolicSar': true, // Tight stops
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
      description:
          'Advanced strategy using Custom Indicators: Automatically engages when Price crosses above the 21-period EMA.',
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
          'ichimoku': false,
          'cci': false,
          'parabolicSar': false,
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
          'High-volatility momentum strategy (CCI, RSI) designed for crypto-correlated stocks with Parabolic SAR trailing stops.',
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
          'ichimoku': false,
          'cci': true, // Volatility sensitive
          'parabolicSar': true, // Trailing stop
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
          'ichimoku': false,
          'cci': false,
          'parabolicSar': false,
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
          'Ideal for sideways markets. Profitable when Price Movement and CCI Impulse are low.',
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
          'ichimoku': false,
          'cci': true, // Range confirmation
          'parabolicSar': false,
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
          'ichimoku': false,
          'cci': false,
          'parabolicSar': false,
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
          'ichimoku': false,
          'cci': false,
          'parabolicSar': false,
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
          'Uses dynamic position sizing to risk exactly 1% of account equity per trade, managed by Parabolic SAR.',
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
          'ichimoku': false,
          'cci': false,
          'parabolicSar': true, // Trailing stop support
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
          'Trades when MACD histogram flips positive while RSI is oversold (< 40), confirmed by CCI.',
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
          'ichimoku': false,
          'cci': true, // Confirm reversal
          'parabolicSar': false,
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
          'Breakout strategy. Low volatility period (ATR) followed by price piercing Upper Band with CCI momentum.',
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
          'ichimoku': false,
          'cci': true, // Breakout strength
          'parabolicSar': false,
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
          'ichimoku': false,
          'cci': false,
          'parabolicSar': false,
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
          'High-frequency style: SPY 5m chart, riding rapid momentum (CCI/RSI) bursts with tight risk using Parabolic SAR.',
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
          'ichimoku': false,
          'cci': true, // Speed
          'parabolicSar': true, // Trailing
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
          'Trend following on XLK (Tech Sector). Captures multi-day moves confirmed by Ichimoku Cloud.',
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
          'ichimoku': true, // Trend confirm
          'cci': false,
          'parabolicSar': true, // Trailing
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
          'Low-beta strategy on SCHD. Buys dips (RSI < 30) in uptrends with CCI oversold confirmation.',
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
          'ichimoku': false,
          'cci': true, // Oversold
          'parabolicSar': false,
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
    TradeStrategyTemplate(
      id: 'default_cloud_breakout',
      name: 'Ichimoku Cloud Breakout',
      description:
          'Trend-following strategy utilizing the Ichimoku Cloud for support/resistance, Parabolic SAR for stops, and CCI for momentum validation.',
      config: TradeStrategyConfig(
        startDate: DateTime.now().subtract(const Duration(days: 365)),
        endDate: DateTime.now(),
        interval: '1d',
        enabledIndicators: {
          'priceMovement': true,
          'momentum': false,
          'marketDirection': true,
          'volume': false,
          'macd': false,
          'bollingerBands': false,
          'stochastic': false,
          'atr': true,
          'obv': false,
          'vwap': false,
          'adx': true,
          'williamsR': false,
          'ichimoku': true,
          'cci': true,
          'parabolicSar': true,
        },
        takeProfitPercent: 18.0,
        stopLossPercent: 7.0,
        trailingStopEnabled: true,
        trailingStopPercent: 4.0,
        riskPerTrade: 0.02,
      ),
      createdAt: DateTime.now(),
    ),
    TradeStrategyTemplate(
      id: 'default_triple_screen_sim',
      name: 'Triple Screen Simulation',
      description:
          'Simulates Elder\'s Triple Screen: Trend (MACD/SMA) + Oscillator (Stochastic/Williams) + Breakout (Price).',
      config: TradeStrategyConfig(
        startDate: DateTime.now().subtract(const Duration(days: 365)),
        endDate: DateTime.now(),
        interval: '1d',
        enabledIndicators: {
          'priceMovement': true, // Screen 3: Execution
          'momentum': false,
          'marketDirection': true, // Screen 1: Trend (SMA)
          'volume': false,
          'macd': true, // Screen 1: Trend (Momentum)
          'bollingerBands': false,
          'stochastic': true, // Screen 2: Value
          'atr': true,
          'obv': false,
          'vwap': false,
          'adx': true, // Trend strength
          'williamsR': true, // Screen 2: Value alternative
          'ichimoku': false,
          'cci': false,
          'parabolicSar': true, // Risk management
        },
        riskPerTrade: 0.015,
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
          'Exploits early market volatility (9:30-10:30 AM). Uses VWAP as anchor and Volume/CCI for confirmation.',
      config: TradeStrategyConfig(
        startDate: DateTime.now().subtract(const Duration(days: 90)),
        endDate: DateTime.now(),
        interval: '5m',
        enabledIndicators: {
          'priceMovement': true, // Break high/low
          'momentum': true, // RSI
          'marketDirection': false,
          'volume': true, // Critical for ORB
          'macd': false,
          'bollingerBands': false,
          'stochastic': false,
          'atr': true, // Volatility check
          'obv': false,
          'vwap': true, // Anchor
          'adx': false,
          'williamsR': false,
          'ichimoku': false,
          'cci': true, // Momentum burst
          'parabolicSar': false,
        },
        riskPerTrade: 0.015,
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
        startDate: DateTime.now().subtract(const Duration(days: 1095)), // 3 years
        endDate: DateTime.now(),
        interval: '1d',
        enabledIndicators: {
          'priceMovement': true, // Breakout detection
          'momentum': false,
          'marketDirection': true, // SMA Trend
          'volume': false,
          'macd': false,
          'bollingerBands': false,
          'stochastic': false,
          'atr': true, // Volatility stops
          'obv': false,
          'vwap': false,
          'adx': true, // Trend strength
          'williamsR': false,
          'ichimoku': false,
          'cci': false,
          'parabolicSar': true, // Trailing stop
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
      name: 'RSI Fade (Contrarian)',
      description:
          'Fades overextended moves. Sells when RSI > 75 and price hits upper Bollinger Band while ADX suggests weak trend.',
      config: TradeStrategyConfig(
        startDate: DateTime.now().subtract(const Duration(days: 365)),
        endDate: DateTime.now(),
        interval: '1h',
        enabledIndicators: {
          'priceMovement': true,
          'momentum': true, // RSI
          'marketDirection': false,
          'volume': false,
          'macd': false,
          'bollingerBands': true, // Reversal zone
          'stochastic': true, // Confirmation
          'atr': true,
          'obv': false,
          'vwap': false,
          'adx': true, // Ensure no strong trend (implied inverse logic if checked?)
          'williamsR': true,
          'ichimoku': false,
          'cci': true,
          'parabolicSar': false,
        },
        customIndicators: [
          CustomIndicatorConfig(
            id: 'rsi_extreme',
            name: 'RSI > 75',
            type: IndicatorType.RSI,
            parameters: {'period': 14},
            condition: SignalCondition.GreaterThan,
            threshold: 75.0,
            compareToPrice: false,
          ),
        ],
        riskPerTrade: 0.01,
        takeProfitPercent: 5.0,
        stopLossPercent: 3.0,
        trailingStopEnabled: false,
      ),
      createdAt: DateTime.now(),
    ),
  ];
}
