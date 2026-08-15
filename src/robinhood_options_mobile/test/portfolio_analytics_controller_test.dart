import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/equity_historical.dart';
import 'package:robinhood_options_mobile/model/portfolio_analytics_controller.dart';
import 'package:robinhood_options_mobile/model/portfolio_historicals.dart';

/// Builds portfolio historicals whose closes follow [closes], one trading day
/// apart starting 2026-01-05.
///
/// Timestamps are local mid-day rather than midnight UTC: the controller keys
/// the two series by calendar date, and Yahoo timestamps deserialize to local
/// time, so a midnight fixture would straddle the date boundary in any
/// timezone behind UTC.
PortfolioHistoricals buildHistoricals(
  List<double> closes, {
  String span = 'year',
  DateTime? start,
}) {
  final first = start ?? DateTime(2026, 1, 5, 12);
  return PortfolioHistoricals(
    closes.first,
    closes.first,
    closes.first,
    closes.first,
    null,
    'day',
    span,
    'regular',
    0,
    [
      for (var i = 0; i < closes.length; i++)
        EquityHistorical(
          closes[i],
          closes[i],
          closes[i],
          closes[i],
          closes[i],
          closes[i],
          first.add(Duration(days: i)),
          0,
          'reg',
        ),
    ],
    false,
  );
}

/// Mimics the Yahoo chart payload the controller parses.
Map<String, dynamic> buildBenchmarkPayload(
  List<double> closes, {
  DateTime? start,
}) {
  final first = start ?? DateTime(2026, 1, 5, 12);
  return {
    'chart': {
      'result': [
        {
          'timestamp': [
            for (var i = 0; i < closes.length; i++)
              first.add(Duration(days: i)).millisecondsSinceEpoch ~/ 1000,
          ],
          'indicators': {
            'adjclose': [
              {'adjclose': closes},
            ],
          },
        },
      ],
    },
  };
}

void main() {
  group('PortfolioAnalyticsController', () {
    test('yields no metrics without historicals', () async {
      final controller = PortfolioAnalyticsController();
      await controller.ensureLoaded();

      expect(controller.hasMetrics, isFalse);
      expect(controller.metrics, isEmpty);
      expect(controller.error, isNull);
    });

    test('yields no metrics when the benchmark never overlaps', () async {
      final controller = PortfolioAnalyticsController(
        portfolioHistoricalsFuture:
            Future.value(buildHistoricals([100, 101, 102, 103])),
        benchmarkHistoricals: {
          // A year later, so no trading day aligns.
          'SPY': Future.value(buildBenchmarkPayload([100, 101, 102, 103],
              start: DateTime(2027, 1, 5, 12))),
        },
      );
      await controller.ensureLoaded();

      expect(controller.hasMetrics, isFalse);
    });

    test('computes excess return against the benchmark', () async {
      final controller = PortfolioAnalyticsController(
        // Portfolio +20%, benchmark +10% over the same window.
        portfolioHistoricalsFuture:
            Future.value(buildHistoricals([100, 105, 110, 120])),
        benchmarkHistoricals: {
          'SPY': Future.value(buildBenchmarkPayload([100, 103, 106, 110])),
        },
      );
      await controller.ensureLoaded();

      expect(controller.hasMetrics, isTrue);
      expect(controller.metrics['excessReturn'], closeTo(0.10, 0.001));
      expect(controller.metrics['benchmarkSymbol'], 'SPY');
      expect(controller.metrics['periodDays'], 3);
    });

    test('exposes the aligned series the CSV export needs', () async {
      final controller = PortfolioAnalyticsController(
        portfolioHistoricalsFuture:
            Future.value(buildHistoricals([100, 105, 110, 120])),
        benchmarkHistoricals: {
          'SPY': Future.value(buildBenchmarkPayload([100, 103, 106, 110])),
        },
      );
      await controller.ensureLoaded();

      expect(controller.metrics['alignedDates'], hasLength(4));
      expect(controller.metrics['alignedPortfolioPrices'],
          [100.0, 105.0, 110.0, 120.0]);
      expect(controller.metrics['alignedBenchmarkPrices'],
          [100.0, 103.0, 106.0, 110.0]);
    });

    test('exposes rolling volatility, beta, and correlation', () async {
      final portfolio = List<double>.generate(
          35, (i) => 100.0 * (1 + i * 0.002 + (i.isEven ? 0.001 : -0.001)));
      final benchmark = List<double>.generate(35, (i) => 100.0 + i * 0.1);
      final controller = PortfolioAnalyticsController(
        portfolioHistoricalsFuture: Future.value(buildHistoricals(portfolio)),
        benchmarkHistoricals: {
          'SPY': Future.value(buildBenchmarkPayload(benchmark)),
        },
      );
      await controller.ensureLoaded();

      final rolling =
          controller.metrics['rollingStatistics'] as List<Map<String, dynamic>>;
      expect(rolling, hasLength(5));
      expect(rolling.first['date'], DateTime(2026, 2, 4, 12));
      expect(rolling.first['volatility'], greaterThan(0));
      expect(rolling.first['beta'], isA<double>());
      expect(rolling.first['correlation'], isA<double>());
      expect(rolling.first['maxDrawdown'], isA<double>());
    });

    test('groups monthly returns by year and month', () async {
      // 5 Jan through 5 Mar, so the series spans three calendar months.
      final closes = List<double>.generate(60, (i) => 100.0 + i);
      final controller = PortfolioAnalyticsController(
        portfolioHistoricalsFuture: Future.value(buildHistoricals(closes)),
        benchmarkHistoricals: {
          'SPY': Future.value(buildBenchmarkPayload(closes)),
        },
      );
      await controller.ensureLoaded();

      final monthly =
          controller.metrics['monthlyReturns'] as Map<int, Map<int, double>>;
      expect(monthly.keys, [2026]);
      expect(monthly[2026]!.keys, containsAll([1, 2, 3]));
      // A rising series produces a positive return every month.
      expect(monthly[2026]!.values.every((value) => value > 0), isTrue);
    });

    test('ensureLoaded computes once, refresh recomputes', () async {
      var awaited = 0;
      Future<PortfolioHistoricals> historicals() async {
        awaited++;
        return buildHistoricals([100, 105, 110, 120]);
      }

      // A single future is awaited repeatedly, so count controller passes via
      // notifications rather than future creation.
      final controller = PortfolioAnalyticsController(
        portfolioHistoricalsFuture: historicals(),
        benchmarkHistoricals: {
          'SPY': Future.value(buildBenchmarkPayload([100, 103, 106, 110])),
        },
      );

      await controller.ensureLoaded();
      await controller.ensureLoaded();
      await controller.ensureLoaded();
      expect(awaited, 1);
      expect(controller.hasMetrics, isTrue);

      await controller.refresh();
      expect(controller.hasMetrics, isTrue);
    });

    test('switching benchmark recomputes against the new series', () async {
      final controller = PortfolioAnalyticsController(
        portfolioHistoricalsFuture:
            Future.value(buildHistoricals([100, 105, 110, 120])),
        benchmarkHistoricals: {
          'SPY': Future.value(buildBenchmarkPayload([100, 103, 106, 110])),
          // QQQ matches the portfolio exactly, so excess return goes to zero.
          'QQQ': Future.value(buildBenchmarkPayload([100, 105, 110, 120])),
        },
      );

      await controller.ensureLoaded();
      expect(controller.metrics['excessReturn'], closeTo(0.10, 0.001));

      await controller.selectBenchmark('QQQ');
      expect(controller.selectedBenchmark, 'QQQ');
      expect(controller.metrics['excessReturn'], closeTo(0.0, 0.001));
      expect(controller.metrics['benchmarkSymbol'], 'QQQ');
    });

    test('selecting the current benchmark is a no-op', () async {
      final controller = PortfolioAnalyticsController(
        portfolioHistoricalsFuture:
            Future.value(buildHistoricals([100, 105, 110, 120])),
        benchmarkHistoricals: {
          'SPY': Future.value(buildBenchmarkPayload([100, 103, 106, 110])),
        },
      );
      await controller.ensureLoaded();

      var notifications = 0;
      controller.addListener(() => notifications++);
      await controller.selectBenchmark('SPY');

      expect(notifications, 0);
    });

    test('falls back to the store historicals, preferring the year span',
        () async {
      final controller = PortfolioAnalyticsController(
        fallbackHistoricals: [
          buildHistoricals([100, 100, 100, 100], span: '3month'),
          buildHistoricals([100, 105, 110, 120], span: 'year'),
        ],
        benchmarkHistoricals: {
          'SPY': Future.value(buildBenchmarkPayload([100, 103, 106, 110])),
        },
      );
      await controller.ensureLoaded();

      // The year span was chosen, so the +20% series drove the metrics.
      expect(controller.metrics['excessReturn'], closeTo(0.10, 0.001));
    });

    test('a custom benchmark is added and selected', () async {
      final controller = PortfolioAnalyticsController(
        portfolioHistoricalsFuture:
            Future.value(buildHistoricals([100, 105, 110, 120])),
      );

      await controller.addCustomBenchmark('  btc-usd ');

      expect(controller.customBenchmarks, ['BTC-USD']);
      expect(controller.selectedBenchmark, 'BTC-USD');
      expect(controller.allBenchmarks, ['SPY', 'QQQ', 'DIA', 'IWM', 'BTC-USD']);
    });

    test('a duplicate or blank custom benchmark is ignored', () async {
      final controller = PortfolioAnalyticsController();

      await controller.addCustomBenchmark('SPY');
      await controller.addCustomBenchmark('   ');

      expect(controller.customBenchmarks, isEmpty);
      expect(controller.selectedBenchmark, 'SPY');
    });

    test('surfaces a failure instead of throwing', () async {
      final controller = PortfolioAnalyticsController(
        portfolioHistoricalsFuture:
            Future.error(StateError('historicals unavailable')),
      );
      await controller.ensureLoaded();

      // A failed historicals fetch degrades to "no data", not a crash.
      expect(controller.hasMetrics, isFalse);
      expect(controller.isLoading, isFalse);
    });
    test('updateInputs recomputes in place without replacing the instance',
        () async {
      final controller = PortfolioAnalyticsController(
        portfolioHistoricalsFuture:
            Future.value(buildHistoricals([100, 105, 110, 120])),
        benchmarkHistoricals: {
          'SPY': Future.value(buildBenchmarkPayload([100, 103, 106, 110])),
        },
        span: ChartDateSpan.ytd,
      );
      await controller.ensureLoaded();
      expect(controller.metrics['excessReturn'], closeTo(0.10, 0.001));

      var notified = 0;
      controller.addListener(() => notified++);

      // Simulates the Portfolio page reloading historicals for a new period.
      controller.updateInputs(
        portfolioHistoricalsFuture:
            Future.value(buildHistoricals([100, 102, 104, 106])),
        benchmarkHistoricals: {
          'SPY': Future.value(buildBenchmarkPayload([100, 103, 106, 110])),
        },
        span: ChartDateSpan.year_5,
      );
      await Future<void>.delayed(Duration.zero);

      // Same instance, new numbers: a pushed Performance or Risk page stays
      // attached and sees the update rather than being stranded on a disposed
      // controller.
      expect(controller.span, ChartDateSpan.year_5);
      expect(controller.metrics['excessReturn'], closeTo(-0.04, 0.001));
      expect(notified, greaterThan(0));
    });

    test('updateInputs re-runs even after a completed load', () async {
      final controller = PortfolioAnalyticsController();
      await controller.ensureLoaded();
      expect(controller.hasMetrics, isFalse);

      controller.updateInputs(
        portfolioHistoricalsFuture:
            Future.value(buildHistoricals([100, 105, 110, 120])),
        benchmarkHistoricals: {
          'SPY': Future.value(buildBenchmarkPayload([100, 103, 106, 110])),
        },
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.hasMetrics, isTrue);
    });

    test('recovers when historicals arrive after an input-less first load',
        () async {
      // Reproduces the Portfolio page's startup order: the controller is built
      // before the account resolves, so the first load has nothing to work
      // from. It must not latch that empty result.
      final controller = PortfolioAnalyticsController();
      await controller.ensureLoaded();

      expect(controller.hasInputs, isFalse);
      expect(controller.hasComputed, isFalse,
          reason: 'an input-less load must not count as computed');
      expect(controller.hasMetrics, isFalse);

      controller.updateInputs(
        portfolioHistoricalsFuture:
            Future.value(buildHistoricals([100, 105, 110, 120])),
        benchmarkHistoricals: {
          'SPY': Future.value(buildBenchmarkPayload([100, 103, 106, 110])),
        },
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.hasComputed, isTrue);
      expect(controller.metrics['excessReturn'], closeTo(0.10, 0.001));
    });

    test('a later ensureLoaded runs once inputs exist', () async {
      final controller = PortfolioAnalyticsController();
      await controller.ensureLoaded();
      expect(controller.hasComputed, isFalse);

      // Inputs appear without going through updateInputs.
      controller.portfolioHistoricalsFuture =
          Future.value(buildHistoricals([100, 105, 110, 120]));
      controller.benchmarkHistoricals = {
        'SPY': Future.value(buildBenchmarkPayload([100, 103, 106, 110])),
      };
      await controller.ensureLoaded();

      expect(controller.hasComputed, isTrue);
      expect(controller.hasMetrics, isTrue);
    });

    test('an empty result from real inputs counts as computed', () async {
      final controller = PortfolioAnalyticsController(
        portfolioHistoricalsFuture:
            Future.value(buildHistoricals([100, 101, 102, 103])),
        benchmarkHistoricals: {
          'SPY': Future.value(buildBenchmarkPayload([100, 101],
              start: DateTime(2027, 1, 5, 12))),
        },
      );
      await controller.ensureLoaded();

      // Nothing aligned, so there is genuinely no data — the section should say
      // so rather than spin forever.
      expect(controller.hasComputed, isTrue);
      expect(controller.hasMetrics, isFalse);
    });
  });
}
