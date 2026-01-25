/// Backtesting Models
///
/// Models for the backtesting interface and historical strategy simulation.
library;

import 'trade_strategy_config.dart';

export 'exit_stage.dart';
export 'trade_strategy_config.dart';

/// A single trade executed during a backtest
class BacktestTrade {
  final DateTime timestamp;
  final String action; // 'BUY', 'SELL'
  final String? symbol;
  final double price;
  final int quantity;
  final double commission;
  final String reason; // Entry reason (signal) or exit reason (TP/SL/trailing)
  final Map<String, dynamic>? signalData; // Original signal data

  BacktestTrade({
    required this.timestamp,
    required this.action,
    this.symbol,
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
        'symbol': symbol,
        'price': price,
        'quantity': quantity,
        'commission': commission,
        'reason': reason,
        'signalData': signalData,
      };

  factory BacktestTrade.fromJson(Map<String, dynamic> json) => BacktestTrade(
        timestamp: DateTime.parse(json['timestamp'] as String),
        action: json['action'] as String,
        symbol: json['symbol'] as String?,
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
  final String? id; // Firestore Document ID
  final String? templateId; // ID of the template used (if any)
  final String? templateName; // Name of the template used (if any)
  final TradeStrategyConfig config;
  final List<BacktestTrade> trades;
  final double finalCapital;
  final double totalReturn;
  final double totalReturnPercent;
  final double buyAndHoldReturn;
  final double buyAndHoldReturnPercent;
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
  final List<Map<String, dynamic>> buyAndHoldEquityCurve;
  final Map<String, dynamic> performanceByIndicator;

  BacktestResult({
    this.id,
    this.templateId,
    this.templateName,
    required this.config,
    required this.trades,
    required this.finalCapital,
    required this.totalReturn,
    required this.totalReturnPercent,
    required this.buyAndHoldReturn,
    required this.buyAndHoldReturnPercent,
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
    this.buyAndHoldEquityCurve = const [],
    required this.performanceByIndicator,
  });

  BacktestResult copyWith({
    String? id,
    String? templateId,
    String? templateName,
  }) {
    return BacktestResult(
      id: id ?? this.id,
      templateId: templateId ?? this.templateId,
      templateName: templateName ?? this.templateName,
      config: config,
      trades: trades,
      finalCapital: finalCapital,
      totalReturn: totalReturn,
      totalReturnPercent: totalReturnPercent,
      buyAndHoldReturn: buyAndHoldReturn,
      buyAndHoldReturnPercent: buyAndHoldReturnPercent,
      totalTrades: totalTrades,
      winningTrades: winningTrades,
      losingTrades: losingTrades,
      winRate: winRate,
      averageWin: averageWin,
      averageLoss: averageLoss,
      largestWin: largestWin,
      largestLoss: largestLoss,
      profitFactor: profitFactor,
      sharpeRatio: sharpeRatio,
      maxDrawdown: maxDrawdown,
      maxDrawdownPercent: maxDrawdownPercent,
      averageHoldTime: averageHoldTime,
      totalDuration: totalDuration,
      equityCurve: equityCurve,
      buyAndHoldEquityCurve: buyAndHoldEquityCurve,
      performanceByIndicator: performanceByIndicator,
    );
  }

  Map<String, dynamic> toJson() => {
        'templateId': templateId,
        'templateName': templateName,
        'config': config.toJson(),
        'trades': trades.map((t) => t.toJson()).toList(),
        'finalCapital': finalCapital,
        'totalReturn': totalReturn,
        'totalReturnPercent': totalReturnPercent,
        'buyAndHoldReturn': buyAndHoldReturn,
        'buyAndHoldReturnPercent': buyAndHoldReturnPercent,
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
        'buyAndHoldEquityCurve': buyAndHoldEquityCurve,
        'performanceByIndicator': performanceByIndicator,
      };

  factory BacktestResult.fromJson(Map<String, dynamic> json, {String? id}) =>
      BacktestResult(
        id: id,
        templateId: json['templateId'] as String?,
        templateName: json['templateName'] as String?,
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
        buyAndHoldReturn: (json['buyAndHoldReturn'] as num?)?.toDouble() ?? 0.0,
        buyAndHoldReturnPercent:
            (json['buyAndHoldReturnPercent'] as num?)?.toDouble() ?? 0.0,
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
        buyAndHoldEquityCurve: (json['buyAndHoldEquityCurve'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [],
        performanceByIndicator:
            Map<String, dynamic>.from(json['performanceByIndicator'] as Map),
      );
}
