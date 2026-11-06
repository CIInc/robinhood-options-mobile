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
  final String? entryRegime; // 'BULL_LOW_VOL', 'BULL_HIGH_VOL', etc.

  BacktestTrade({
    required this.timestamp,
    required this.action,
    this.symbol,
    required this.price,
    required this.quantity,
    this.commission = 0.0,
    required this.reason,
    this.signalData,
    this.entryRegime,
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
        'entryRegime': entryRegime,
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
        entryRegime: json['entryRegime'] as String?,
      );
}

/// Performance attribution for a specific macro market regime
class RegimePerformanceAttribution {
  final String regime;
  final String label;
  final int tradeCount;
  final int winCount;
  final int lossCount;
  final double winRate;
  final double winRatePercent;
  final double netProfit;
  final double profitFactor;
  final double averageProfit;
  final double maxDrawdownPercent;

  const RegimePerformanceAttribution({
    required this.regime,
    required this.label,
    required this.tradeCount,
    required this.winCount,
    required this.lossCount,
    required this.winRate,
    required this.winRatePercent,
    required this.netProfit,
    required this.profitFactor,
    required this.averageProfit,
    required this.maxDrawdownPercent,
  });

  Map<String, dynamic> toJson() => {
        'regime': regime,
        'label': label,
        'tradeCount': tradeCount,
        'winCount': winCount,
        'lossCount': lossCount,
        'winRate': winRate,
        'winRatePercent': winRatePercent,
        'netProfit': netProfit,
        'profitFactor': profitFactor,
        'averageProfit': averageProfit,
        'maxDrawdownPercent': maxDrawdownPercent,
      };

  factory RegimePerformanceAttribution.fromJson(Map<String, dynamic> json) =>
      RegimePerformanceAttribution(
        regime: json['regime'] as String? ?? 'UNKNOWN',
        label: json['label'] as String? ?? 'Unknown',
        tradeCount: (json['tradeCount'] as num?)?.toInt() ?? 0,
        winCount: (json['winCount'] as num?)?.toInt() ?? 0,
        lossCount: (json['lossCount'] as num?)?.toInt() ?? 0,
        winRate: (json['winRate'] as num?)?.toDouble() ?? 0.0,
        winRatePercent: (json['winRatePercent'] as num?)?.toDouble() ?? 0.0,
        netProfit: (json['netProfit'] as num?)?.toDouble() ?? 0.0,
        profitFactor: (json['profitFactor'] as num?)?.toDouble() ?? 0.0,
        averageProfit: (json['averageProfit'] as num?)?.toDouble() ?? 0.0,
        maxDrawdownPercent:
            (json['maxDrawdownPercent'] as num?)?.toDouble() ?? 0.0,
      );
}

/// Period metrics for In-Sample or Out-of-Sample walk-forward window
class WalkForwardPeriodMetrics {
  final int totalTrades;
  final double winRate;
  final double totalReturn;
  final double totalReturnPercent;
  final double profitFactor;
  final double sharpeRatio;
  final double maxDrawdownPercent;

  const WalkForwardPeriodMetrics({
    required this.totalTrades,
    required this.winRate,
    required this.totalReturn,
    required this.totalReturnPercent,
    required this.profitFactor,
    required this.sharpeRatio,
    required this.maxDrawdownPercent,
  });

  Map<String, dynamic> toJson() => {
        'totalTrades': totalTrades,
        'winRate': winRate,
        'totalReturn': totalReturn,
        'totalReturnPercent': totalReturnPercent,
        'profitFactor': profitFactor,
        'sharpeRatio': sharpeRatio,
        'maxDrawdownPercent': maxDrawdownPercent,
      };

  factory WalkForwardPeriodMetrics.fromJson(Map<String, dynamic> json) =>
      WalkForwardPeriodMetrics(
        totalTrades: (json['totalTrades'] as num?)?.toInt() ?? 0,
        winRate: (json['winRate'] as num?)?.toDouble() ?? 0.0,
        totalReturn: (json['totalReturn'] as num?)?.toDouble() ?? 0.0,
        totalReturnPercent:
            (json['totalReturnPercent'] as num?)?.toDouble() ?? 0.0,
        profitFactor: (json['profitFactor'] as num?)?.toDouble() ?? 0.0,
        sharpeRatio: (json['sharpeRatio'] as num?)?.toDouble() ?? 0.0,
        maxDrawdownPercent:
            (json['maxDrawdownPercent'] as num?)?.toDouble() ?? 0.0,
      );
}

/// Out-of-sample walk-forward validation and stability assessment
class WalkForwardValidationResult {
  final double splitRatio;
  final String splitTimestamp;
  final WalkForwardPeriodMetrics inSample;
  final WalkForwardPeriodMetrics outOfSample;
  final double sharpeRetention;
  final double profitFactorRetention;
  final String
      stabilityScore; // 'ROBUST', 'MODERATE', 'OVERFITTED', 'INSUFFICIENT_DATA'
  final String summary;

  const WalkForwardValidationResult({
    required this.splitRatio,
    required this.splitTimestamp,
    required this.inSample,
    required this.outOfSample,
    required this.sharpeRetention,
    required this.profitFactorRetention,
    required this.stabilityScore,
    required this.summary,
  });

  bool get isRobust => stabilityScore == 'ROBUST';
  bool get isModerate => stabilityScore == 'MODERATE';
  bool get isOverfitted => stabilityScore == 'OVERFITTED';

  Map<String, dynamic> toJson() => {
        'splitRatio': splitRatio,
        'splitTimestamp': splitTimestamp,
        'inSample': inSample.toJson(),
        'outOfSample': outOfSample.toJson(),
        'sharpeRetention': sharpeRetention,
        'profitFactorRetention': profitFactorRetention,
        'stabilityScore': stabilityScore,
        'summary': summary,
      };

  factory WalkForwardValidationResult.fromJson(Map<String, dynamic> json) =>
      WalkForwardValidationResult(
        splitRatio: (json['splitRatio'] as num?)?.toDouble() ?? 0.70,
        splitTimestamp: json['splitTimestamp'] as String? ?? '',
        inSample: WalkForwardPeriodMetrics.fromJson(
          Map<String, dynamic>.from(json['inSample'] as Map? ?? {}),
        ),
        outOfSample: WalkForwardPeriodMetrics.fromJson(
          Map<String, dynamic>.from(json['outOfSample'] as Map? ?? {}),
        ),
        sharpeRetention: (json['sharpeRetention'] as num?)?.toDouble() ?? 1.0,
        profitFactorRetention:
            (json['profitFactorRetention'] as num?)?.toDouble() ?? 1.0,
        stabilityScore:
            json['stabilityScore'] as String? ?? 'INSUFFICIENT_DATA',
        summary: json['summary'] as String? ?? '',
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
  final List<RegimePerformanceAttribution> regimeAttribution;
  final WalkForwardValidationResult? walkForwardValidation;

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
    this.regimeAttribution = const [],
    this.walkForwardValidation,
  });

  BacktestResult copyWith({
    String? id,
    String? templateId,
    String? templateName,
    List<RegimePerformanceAttribution>? regimeAttribution,
    WalkForwardValidationResult? walkForwardValidation,
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
      regimeAttribution: regimeAttribution ?? this.regimeAttribution,
      walkForwardValidation:
          walkForwardValidation ?? this.walkForwardValidation,
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
        'regimeAttribution': regimeAttribution.map((r) => r.toJson()).toList(),
        if (walkForwardValidation != null)
          'walkForwardValidation': walkForwardValidation!.toJson(),
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
        regimeAttribution: () {
          final raw = json['regimeAttribution'];
          if (raw is List) {
            return raw
                .map((r) => RegimePerformanceAttribution.fromJson(
                    Map<String, dynamic>.from(r as Map)))
                .toList();
          } else if (raw is Map) {
            return raw.values
                .map((r) => RegimePerformanceAttribution.fromJson(
                    Map<String, dynamic>.from(r as Map)))
                .toList();
          }
          return <RegimePerformanceAttribution>[];
        }(),
        walkForwardValidation: json['walkForwardValidation'] != null
            ? WalkForwardValidationResult.fromJson(
                Map<String, dynamic>.from(json['walkForwardValidation'] as Map))
            : null,
      );
}
