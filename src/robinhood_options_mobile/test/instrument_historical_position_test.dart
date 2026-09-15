import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/instrument_historical_position.dart';
import 'package:robinhood_options_mobile/model/instrument_order.dart';

InstrumentOrder _createOrder({
  required String id,
  required String side,
  required double quantity,
  required double price,
  required DateTime createdAt,
  String state = 'filled',
  String instrumentId = 'inst_aapl_123',
}) {
  return InstrumentOrder(
    id,
    'ref_$id',
    'https://api.robinhood.com/orders/$id/',
    'https://api.robinhood.com/accounts/ACC123/',
    'https://api.robinhood.com/positions/ACC123/$instrumentId/',
    null,
    'https://api.robinhood.com/instruments/$instrumentId/',
    instrumentId,
    quantity,
    price,
    0.0,
    state,
    null,
    'market',
    side,
    'gtc',
    'immediate',
    price,
    null,
    quantity,
    null,
    createdAt,
    createdAt,
    null,
  );
}

void main() {
  group('InstrumentCostBasisLookbackSummary FIFO Calculation Tests', () {
    test('returns empty summary when orders list is empty', () {
      final summary = InstrumentCostBasisLookbackSummary.fromOrders([]);

      expect(summary.cycles, isEmpty);
      expect(summary.closedCycles, isEmpty);
      expect(summary.hasHistory, isFalse);
      expect(summary.totalRealizedGainLoss, 0.0);
      expect(summary.totalRoundTrips, 0);
      expect(summary.winRate, 0.0);
      expect(summary.averageHoldDuration, Duration.zero);
    });

    test('reconstructs single profitable round-trip correctly', () {
      final buyDate = DateTime(2025, 1, 10, 10, 0);
      final sellDate = DateTime(
        2025,
        1,
        25,
        14,
        30,
      ); // 15 days, 4.5 hours later

      final orders = [
        _createOrder(
          id: 'ord_1',
          side: 'buy',
          quantity: 10.0,
          price: 150.0,
          createdAt: buyDate,
        ),
        _createOrder(
          id: 'ord_2',
          side: 'sell',
          quantity: 10.0,
          price: 180.0,
          createdAt: sellDate,
        ),
      ];

      final summary = InstrumentCostBasisLookbackSummary.fromOrders(
        orders,
        symbol: 'AAPL',
      );

      expect(summary.hasHistory, isTrue);
      expect(summary.totalRoundTrips, 1);
      expect(summary.closedCycles.length, 1);

      final cycle = summary.closedCycles.first;
      expect(cycle.isClosed, isTrue);
      expect(cycle.totalShares, 10.0);
      expect(cycle.totalCostBasis, 1500.0);
      expect(cycle.averageBuyPrice, 150.0);
      expect(cycle.totalProceeds, 1800.0);
      expect(cycle.averageSellPrice, 180.0);
      expect(cycle.realizedGainLoss, 300.0);
      expect(cycle.realizedGainLossPercent, closeTo(0.20, 0.0001));
      expect(cycle.isProfitable, isTrue);
      expect(cycle.isLoss, isFalse);
      expect(cycle.holdDuration.inDays, 15);
      expect(cycle.formattedHoldDuration, '15 days');

      expect(summary.totalRealizedGainLoss, 300.0);
      expect(summary.winningTradesCount, 1);
      expect(summary.losingTradesCount, 0);
      expect(summary.winRate, 1.0);
      expect(summary.overallAverageBuyPrice, 150.0);
      expect(summary.overallAverageSellPrice, 180.0);
    });

    test('reconstructs multiple round-trips with multi-lot buys and sells', () {
      // Cycle 1: Buy 10 @ $100, Buy 10 @ $120 (Avg: $110, Cost: $2200)
      //          Sell 20 @ $130 (Proceeds: $2600, Gain: +$400)
      // Cycle 2: Buy 50 @ $200 (Cost: $10000)
      //          Sell 25 @ $190, Sell 25 @ $170 (Proceeds: $9000, Loss: -$1000)
      final d1 = DateTime(2025, 2, 1);
      final d2 = DateTime(2025, 2, 5);
      final d3 = DateTime(2025, 2, 20);

      final d4 = DateTime(2025, 3, 1);
      final d5 = DateTime(2025, 3, 10);
      final d6 = DateTime(2025, 3, 15);

      final orders = [
        _createOrder(
          id: 'o1',
          side: 'buy',
          quantity: 10,
          price: 100,
          createdAt: d1,
        ),
        _createOrder(
          id: 'o2',
          side: 'buy',
          quantity: 10,
          price: 120,
          createdAt: d2,
        ),
        _createOrder(
          id: 'o3',
          side: 'sell',
          quantity: 20,
          price: 130,
          createdAt: d3,
        ),
        _createOrder(
          id: 'o4',
          side: 'buy',
          quantity: 50,
          price: 200,
          createdAt: d4,
        ),
        _createOrder(
          id: 'o5',
          side: 'sell',
          quantity: 25,
          price: 190,
          createdAt: d5,
        ),
        _createOrder(
          id: 'o6',
          side: 'sell',
          quantity: 25,
          price: 170,
          createdAt: d6,
        ),
      ];

      final summary = InstrumentCostBasisLookbackSummary.fromOrders(orders);

      expect(summary.totalRoundTrips, 2);
      expect(summary.closedCycles.length, 2);

      // Cycle 1
      final c1 = summary.closedCycles[0];
      expect(c1.totalShares, 20);
      expect(c1.averageBuyPrice, 110.0);
      expect(c1.averageSellPrice, 130.0);
      expect(c1.realizedGainLoss, 400.0);
      expect(c1.isProfitable, isTrue);

      // Cycle 2
      final c2 = summary.closedCycles[1];
      expect(c2.totalShares, 50);
      expect(c2.averageBuyPrice, 200.0);
      expect(c2.averageSellPrice, 180.0);
      expect(c2.realizedGainLoss, -1000.0);
      expect(c2.isLoss, isTrue);

      // Summary
      expect(summary.totalRealizedGainLoss, -600.0);
      expect(summary.winningTradesCount, 1);
      expect(summary.losingTradesCount, 1);
      expect(summary.winRate, 0.5);
      expect(
        summary.totalSharesTraded,
        140.0,
      ); // (20 buy + 20 sell) + (50 buy + 50 sell)
    });

    test('handles fractional shares with precision', () {
      final t1 = DateTime(2025, 4, 1);
      final t2 = DateTime(2025, 4, 5);
      final t3 = DateTime(2025, 4, 10);

      final orders = [
        _createOrder(
          id: 'f1',
          side: 'buy',
          quantity: 1.5,
          price: 200,
          createdAt: t1,
        ),
        _createOrder(
          id: 'f2',
          side: 'sell',
          quantity: 0.5,
          price: 250,
          createdAt: t2,
        ),
        _createOrder(
          id: 'f3',
          side: 'sell',
          quantity: 1.0,
          price: 220,
          createdAt: t3,
        ),
      ];

      final summary = InstrumentCostBasisLookbackSummary.fromOrders(orders);

      expect(summary.totalRoundTrips, 1);
      final cycle = summary.closedCycles.first;
      expect(cycle.totalShares, 1.5);
      expect(cycle.totalCostBasis, 300.0);
      expect(
        cycle.totalProceeds,
        345.0,
      ); // (0.5 * 250 = 125) + (1.0 * 220 = 220) = 345
      expect(cycle.realizedGainLoss, 45.0);
      expect(cycle.realizedGainLossPercent, closeTo(0.15, 0.001));
    });

    test('handles active unclosed position alongside closed round trips', () {
      final t1 = DateTime(2025, 5, 1);
      final t2 = DateTime(2025, 5, 10);
      final t3 = DateTime(2025, 6, 1);

      final orders = [
        // Completed round trip
        _createOrder(
          id: 'c1',
          side: 'buy',
          quantity: 10,
          price: 50,
          createdAt: t1,
        ),
        _createOrder(
          id: 'c2',
          side: 'sell',
          quantity: 10,
          price: 60,
          createdAt: t2,
        ),
        // Active position still open
        _createOrder(
          id: 'a1',
          side: 'buy',
          quantity: 25,
          price: 65,
          createdAt: t3,
        ),
      ];

      final summary = InstrumentCostBasisLookbackSummary.fromOrders(orders);

      expect(summary.cycles.length, 2);
      expect(summary.closedCycles.length, 1);
      expect(summary.totalRoundTrips, 1);
      expect(summary.totalRealizedGainLoss, 100.0);

      final activeCycle = summary.cycles.last;
      expect(activeCycle.isClosed, isFalse);
      expect(activeCycle.totalShares, 25.0);
      expect(activeCycle.averageBuyPrice, 65.0);
      expect(activeCycle.closedAt, isNull);
    });

    test('ignores non-filled or cancelled orders', () {
      final orders = [
        _createOrder(
          id: 'o_cancelled',
          side: 'buy',
          quantity: 10,
          price: 100,
          createdAt: DateTime(2025, 1, 1),
          state: 'cancelled',
        ),
        _createOrder(
          id: 'o_filled_buy',
          side: 'buy',
          quantity: 5,
          price: 100,
          createdAt: DateTime(2025, 1, 2),
          state: 'filled',
        ),
        _createOrder(
          id: 'o_filled_sell',
          side: 'sell',
          quantity: 5,
          price: 110,
          createdAt: DateTime(2025, 1, 3),
          state: 'filled',
        ),
      ];

      final summary = InstrumentCostBasisLookbackSummary.fromOrders(orders);
      expect(summary.totalRoundTrips, 1);
      expect(summary.closedCycles.first.totalShares, 5);
      expect(summary.closedCycles.first.realizedGainLoss, 50.0);
    });

    test('correctly adjusts for forward stock split (e.g. 10-for-1)', () {
      final buyDate = DateTime(2024, 5, 1, 10, 0);
      final splitDate = DateTime(2024, 6, 10);
      final sellDate = DateTime(2024, 7, 1, 14, 0);

      final orders = [
        _createOrder(
          id: 'buy_presplit',
          side: 'buy',
          quantity: 10.0,
          price: 1000.0,
          createdAt: buyDate,
        ),
        _createOrder(
          id: 'sell_postsplit',
          side: 'sell',
          quantity: 100.0,
          price: 120.0,
          createdAt: sellDate,
        ),
      ];

      final rawSplits = [
        {
          'execution_date': '2024-06-10',
          'multiplier': '10.00000000',
          'divisor': '1.00000000',
        },
      ];

      final summary = InstrumentCostBasisLookbackSummary.fromOrders(
        orders,
        symbol: 'NVDA',
        splits: rawSplits,
      );

      expect(summary.hasSplits, isTrue);
      expect(summary.totalRoundTrips, 1);
      expect(summary.closedCycles.length, 1);

      final cycle = summary.closedCycles.first;
      expect(cycle.isClosed, isTrue);
      expect(cycle.hasSplits, isTrue);
      expect(cycle.splitsApplied.length, 1);
      expect(cycle.splitsApplied.first.formattedRatio, '10 for 1 Split');
      expect(cycle.splitsApplied.first.shortRatioBadge, '10:1 Split');
      expect(cycle.splitsApplied.first.executionDate, splitDate);

      // 10 pre-split shares become 100 post-split shares
      expect(cycle.totalShares, 100.0);
      // Cost basis remains $10,000 (10 * $1000)
      expect(cycle.totalCostBasis, 10000.0);
      // Split-adjusted buy price is $1000 / 10 = $100
      expect(cycle.averageBuyPrice, 100.0);
      // Proceeds from selling 100 @ $120 = $12,000
      expect(cycle.totalProceeds, 12000.0);
      expect(cycle.averageSellPrice, 120.0);
      // Realized P&L is $12,000 - $10,000 = +$2,000 (+20%)
      expect(cycle.realizedGainLoss, 2000.0);
      expect(cycle.realizedGainLossPercent, closeTo(0.20, 0.0001));
      expect(cycle.isProfitable, isTrue);

      // Summary-level overall averages should also be split-adjusted
      // Buy: $10,000 cost / 100 split-adjusted shares = $100
      expect(summary.overallAverageBuyPrice, 100.0);
      // Sell: $12,000 proceeds / 100 shares = $120
      expect(summary.overallAverageSellPrice, 120.0);
    });

    test('correctly adjusts for reverse stock split (e.g. 1-for-5)', () {
      final buyDate = DateTime(2025, 1, 15, 11, 0);
      final splitDate = DateTime(2025, 2, 1);
      final sellDate = DateTime(2025, 3, 1, 15, 0);

      final orders = [
        _createOrder(
          id: 'buy_rev_pre',
          side: 'buy',
          quantity: 100.0,
          price: 2.0,
          createdAt: buyDate,
        ),
        _createOrder(
          id: 'sell_rev_post',
          side: 'sell',
          quantity: 20.0,
          price: 15.0,
          createdAt: sellDate,
        ),
      ];

      final splits = [
        StockSplit(executionDate: splitDate, multiplier: 1.0, divisor: 5.0),
      ];

      final summary = InstrumentCostBasisLookbackSummary.fromOrders(
        orders,
        symbol: 'MULL',
        splits: splits,
      );

      expect(summary.totalRoundTrips, 1);
      final cycle = summary.closedCycles.first;
      expect(cycle.hasSplits, isTrue);
      expect(cycle.splitsApplied.first.isReverseSplit, isTrue);
      expect(cycle.splitsApplied.first.formattedRatio, '1 for 5 Reverse Split');
      expect(cycle.splitsApplied.first.shortRatioBadge, '1:5 Rev Split');

      // 100 pre-split shares became 20 shares
      expect(cycle.totalShares, 20.0);
      // Cost basis is $200 (100 * $2)
      expect(cycle.totalCostBasis, 200.0);
      // Split-adjusted buy price is $2 / 0.2 = $10
      expect(cycle.averageBuyPrice, 10.0);
      // Proceeds from selling 20 @ $15 = $300
      expect(cycle.totalProceeds, 300.0);
      expect(cycle.averageSellPrice, 15.0);
      // Realized P&L is $300 - $200 = +$100 (+50%)
      expect(cycle.realizedGainLoss, 100.0);
      expect(cycle.realizedGainLossPercent, closeTo(0.50, 0.0001));

      // Summary-level overall averages should be split-adjusted
      // Buy: $200 cost / 20 split-adjusted shares = $10
      expect(summary.overallAverageBuyPrice, 10.0);
      // Sell: $300 proceeds / 20 shares = $15
      expect(summary.overallAverageSellPrice, 15.0);
    });

    test('preserves cycles executed entirely before a stock split', () {
      final preSplitBuy = DateTime(2023, 1, 10);
      final preSplitSell = DateTime(2023, 1, 20);
      final splitDate = DateTime(2024, 6, 10);
      final postSplitBuy = DateTime(2024, 7, 1);
      final postSplitSell = DateTime(2024, 7, 10);

      final orders = [
        // Cycle 1: Completed in 2023 before the 2024 split
        _createOrder(
          id: 'c1_b',
          side: 'buy',
          quantity: 10,
          price: 100,
          createdAt: preSplitBuy,
        ),
        _createOrder(
          id: 'c1_s',
          side: 'sell',
          quantity: 10,
          price: 150,
          createdAt: preSplitSell,
        ),
        // Cycle 2: Executed post-split in 2024
        _createOrder(
          id: 'c2_b',
          side: 'buy',
          quantity: 40,
          price: 30,
          createdAt: postSplitBuy,
        ),
        _createOrder(
          id: 'c2_s',
          side: 'sell',
          quantity: 40,
          price: 35,
          createdAt: postSplitSell,
        ),
      ];

      final splits = [
        StockSplit(executionDate: splitDate, multiplier: 4.0, divisor: 1.0),
      ];

      final summary = InstrumentCostBasisLookbackSummary.fromOrders(
        orders,
        splits: splits,
      );

      expect(summary.totalRoundTrips, 2);
      // Cycle 1 had no splits applied during its holding period
      expect(summary.closedCycles[0].hasSplits, isFalse);
      expect(summary.closedCycles[0].totalShares, 10.0);
      expect(summary.closedCycles[0].realizedGainLoss, 500.0);

      // Cycle 2 opened after the split, so no split occurred while holding
      expect(summary.closedCycles[1].hasSplits, isFalse);
      expect(summary.closedCycles[1].totalShares, 40.0);
      expect(summary.closedCycles[1].realizedGainLoss, 200.0);

      expect(summary.totalRealizedGainLoss, 700.0);
    });
  });
}
