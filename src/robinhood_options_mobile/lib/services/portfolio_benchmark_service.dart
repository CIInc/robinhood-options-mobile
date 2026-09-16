import 'package:flutter/foundation.dart';
import 'package:robinhood_options_mobile/model/portfolio_historicals.dart';

/// Portfolio return versus a benchmark over the same aligned window.
@immutable
class BenchmarkComparison {
  final String symbol;
  final double portfolioReturn;
  final double benchmarkReturn;

  const BenchmarkComparison({
    required this.symbol,
    required this.portfolioReturn,
    required this.benchmarkReturn,
  });

  double get excessReturn => portfolioReturn - benchmarkReturn;
  bool get isTrailing => excessReturn < 0;
}

/// Computes the single benchmark number the Portfolio hero needs.
///
/// The full analytics suite in `PortfolioAnalyticsWidget` produces this too, but
/// only once the user opens the Performance section. The overview needs the
/// comparison on first paint, so this does the minimum work: align the two
/// series on trading days, then take the first-to-last cumulative return of
/// each.
class PortfolioBenchmarkService {
  static Future<BenchmarkComparison?> compare({
    required Future<PortfolioHistoricals>? portfolioHistoricalsFuture,
    required Future<dynamic>? benchmarkHistoricalsFuture,
    String symbol = 'SPY',
  }) async {
    if (portfolioHistoricalsFuture == null ||
        benchmarkHistoricalsFuture == null) {
      return null;
    }

    try {
      final results = await Future.wait([
        portfolioHistoricalsFuture,
        benchmarkHistoricalsFuture,
      ]);
      final historicals = results[0] as PortfolioHistoricals;
      final benchmarkByDate = _parseBenchmark(results[1]);
      if (benchmarkByDate.isEmpty) return null;

      final portfolioPrices = <double>[];
      final benchmarkPrices = <double>[];
      for (final historical in historicals.equityHistoricals) {
        final beginsAt = historical.beginsAt;
        if (beginsAt == null) continue;
        final equity =
            historical.adjustedCloseEquity ?? historical.closeEquity ?? 0.0;
        if (equity == 0) continue;

        final benchmark = benchmarkByDate[_dateKey(beginsAt)];
        if (benchmark == null) continue;

        portfolioPrices.add(equity);
        benchmarkPrices.add(benchmark);
      }

      if (portfolioPrices.length < 2) return null;

      return BenchmarkComparison(
        symbol: symbol,
        portfolioReturn: _cumulativeReturn(portfolioPrices),
        benchmarkReturn: _cumulativeReturn(benchmarkPrices),
      );
    } catch (e) {
      debugPrint('Error comparing portfolio to $symbol: $e');
      return null;
    }
  }

  static Map<String, double> _parseBenchmark(dynamic data) {
    final byDate = <String, double>{};
    if (data == null) return byDate;

    final result = data['chart']?['result']?[0];
    if (result == null) return byDate;

    final timestamps = result['timestamp'] as List?;
    final adjcloses =
        result['indicators']?['adjclose']?[0]?['adjclose'] as List?;
    if (timestamps == null || adjcloses == null) return byDate;

    for (var i = 0; i < timestamps.length && i < adjcloses.length; i++) {
      final close = adjcloses[i];
      if (close == null) continue;
      final date =
          DateTime.fromMillisecondsSinceEpoch((timestamps[i] as int) * 1000);
      byDate[_dateKey(date)] = (close as num).toDouble();
    }
    return byDate;
  }

  static String _dateKey(DateTime date) =>
      date.toIso8601String().split('T').first;

  static double _cumulativeReturn(List<double> prices) {
    final first = prices.first;
    if (first == 0) return 0;
    return (prices.last - first) / first;
  }
}
