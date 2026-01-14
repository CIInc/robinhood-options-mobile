/// Backtesting Models
///
/// Models for the backtesting interface and historical strategy simulation.
library;

import 'agentic_trading_config.dart';
import 'custom_indicator_config.dart';

/// Configuration for a backtesting run
class TradeStrategyConfig {
  final DateTime startDate;
  final DateTime endDate;
  final double initialCapital;
  final String interval; // '1d', '1h', '15m'
  final Map<String, bool> enabledIndicators;
  final int tradeQuantity;
  final double takeProfitPercent;
  final double stopLossPercent;
  final bool trailingStopEnabled;
  final double trailingStopPercent;
  final int rsiPeriod;
  final int smaPeriodFast;
  final int smaPeriodSlow;
  final String marketIndexSymbol;

  // Advanced Auto-Trading Alignment
  final double minSignalStrength;
  final bool requireAllIndicatorsGreen;
  final bool timeBasedExitEnabled;
  final int timeBasedExitMinutes;
  final bool marketCloseExitEnabled;
  final int marketCloseExitMinutes;
  final bool enablePartialExits;
  final List<ExitStage> exitStages;
  final bool enableDynamicPositionSizing;
  final double riskPerTrade;
  final double atrMultiplier;
  final List<CustomIndicatorConfig> customIndicators;
  final List<String> symbolFilter;

  TradeStrategyConfig({
    required this.startDate,
    required this.endDate,
    this.initialCapital = 10000.0,
    this.interval = '1d',
    Map<String, bool>? enabledIndicators,
    this.tradeQuantity = 1,
    this.takeProfitPercent = 10.0,
    this.stopLossPercent = 5.0,
    this.trailingStopEnabled = false,
    this.trailingStopPercent = 5.0,
    this.rsiPeriod = 14,
    this.smaPeriodFast = 10,
    this.smaPeriodSlow = 30,
    this.marketIndexSymbol = 'SPY',
    this.minSignalStrength = 50.0,
    this.requireAllIndicatorsGreen = false,
    this.timeBasedExitEnabled = false,
    this.timeBasedExitMinutes = 120,
    this.marketCloseExitEnabled = false,
    this.marketCloseExitMinutes = 15,
    this.enablePartialExits = false,
    this.exitStages = const [],
    this.enableDynamicPositionSizing = false,
    this.riskPerTrade = 0.01,
    this.atrMultiplier = 2.0,
    this.customIndicators = const [],
    this.symbolFilter = const [],
  }) : enabledIndicators = enabledIndicators ??
            {
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
            };

  Map<String, dynamic> toJson() => {
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'initialCapital': initialCapital,
        'interval': interval,
        'enabledIndicators': enabledIndicators,
        'tradeQuantity': tradeQuantity,
        'takeProfitPercent': takeProfitPercent,
        'stopLossPercent': stopLossPercent,
        'trailingStopEnabled': trailingStopEnabled,
        'trailingStopPercent': trailingStopPercent,
        'rsiPeriod': rsiPeriod,
        'smaPeriodFast': smaPeriodFast,
        'smaPeriodSlow': smaPeriodSlow,
        'marketIndexSymbol': marketIndexSymbol,
        'minSignalStrength': minSignalStrength,
        'requireAllIndicatorsGreen': requireAllIndicatorsGreen,
        'timeBasedExitEnabled': timeBasedExitEnabled,
        'timeBasedExitMinutes': timeBasedExitMinutes,
        'marketCloseExitEnabled': marketCloseExitEnabled,
        'marketCloseExitMinutes': marketCloseExitMinutes,
        'enablePartialExits': enablePartialExits,
        'exitStages': exitStages.map((e) => e.toJson()).toList(),
        'enableDynamicPositionSizing': enableDynamicPositionSizing,
        'riskPerTrade': riskPerTrade,
        'atrMultiplier': atrMultiplier,
        'customIndicators': customIndicators.map((e) => e.toJson()).toList(),
        'symbolFilter': symbolFilter,
      };

  factory TradeStrategyConfig.fromJson(Map<String, dynamic> json) =>
      TradeStrategyConfig(
        startDate: DateTime.parse(json['startDate'] as String),
        endDate: DateTime.parse(json['endDate'] as String),
        initialCapital: (json['initialCapital'] as num).toDouble(),
        interval: json['interval'] as String,
        enabledIndicators: json['enabledIndicators'] != null
            ? Map<String, bool>.from(json['enabledIndicators'] as Map)
            : null,
        tradeQuantity: json['tradeQuantity'] as int,
        takeProfitPercent: (json['takeProfitPercent'] as num).toDouble(),
        stopLossPercent: (json['stopLossPercent'] as num).toDouble(),
        trailingStopEnabled: json['trailingStopEnabled'] as bool? ?? false,
        trailingStopPercent:
            (json['trailingStopPercent'] as num?)?.toDouble() ?? 5.0,
        rsiPeriod: json['rsiPeriod'] as int,
        smaPeriodFast: json['smaPeriodFast'] as int,
        smaPeriodSlow: json['smaPeriodSlow'] as int,
        marketIndexSymbol: json['marketIndexSymbol'] as String,
        minSignalStrength:
            (json['minSignalStrength'] as num?)?.toDouble() ?? 50.0,
        requireAllIndicatorsGreen:
            json['requireAllIndicatorsGreen'] as bool? ?? false,
        timeBasedExitEnabled: json['timeBasedExitEnabled'] as bool? ?? false,
        timeBasedExitMinutes: json['timeBasedExitMinutes'] as int? ?? 120,
        marketCloseExitEnabled:
            json['marketCloseExitEnabled'] as bool? ?? false,
        marketCloseExitMinutes: json['marketCloseExitMinutes'] as int? ?? 15,
        enablePartialExits: json['enablePartialExits'] as bool? ?? false,
        exitStages: (json['exitStages'] as List<dynamic>?)
                ?.map((e) =>
                    ExitStage.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            [],
        enableDynamicPositionSizing:
            json['enableDynamicPositionSizing'] as bool? ?? false,
        riskPerTrade: (json['riskPerTrade'] as num?)?.toDouble() ?? 0.01,
        atrMultiplier: (json['atrMultiplier'] as num?)?.toDouble() ?? 2.0,
        customIndicators: (json['customIndicators'] as List<dynamic>?)
                ?.map((e) => CustomIndicatorConfig.fromJson(
                    Map<String, dynamic>.from(e as Map)))
                .toList() ??
            [],
        symbolFilter: (json['symbolFilter'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
      );
}

/// A single trade executed during a backtest
class BacktestTrade {
  final DateTime timestamp;
  final String action; // 'BUY', 'SELL'
  final double price;
  final int quantity;
  final double commission;
  final String reason; // Entry reason (signal) or exit reason (TP/SL/trailing)
  final Map<String, dynamic>? signalData; // Original signal data

  BacktestTrade({
    required this.timestamp,
    required this.action,
    required this.price,
    required this.quantity,
    this.commission = 0.0,
    required this.reason,
    this.signalData,
  });

  double get totalCost => price * quantity + commission;

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'action': action,
        'price': price,
        'quantity': quantity,
        'commission': commission,
        'reason': reason,
        'signalData': signalData,
      };

  factory BacktestTrade.fromJson(Map<String, dynamic> json) => BacktestTrade(
        timestamp: DateTime.parse(json['timestamp'] as String),
        action: json['action'] as String,
        price: (json['price'] as num).toDouble(),
        quantity: json['quantity'] as int,
        commission: (json['commission'] as num?)?.toDouble() ?? 0.0,
        reason: json['reason'] as String,
        signalData: json['signalData'] != null
            ? Map<String, dynamic>.from(json['signalData'] as Map)
            : null,
      );
}

/// Results from a completed backtest run
class BacktestResult {
  final TradeStrategyConfig config;
  final List<BacktestTrade> trades;
  final double finalCapital;
  final double totalReturn;
  final double totalReturnPercent;
  final int totalTrades;
  final int winningTrades;
  final int losingTrades;
  final double winRate;
  final double averageWin;
  final double averageLoss;
  final double largestWin;
  final double largestLoss;
  final double profitFactor;
  final double sharpeRatio;
  final double maxDrawdown;
  final double maxDrawdownPercent;
  final Duration averageHoldTime;
  final Duration totalDuration;
  final List<Map<String, dynamic>> equityCurve; // [{timestamp, equity}]
  final Map<String, dynamic> performanceByIndicator;

  BacktestResult({
    required this.config,
    required this.trades,
    required this.finalCapital,
    required this.totalReturn,
    required this.totalReturnPercent,
    required this.totalTrades,
    required this.winningTrades,
    required this.losingTrades,
    required this.winRate,
    required this.averageWin,
    required this.averageLoss,
    required this.largestWin,
    required this.largestLoss,
    required this.profitFactor,
    required this.sharpeRatio,
    required this.maxDrawdown,
    required this.maxDrawdownPercent,
    required this.averageHoldTime,
    required this.totalDuration,
    required this.equityCurve,
    required this.performanceByIndicator,
  });

  Map<String, dynamic> toJson() => {
        'config': config.toJson(),
        'trades': trades.map((t) => t.toJson()).toList(),
        'finalCapital': finalCapital,
        'totalReturn': totalReturn,
        'totalReturnPercent': totalReturnPercent,
        'totalTrades': totalTrades,
        'winningTrades': winningTrades,
        'losingTrades': losingTrades,
        'winRate': winRate,
        'averageWin': averageWin,
        'averageLoss': averageLoss,
        'largestWin': largestWin,
        'largestLoss': largestLoss,
        'profitFactor': profitFactor,
        'sharpeRatio': sharpeRatio,
        'maxDrawdown': maxDrawdown,
        'maxDrawdownPercent': maxDrawdownPercent,
        'averageHoldTimeSeconds': averageHoldTime.inSeconds,
        'totalDurationSeconds': totalDuration.inSeconds,
        'equityCurve': equityCurve,
        'performanceByIndicator': performanceByIndicator,
      };

  factory BacktestResult.fromJson(Map<String, dynamic> json) => BacktestResult(
        config: TradeStrategyConfig.fromJson(
          Map<String, dynamic>.from(json['config'] as Map),
        ),
        trades: (json['trades'] as List)
            .map((t) =>
                BacktestTrade.fromJson(Map<String, dynamic>.from(t as Map)))
            .toList(),
        finalCapital: (json['finalCapital'] as num).toDouble(),
        totalReturn: (json['totalReturn'] as num).toDouble(),
        totalReturnPercent: (json['totalReturnPercent'] as num).toDouble(),
        totalTrades: json['totalTrades'] as int,
        winningTrades: json['winningTrades'] as int,
        losingTrades: json['losingTrades'] as int,
        winRate: (json['winRate'] as num).toDouble(),
        averageWin: (json['averageWin'] as num).toDouble(),
        averageLoss: (json['averageLoss'] as num).toDouble(),
        largestWin: (json['largestWin'] as num).toDouble(),
        largestLoss: (json['largestLoss'] as num).toDouble(),
        profitFactor: (json['profitFactor'] as num).toDouble(),
        sharpeRatio: (json['sharpeRatio'] as num).toDouble(),
        maxDrawdown: (json['maxDrawdown'] as num).toDouble(),
        maxDrawdownPercent: (json['maxDrawdownPercent'] as num).toDouble(),
        averageHoldTime:
            Duration(seconds: json['averageHoldTimeSeconds'] as int),
        totalDuration: Duration(seconds: json['totalDurationSeconds'] as int),
        equityCurve: (json['equityCurve'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
        performanceByIndicator:
            Map<String, dynamic>.from(json['performanceByIndicator'] as Map),
      );
}

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
