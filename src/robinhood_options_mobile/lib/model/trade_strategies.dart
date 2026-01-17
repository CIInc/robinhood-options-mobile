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
          'Captures strong price moves by combining RSI and CCI momentum with ADX trend confirmation. Best for strong trends.',
      config: TradeStrategyConfig(
        minSignalStrength: 65.0,
        requireAllIndicatorsGreen: false,
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
          'adx': true, // ADX
          'williamsR': false,
          'ichimoku': false,
          'cci': true, // CCI
          'parabolicSar': false,
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
        enabledIndicators: {
          'priceMovement': true,
          'momentum': false,
          'marketDirection': true,
          'volume': false,
          'macd': true,
          'bollingerBands': false,
          'stochastic': false,
          'atr': true,
          'obv': true,
          'vwap': false,
          'adx': true, // ADX
          'williamsR': false,
          'ichimoku': true,
          'cci': false,
          'parabolicSar': true,
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
        trailingStopPercent: 5.0,
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
          'adx': true, // ADX > 20
          'williamsR': false,
          'ichimoku': false,
          'cci': true, // CCI > 100
          'parabolicSar': false,
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
        trailingStopPercent: 2.0,
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
          'atr': true,
          'obv': false,
          'vwap': true,
          'adx': true, // ADX
          'williamsR': true,
          'ichimoku': false,
          'cci': true,
          'parabolicSar': true,
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
        enabledIndicators: {
          'priceMovement': true,
          'momentum': false,
          'marketDirection': false,
          'volume': true, // Added volume
          'macd': false,
          'bollingerBands': false,
          'stochastic': false,
          'atr': true, // For stop loss helper
          'obv': false,
          'vwap': false,
          'adx': false,
          'williamsR': false,
          'ichimoku': false,
          'cci': false,
          'parabolicSar': true, // Trailing stop source
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
          'adx': true, // Strong Trend
          'williamsR': false,
          'ichimoku': false,
          'cci': true, // Volatility sensitive
          'parabolicSar': true, // Trailing stop
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
        stopLossPercent: 8.0, // Wider stop for volatility
        trailingStopEnabled: true,
        trailingStopPercent: 5.0,
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
      name: 'Range Bound (RSI 40-60)',
      description:
          'Ideal for choppy, sideways markets. Targets entries when RSI is in the neutral zone (40-60) indicating lack of strong trend.',
      config: TradeStrategyConfig(
        minSignalStrength: 50.0,
        requireAllIndicatorsGreen: false,
        startDate: DateTime.now().subtract(const Duration(days: 365)),
        endDate: DateTime.now(),
        interval: '1d',
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
        minSignalStrength: 50.0,
        requireAllIndicatorsGreen: false,
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
          'Breakout strategy. Low volatility period (ATR) followed by price piercing Upper Band with CCI momentum (> 100).',
      config: TradeStrategyConfig(
        minSignalStrength: 50.0,
        requireAllIndicatorsGreen: false,
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
          'High-frequency style: SPY 5m chart, riding rapid momentum (CCI > 100, RSI > 55) bursts with tight risk.',
      config: TradeStrategyConfig(
        minSignalStrength: 65.0,
        requireAllIndicatorsGreen: false,
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
          'Trend-following strategy utilizing the Ichimoku Cloud for support/resistance, Parabolic SAR for stops, and CCI > 100 for momentum.',
      config: TradeStrategyConfig(
        minSignalStrength: 65.0,
        requireAllIndicatorsGreen: false,
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
      name: 'RSI Reversal (Long)',
      description:
          'Contrarian Mean Reversion. Buys when RSI < 30 (Oversold) and price hits Lower Bollinger Band while ADX suggests trend exhaustion.',
      config: TradeStrategyConfig(
        minSignalStrength: 50.0,
        requireAllIndicatorsGreen: false,
        startDate: DateTime.now().subtract(const Duration(days: 365)),
        endDate: DateTime.now(),
        interval: '1h',
        enabledIndicators: {
          'priceMovement': true,
          'momentum': true, // RSI
          'marketDirection': false,
          'volume': false,
          'macd': false,
          'bollingerBands': true, // Reversal zone (Lower Band implied by oversold)
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
        ],
        riskPerTrade: 0.01,
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
        enabledIndicators: {
          'priceMovement': true,
          'momentum': true,
          'marketDirection': true, // Key for swings
          'volume': false,
          'macd': true,
          'bollingerBands': false,
          'stochastic': false,
          'atr': true,
          'obv': false,
          'vwap': false,
          'adx': true,
          'williamsR': false,
          'ichimoku': false,
          'cci': false,
          'parabolicSar': true, // Trailing stops
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
        enabledIndicators: {
          'priceMovement': true,
          'momentum': true,
          'marketDirection': false,
          'volume': true, // Critical
          'macd': false,
          'bollingerBands': true, // Squeeze breaks
          'stochastic': false,
          'atr': true, // Volatility check
          'obv': true, // Smart money flow
          'vwap': true, // Support
          'adx': true, // Trend strength
          'williamsR': false,
          'ichimoku': false,
          'cci': true, // Scalper
          'parabolicSar': false,
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
        enabledIndicators: {
          'priceMovement': true,
          'momentum': false,
          'marketDirection': true,
          'volume': true,
          'macd': false,
          'bollingerBands': false,
          'stochastic': false,
          'atr': true,
          'obv': true, // Critical
          'vwap': false,
          'adx': true, // Trend strength
          'williamsR': false,
          'ichimoku': false,
          'cci': false,
          'parabolicSar': true,
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
        takeProfitPercent: 12.0,
        stopLossPercent: 5.0,
        trailingStopEnabled: true,
        trailingStopPercent: 2.0,
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
        enabledIndicators: {
          'priceMovement': true,
          'momentum': true,
          'marketDirection':
              true, // SMA 200 Check (Must be "Bullish" on the Inverse ETF itself)
          'volume': true,
          'macd': true, // Momentum flip
          'bollingerBands': false,
          'stochastic': false,
          'atr': true, // Volatility
          'obv': false,
          'vwap': false,
          'adx': true, // Trend strength
          'williamsR': false,
          'ichimoku': false,
          'cci': false,
          'parabolicSar': true, // Trailing stop
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
        takeProfitPercent: 15.0,
        stopLossPercent: 6.0,
        trailingStopEnabled: true,
        trailingStopPercent: 3.5,
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
        enabledIndicators: {
          'priceMovement': true,
          'momentum': false,
          'marketDirection': false,
          'volume': true, // Critical for catalysts
          'macd': false,
          'bollingerBands': true, // Expansion
          'stochastic': false,
          'atr': true,
          'obv': true, // Institutional flow
          'vwap': false,
          'adx': true, // Trend strength
          'williamsR': false,
          'ichimoku': false,
          'cci': true, // Impulse
          'parabolicSar': false,
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
        takeProfitPercent: 20.0,
        stopLossPercent: 7.0,
        trailingStopEnabled: true,
        trailingStopPercent: 4.0,
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
        enabledIndicators: {
          'priceMovement': true, // Gap Up (Price > prev close implied)
          'momentum': true, // RSI > 60
          'marketDirection': false,
          'volume': true, // Must be high
          'macd': false,
          'bollingerBands': false,
          'stochastic': false,
          'atr': true,
          'obv': false,
          'vwap': true, // Price > VWAP is key
          'adx': false,
          'williamsR': false,
          'ichimoku': false,
          'cci': true, // Momentum kick
          'parabolicSar': false,
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
        enabledIndicators: {
          'priceMovement': true,
          'momentum': false,
          'marketDirection': false,
          'volume': true, // Verification
          'macd': true,
          'bollingerBands': true, // Volatility Expansion
          'stochastic': false,
          'atr': true, // High Volatility
          'obv': false,
          'vwap': false,
          'adx': true, // Strong Trend (>25)
          'williamsR': false,
          'ichimoku': false,
          'cci': false,
          'parabolicSar': true, // Trailing
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
        enabledIndicators: {
          'priceMovement': false, // Looking for drops
          'momentum': true, // RSI
          'marketDirection': false,
          'volume': true, // Panic selling volume
          'macd': false,
          'bollingerBands': true, // Below lower band
          'stochastic': true, // Deep oversold
          'atr': true, // High volatility
          'obv': false,
          'vwap': false,
          'adx': false,
          'williamsR': true, // Ultra oversold
          'ichimoku': false,
          'cci': true,
          'parabolicSar': false,
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
        enabledIndicators: {
          'priceMovement': false, // Contrarian
          'momentum': true, // RSI overbought
          'marketDirection': true, // Extended from SMA
          'volume': true, // Climax volume
          'macd': true, // Histogram ticking down
          'bollingerBands': true, // Outside upper band
          'stochastic': true, // Crossing down
          'atr': true,
          'obv': false,
          'vwap': false,
          'adx': true, // Trend weakening
          'williamsR': true,
          'ichimoku': false,
          'cci': true,
          'parabolicSar': false,
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
        takeProfitPercent: 6.0,
        stopLossPercent: 3.0,
        trailingStopEnabled: true,
        trailingStopPercent: 1.5,
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
          'adx': true, // Low ADX (No trend yet)
          'williamsR': false,
          'ichimoku': false,
          'cci': false,
          'parabolicSar': false,
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
        enabledIndicators: {
          'priceMovement': false, // Bearish
          'momentum': false,
          'marketDirection': true, // SMA Crossover Key
          'volume': true,
          'macd': true,
          'bollingerBands': false,
          'stochastic': false,
          'atr': true, // Volatility check
          'obv': false,
          'vwap': false,
          'adx': true, // Confirm trend strength
          'williamsR': false,
          'ichimoku': true, // Cloud confirmation
          'cci': false,
          'parabolicSar': true, // Trailing stop
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
        enabledIndicators: {
          'priceMovement': true, // Key: Candle patterns
          'momentum': false,
          'marketDirection': false,
          'volume': true, // Breakout volume
          'macd': false,
          'bollingerBands': true, // Squeeze context
          'stochastic': false,
          'atr': true, // Profit targets based on ATR
          'obv': false,
          'vwap': false,
          'adx': false,
          'williamsR': false,
          'ichimoku': false,
          'cci': false,
          'parabolicSar': false,
        },
        riskPerTrade: 0.01,
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
        enabledIndicators: {
          'priceMovement': true, // Momentum
          'momentum': true, // RSI > 60-70 maintained
          'marketDirection': true, // Strong Uptrend
          'volume': true, // Low volume on flag, high on break
          'macd': false,
          'bollingerBands': false,
          'stochastic': false,
          'atr': true,
          'obv': true, // No distribution allowed
          'vwap': false,
          'adx': true, // ADX > 40 typically
          'williamsR': false,
          'ichimoku': false,
          'cci': true,
          'parabolicSar': true,
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
        takeProfitPercent: 40.0, // Multi-baggers
        stopLossPercent: 7.0,
        trailingStopEnabled: true,
        trailingStopPercent: 5.0,
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
        enabledIndicators: {
          'priceMovement': true,
          'momentum': true, // RSI
          'marketDirection': true,
          'volume': false,
          'macd': true,
          'bollingerBands': false,
          'stochastic': false,
          'atr': true,
          'obv': false,
          'vwap': false,
          'adx': true, // Trend strength
          'williamsR': false,
          'ichimoku': false,
          'cci': false,
          'parabolicSar': true, // Trailing stop
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
        enabledIndicators: {
          'priceMovement': true,
          'momentum': true, // RSI
          'marketDirection': false,
          'volume': true,
          'macd': true,
          'bollingerBands': true, // Breakout above upper band
          'stochastic': false,
          'atr': true,
          'obv': false,
          'vwap': false,
          'adx': true,
          'williamsR': false,
          'ichimoku': false,
          'cci': true,
          'parabolicSar': false,
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
        takeProfitPercent: 10.0,
        stopLossPercent: 4.0,
        trailingStopEnabled: true,
        trailingStopPercent: 2.0,
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
        takeProfitPercent: 8.0,
        stopLossPercent: 4.0,
        trailingStopEnabled: false,
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
        enabledIndicators: {
          'priceMovement': true,
          'momentum': false,
          'marketDirection': true, // SMA 50/200 Cross
          'volume': false, // Forex volume often less reliable in ETFs
          'macd': true,
          'bollingerBands': false,
          'stochastic': false,
          'atr': true, // Volatility
          'obv': false,
          'vwap': false,
          'adx': true, // Trend strength > 25
          'williamsR': false,
          'ichimoku': true, // Cloud confirmation
          'cci': false,
          'parabolicSar': true, // Trailing stop
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
        enabledIndicators: {
          'priceMovement': true,
          'momentum': true,
          'marketDirection': false,
          'volume': true,
          'macd': false,
          'bollingerBands': true, // Bounce off bands
          'stochastic': true, // Cycle lows
          'atr': true,
          'obv': true, // Accumulation check
          'vwap': false,
          'adx': true,
          'williamsR': false,
          'ichimoku': false,
          'cci': true, // Momentum
          'parabolicSar': false,
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
        enabledIndicators: {
          'priceMovement': false, // Shorting
          'momentum': true, // RSI turning down
          'marketDirection': false,
          'volume': true, // Volume on rejection
          'macd': false,
          'bollingerBands': false,
          'stochastic': true, // Overbought crossing down
          'atr': true,
          'obv': false,
          'vwap': true, // Key resistance level
          'adx': false,
          'williamsR': false,
          'ichimoku': false,
          'cci': false,
          'parabolicSar': true, // Tight stop
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
        enabledIndicators: {
          'priceMovement': true,
          'momentum': false,
          'marketDirection': true, // SMA Direction
          'volume': false,
          'macd': true,
          'bollingerBands': false,
          'stochastic': false,
          'atr': true,
          'obv': false,
          'vwap': false,
          'adx': true, // Primary filter
          'williamsR': false,
          'ichimoku': false,
          'cci': false,
          'parabolicSar': true,
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
        enabledIndicators: {
          'priceMovement': true,
          'momentum': false,
          'marketDirection': false,
          'volume': true,
          'macd': false,
          'bollingerBands': true, // Band expansion often accompanies CCI burst
          'stochastic': false,
          'atr': true,
          'obv': false,
          'vwap': false,
          'adx': true, // Trend acceleration
          'williamsR': false,
          'ichimoku': false,
          'cci': true, // Driver
          'parabolicSar': false,
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
        enabledIndicators: {
          'priceMovement': false, // Buying dip
          'momentum': false,
          'marketDirection': true, // SMA 200 Uptrend
          'volume': true, // Essential for MFI
          'macd': false,
          'bollingerBands': false,
          'stochastic': false,
          'atr': true,
          'obv': true, // Additional volume confirm
          'vwap': false,
          'adx': false,
          'williamsR': false,
          'ichimoku': false,
          'cci': false,
          'parabolicSar': false,
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
        enabledIndicators: {
          'priceMovement': true,
          'momentum': true,
          'marketDirection': false,
          'volume': true,
          'macd': false,
          'bollingerBands': true, // Breakout
          'stochastic': false,
          'atr': true,
          'obv': false,
          'vwap': false,
          'adx': true, // Trend strength
          'williamsR': false,
          'ichimoku': false,
          'cci': false,
          'parabolicSar': true, // Trailing
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
          'adx': true, // Low ADX likely
          'williamsR': false,
          'ichimoku': false,
          'cci': false,
          'parabolicSar': false,
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
        takeProfitPercent: 12.0,
        stopLossPercent: 5.0,
        trailingStopEnabled: true,
        trailingStopPercent: 3.0,
      ),
      createdAt: DateTime.now(),
    ),
  ];
}
