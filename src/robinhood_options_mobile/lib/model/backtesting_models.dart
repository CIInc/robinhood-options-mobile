/// Backtesting Models
///
/// Models for the backtesting interface and historical strategy simulation.
library;

/// Configuration for a backtesting run
class BacktestConfig {
  final String symbol;
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

  BacktestConfig({
    required this.symbol,
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
        'symbol': symbol,
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
      };

  factory BacktestConfig.fromJson(Map<String, dynamic> json) => BacktestConfig(
        symbol: json['symbol'] as String,
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
  final BacktestConfig config;
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
        config: BacktestConfig.fromJson(
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
class BacktestTemplate {
  final String id;
  final String name;
  final String description;
  final BacktestConfig config;
  final DateTime createdAt;
  final DateTime? lastUsedAt;

  BacktestTemplate({
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

  factory BacktestTemplate.fromJson(Map<String, dynamic> json) =>
      BacktestTemplate(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String,
        config: BacktestConfig.fromJson(
          Map<String, dynamic>.from(json['config'] as Map),
        ),
        createdAt: DateTime.parse(json['createdAt'] as String),
        lastUsedAt: json['lastUsedAt'] != null
            ? DateTime.parse(json['lastUsedAt'] as String)
            : null,
      );
}
