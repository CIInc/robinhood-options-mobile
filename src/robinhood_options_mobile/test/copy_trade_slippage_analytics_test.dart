import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/copy_trade_record.dart';
import 'package:robinhood_options_mobile/model/copy_trade_slippage_analytics.dart';

void main() {
  group('CopyTradeSlippageAnalytics Tests', () {
    final now = DateTime(2026, 9, 22, 10, 0, 0);

    test('should return default summary for empty trades list', () {
      final summary = CopyTradeSlippageAnalytics.compute(trades: []);
      expect(summary.totalTrades, 0);
      expect(summary.executedTrades, 0);
      expect(summary.averageLatencyMs, 0.0);
      expect(summary.averageSlippageDollar, 0.0);
      expect(summary.totalSlippageCost, 0.0);
      expect(summary.executionQualityScore, 100.0);
      expect(summary.byTrader, isEmpty);
      expect(summary.byAssetClass, isEmpty);
    });

    test('should compute latency and slippage accurately for mixed trades', () {
      final trades = [
        // Trade 1: Fast, small favorable slippage (Buy at 99.90 vs leader 100.00)
        CopyTradeRecord(
          id: 't1',
          sourceUserId: 'trader-alice',
          targetUserId: 'user-me',
          groupId: 'grp-1',
          orderType: 'instrument',
          originalOrderId: 'o1',
          symbol: 'AAPL',
          side: 'buy',
          originalQuantity: 10,
          copiedQuantity: 10,
          price: 100.0,
          timestamp: now,
          executed: true,
          executionTime: now.add(const Duration(milliseconds: 50)),
          executedPrice: 99.90, // -$0.10 favorable
          fillLatencyMs: 50,
          leaderReturnPct: 0.05,
          followerReturnPct: 0.052,
        ),
        // Trade 2: Medium latency, unfavorable slippage (Buy at 201.00 vs leader 200.00)
        CopyTradeRecord(
          id: 't2',
          sourceUserId: 'trader-alice',
          targetUserId: 'user-me',
          groupId: 'grp-1',
          orderType: 'instrument',
          originalOrderId: 'o2',
          symbol: 'MSFT',
          side: 'buy',
          originalQuantity: 5,
          copiedQuantity: 5,
          price: 200.0,
          timestamp: now,
          executed: true,
          executionTime: now.add(const Duration(milliseconds: 150)),
          executedPrice: 201.00, // +$1.00 unfavorable
          fillLatencyMs: 150,
          leaderReturnPct: 0.08,
          followerReturnPct: 0.075,
        ),
        // Trade 3: Option trade with 100x multiplier, exact fill (zero slippage)
        CopyTradeRecord(
          id: 't3',
          sourceUserId: 'trader-bob',
          targetUserId: 'user-me',
          groupId: 'grp-1',
          orderType: 'option',
          originalOrderId: 'o3',
          symbol: 'NVDA',
          side: 'buy',
          originalQuantity: 1,
          copiedQuantity: 1,
          price: 5.0,
          timestamp: now,
          executed: true,
          executionTime: now.add(const Duration(milliseconds: 300)),
          executedPrice: 5.0, // exact fill
          fillLatencyMs: 300,
        ),
      ];

      final summary = CopyTradeSlippageAnalytics.compute(trades: trades);

      expect(summary.totalTrades, 3);
      expect(summary.executedTrades, 3);
      // Latencies: 50, 150, 300 -> avg = 500 / 3 = 166.67
      expect(summary.averageLatencyMs, closeTo(166.67, 0.1));
      expect(summary.medianLatencyMs, 150.0);
      expect(summary.minLatencyMs, 50);
      expect(summary.maxLatencyMs, 300);

      // Latency buckets
      expect(summary.latencyBuckets['< 100ms'], 1);
      expect(summary.latencyBuckets['100-250ms'], 1);
      expect(summary.latencyBuckets['250-500ms'], 1);
      expect(summary.latencyBuckets['500ms-1s'], 0);
      expect(summary.latencyBuckets['> 1s'], 0);

      // Slippage quality
      expect(summary.favorableTradesCount, 1);
      expect(summary.unfavorableTradesCount, 1);
      expect(summary.neutralTradesCount, 1);
      // (1 favorable + 1 neutral) / 3 = 66.67%
      expect(summary.executionQualityScore, closeTo(66.67, 0.1));

      // Dollar slippage cost:
      // t1: -0.10 * 10 * 1 = -$1.00
      // t2: +1.00 * 5 * 1 = +$5.00
      // t3: 0.0 * 1 * 100 = $0.00
      // Total cost = $4.00
      expect(summary.totalSlippageCost, closeTo(4.00, 0.001));

      // Per-trader breakdown
      expect(summary.byTrader.containsKey('trader-alice'), true);
      expect(summary.byTrader.containsKey('trader-bob'), true);

      final alice = summary.byTrader['trader-alice']!;
      expect(alice.totalTrades, 2);
      expect(alice.averageLatencyMs, 100.0);
      expect(alice.totalSlippageCost, closeTo(4.00, 0.001));

      final bob = summary.byTrader['trader-bob']!;
      expect(bob.totalTrades, 1);
      expect(bob.averageLatencyMs, 300.0);
      expect(bob.totalSlippageCost, 0.0);
      expect(bob.executionQualityScore, 100.0);

      // Asset class breakdown
      expect(summary.byAssetClass.containsKey('instrument'), true);
      expect(summary.byAssetClass.containsKey('option'), true);
      expect(summary.byAssetClass['instrument']!.totalTrades, 2);
      expect(summary.byAssetClass['option']!.totalTrades, 1);

      // Return divergence:
      // t1: leader 0.05, follower 0.052 (+0.002)
      // t2: leader 0.08, follower 0.075 (-0.005)
      // avg leader = 0.065, avg follower = 0.0635 -> net divergence = -0.0015
      expect(summary.averageLeaderReturnPct, closeTo(0.065, 0.0001));
      expect(summary.averageFollowerReturnPct, closeTo(0.0635, 0.0001));
      expect(summary.netReturnDivergencePct, closeTo(-0.0015, 0.0001));
    });
  });
}
