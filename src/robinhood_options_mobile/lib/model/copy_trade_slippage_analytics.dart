import 'package:robinhood_options_mobile/model/copy_trade_record.dart';

/// Summary of slippage and execution metrics for a specific trader/leader
class TraderSlippageSummary {
  final String traderId;
  final int totalTrades;
  final double averageLatencyMs;
  final double averageSlippageBps;
  final double totalSlippageCost;
  final double executionQualityScore;
  final double? leaderReturnPct;
  final double? followerReturnPct;
  final double? divergencePct;

  TraderSlippageSummary({
    required this.traderId,
    required this.totalTrades,
    required this.averageLatencyMs,
    required this.averageSlippageBps,
    required this.totalSlippageCost,
    required this.executionQualityScore,
    this.leaderReturnPct,
    this.followerReturnPct,
    this.divergencePct,
  });
}

/// Summary of slippage and execution metrics for an asset class (equity, option, crypto)
class AssetClassSlippageSummary {
  final String assetClass;
  final int totalTrades;
  final double averageLatencyMs;
  final double averageSlippageBps;
  final double totalSlippageCost;
  final double executionQualityScore;

  AssetClassSlippageSummary({
    required this.assetClass,
    required this.totalTrades,
    required this.averageLatencyMs,
    required this.averageSlippageBps,
    required this.totalSlippageCost,
    required this.executionQualityScore,
  });
}

/// Comprehensive summary of copy trading slippage, latency, and return divergence
class CopyTradeSlippageSummary {
  final int totalTrades;
  final int executedTrades;
  final int tradesWithSlippage;
  final double averageLatencyMs;
  final double medianLatencyMs;
  final int minLatencyMs;
  final int maxLatencyMs;
  final double averageSlippageDollar;
  final double averageSlippageBps;
  final double totalSlippageCost;
  final int favorableTradesCount;
  final int unfavorableTradesCount;
  final int neutralTradesCount;
  final double executionQualityScore; // 0.0 - 100.0%
  final double? averageLeaderReturnPct;
  final double? averageFollowerReturnPct;
  final double? netReturnDivergencePct;
  final Map<String, TraderSlippageSummary> byTrader;
  final Map<String, AssetClassSlippageSummary> byAssetClass;
  final Map<String, int> latencyBuckets;

  CopyTradeSlippageSummary({
    required this.totalTrades,
    required this.executedTrades,
    required this.tradesWithSlippage,
    required this.averageLatencyMs,
    required this.medianLatencyMs,
    required this.minLatencyMs,
    required this.maxLatencyMs,
    required this.averageSlippageDollar,
    required this.averageSlippageBps,
    required this.totalSlippageCost,
    required this.favorableTradesCount,
    required this.unfavorableTradesCount,
    required this.neutralTradesCount,
    required this.executionQualityScore,
    this.averageLeaderReturnPct,
    this.averageFollowerReturnPct,
    this.netReturnDivergencePct,
    required this.byTrader,
    required this.byAssetClass,
    required this.latencyBuckets,
  });
}

/// Analytics calculator for Copy Trading slippage and divergence
class CopyTradeSlippageAnalytics {
  /// Computes slippage, fill latency, and return divergence across trades
  static CopyTradeSlippageSummary compute({
    required List<CopyTradeRecord> trades,
    List<dynamic>? completedTrades, // Optional completed trade objects
  }) {
    if (trades.isEmpty) {
      return CopyTradeSlippageSummary(
        totalTrades: 0,
        executedTrades: 0,
        tradesWithSlippage: 0,
        averageLatencyMs: 0,
        medianLatencyMs: 0,
        minLatencyMs: 0,
        maxLatencyMs: 0,
        averageSlippageDollar: 0,
        averageSlippageBps: 0,
        totalSlippageCost: 0,
        favorableTradesCount: 0,
        unfavorableTradesCount: 0,
        neutralTradesCount: 0,
        executionQualityScore: 100.0,
        byTrader: {},
        byAssetClass: {},
        latencyBuckets: {
          '< 100ms': 0,
          '100-250ms': 0,
          '250-500ms': 0,
          '500ms-1s': 0,
          '> 1s': 0,
        },
      );
    }

    final executedTradesList = trades.where((t) => t.executed).toList();
    final totalExecuted = executedTradesList.length;

    final latencies = <int>[];
    double totalSlippageDollarSum = 0;
    double totalSlippageBpsSum = 0;
    double totalSlippageCostSum = 0;
    int favorableCount = 0;
    int unfavorableCount = 0;
    int neutralCount = 0;
    int tradesWithSlippageCount = 0;

    final latencyBuckets = {
      '< 100ms': 0,
      '100-250ms': 0,
      '250-500ms': 0,
      '500ms-1s': 0,
      '> 1s': 0,
    };

    final Map<String, List<CopyTradeRecord>> traderGroups = {};
    final Map<String, List<CopyTradeRecord>> assetGroups = {};

    for (final trade in executedTradesList) {
      traderGroups.putIfAbsent(trade.sourceUserId, () => []).add(trade);
      assetGroups.putIfAbsent(trade.orderType, () => []).add(trade);

      final latency = trade.effectiveFillLatencyMs;
      if (latency != null) {
        latencies.add(latency);
        if (latency < 100) {
          latencyBuckets['< 100ms'] = (latencyBuckets['< 100ms'] ?? 0) + 1;
        } else if (latency <= 250) {
          latencyBuckets['100-250ms'] =
              (latencyBuckets['100-250ms'] ?? 0) + 1;
        } else if (latency <= 500) {
          latencyBuckets['250-500ms'] =
              (latencyBuckets['250-500ms'] ?? 0) + 1;
        } else if (latency <= 1000) {
          latencyBuckets['500ms-1s'] = (latencyBuckets['500ms-1s'] ?? 0) + 1;
        } else {
          latencyBuckets['> 1s'] = (latencyBuckets['> 1s'] ?? 0) + 1;
        }
      }

      final dollarSlippage = trade.dollarSlippage;
      final slippageBps = trade.effectiveSlippageBps;
      final multiplier = trade.orderType == 'option' ? 100 : 1;
      final cost = dollarSlippage * trade.copiedQuantity * multiplier;

      totalSlippageDollarSum += dollarSlippage;
      totalSlippageBpsSum += slippageBps;
      totalSlippageCostSum += cost;

      if (trade.executedPrice != null || trade.priceSlippage != null) {
        tradesWithSlippageCount++;
      }

      if (trade.isFavorableSlippage) {
        favorableCount++;
      } else if (trade.isUnfavorableSlippage) {
        unfavorableCount++;
      } else {
        neutralCount++;
      }
    }

    latencies.sort();
    final avgLatency =
        latencies.isNotEmpty ? latencies.reduce((a, b) => a + b) / latencies.length : 0.0;
    final medianLatency = latencies.isNotEmpty
        ? (latencies.length % 2 == 1
            ? latencies[latencies.length ~/ 2].toDouble()
            : (latencies[latencies.length ~/ 2 - 1] +
                    latencies[latencies.length ~/ 2]) /
                2.0)
        : 0.0;
    final minLatency = latencies.isNotEmpty ? latencies.first : 0;
    final maxLatency = latencies.isNotEmpty ? latencies.last : 0;

    final avgSlippageDollar = totalExecuted > 0
        ? totalSlippageDollarSum / totalExecuted
        : 0.0;
    final avgSlippageBps =
        totalExecuted > 0 ? totalSlippageBpsSum / totalExecuted : 0.0;

    final qualityScore = totalExecuted > 0
        ? ((favorableCount + neutralCount) / totalExecuted) * 100.0
        : 100.0;

    // Per-trader metrics
    final byTrader = <String, TraderSlippageSummary>{};
    for (final entry in traderGroups.entries) {
      final tId = entry.key;
      final tTrades = entry.value;
      final tLatencies = tTrades
          .map((t) => t.effectiveFillLatencyMs)
          .whereType<int>()
          .toList();
      final tAvgLatency = tLatencies.isNotEmpty
          ? tLatencies.reduce((a, b) => a + b) / tLatencies.length
          : 0.0;
      final tAvgBps = tTrades.isNotEmpty
          ? tTrades.map((t) => t.effectiveSlippageBps).reduce((a, b) => a + b) /
              tTrades.length
          : 0.0;
      final tCost = tTrades.fold<double>(
          0.0,
          (sum, t) =>
              sum +
              (t.dollarSlippage *
                  t.copiedQuantity *
                  (t.orderType == 'option' ? 100 : 1)));
      final tFavorable = tTrades.where((t) => t.isFavorableSlippage).length;
      final tNeutral = tTrades.where((t) => t.isZeroSlippage).length;
      final tQuality = tTrades.isNotEmpty
          ? ((tFavorable + tNeutral) / tTrades.length) * 100.0
          : 100.0;

      byTrader[tId] = TraderSlippageSummary(
        traderId: tId,
        totalTrades: tTrades.length,
        averageLatencyMs: tAvgLatency,
        averageSlippageBps: tAvgBps,
        totalSlippageCost: tCost,
        executionQualityScore: tQuality,
      );
    }

    // Per-asset class metrics
    final byAssetClass = <String, AssetClassSlippageSummary>{};
    for (final entry in assetGroups.entries) {
      final asset = entry.key;
      final aTrades = entry.value;
      final aLatencies = aTrades
          .map((t) => t.effectiveFillLatencyMs)
          .whereType<int>()
          .toList();
      final aAvgLatency = aLatencies.isNotEmpty
          ? aLatencies.reduce((a, b) => a + b) / aLatencies.length
          : 0.0;
      final aAvgBps = aTrades.isNotEmpty
          ? aTrades.map((t) => t.effectiveSlippageBps).reduce((a, b) => a + b) /
              aTrades.length
          : 0.0;
      final aCost = aTrades.fold<double>(
          0.0,
          (sum, t) =>
              sum +
              (t.dollarSlippage *
                  t.copiedQuantity *
                  (t.orderType == 'option' ? 100 : 1)));
      final aFavorable = aTrades.where((t) => t.isFavorableSlippage).length;
      final aNeutral = aTrades.where((t) => t.isZeroSlippage).length;
      final aQuality = aTrades.isNotEmpty
          ? ((aFavorable + aNeutral) / aTrades.length) * 100.0
          : 100.0;

      byAssetClass[asset] = AssetClassSlippageSummary(
        assetClass: asset,
        totalTrades: aTrades.length,
        averageLatencyMs: aAvgLatency,
        averageSlippageBps: aAvgBps,
        totalSlippageCost: aCost,
        executionQualityScore: aQuality,
      );
    }

    // Net return divergence calculation
    double? avgLeaderReturn;
    double? avgFollowerReturn;
    double? netReturnDivergence;

    final tradesWithDivergence = executedTradesList
        .where((t) => t.leaderReturnPct != null && t.followerReturnPct != null)
        .toList();

    if (tradesWithDivergence.isNotEmpty) {
      avgLeaderReturn = tradesWithDivergence
              .map((t) => t.leaderReturnPct!)
              .reduce((a, b) => a + b) /
          tradesWithDivergence.length;
      avgFollowerReturn = tradesWithDivergence
              .map((t) => t.followerReturnPct!)
              .reduce((a, b) => a + b) /
          tradesWithDivergence.length;
      netReturnDivergence = avgFollowerReturn - avgLeaderReturn;
    }

    return CopyTradeSlippageSummary(
      totalTrades: trades.length,
      executedTrades: totalExecuted,
      tradesWithSlippage: tradesWithSlippageCount,
      averageLatencyMs: avgLatency,
      medianLatencyMs: medianLatency,
      minLatencyMs: minLatency,
      maxLatencyMs: maxLatency,
      averageSlippageDollar: avgSlippageDollar,
      averageSlippageBps: avgSlippageBps,
      totalSlippageCost: totalSlippageCostSum,
      favorableTradesCount: favorableCount,
      unfavorableTradesCount: unfavorableCount,
      neutralTradesCount: neutralCount,
      executionQualityScore: qualityScore,
      averageLeaderReturnPct: avgLeaderReturn,
      averageFollowerReturnPct: avgFollowerReturn,
      netReturnDivergencePct: netReturnDivergence,
      byTrader: byTrader,
      byAssetClass: byAssetClass,
      latencyBuckets: latencyBuckets,
    );
  }
}
