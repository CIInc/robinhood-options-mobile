import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/esg_score.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/portfolio_historicals.dart';
import 'package:robinhood_options_mobile/services/esg_service.dart';
import 'package:robinhood_options_mobile/services/yahoo_service.dart';
import 'package:robinhood_options_mobile/utils/analytics_utils.dart';

/// Owns the portfolio analytics computation so it runs once and every section
/// reads the same numbers.
///
/// Previously this lived inside `PortfolioAnalyticsWidget`, which meant the
/// metrics were recomputed by whichever screen happened to mount that widget.
/// Now the Portfolio page creates one controller and hands it to the Performance
/// and Risk sections through `PortfolioSectionContext`; both listen to it, and
/// [ensureLoaded] makes the first reader pay for the work while later ones get
/// the cached result.
class PortfolioAnalyticsController extends ChangeNotifier {
  static const List<String> builtInBenchmarks = ['SPY', 'QQQ', 'DIA', 'IWM'];

  Future<PortfolioHistoricals>? portfolioHistoricalsFuture;

  /// Index historicals keyed by ticker, supplied by the Portfolio page.
  Map<String, Future<dynamic>?> benchmarkHistoricals;

  /// Used when [portfolioHistoricalsFuture] yields nothing, mirroring the
  /// span-preference order the old widget used.
  List<PortfolioHistoricals> fallbackHistoricals;

  ChartDateSpan? span;
  final YahooService _yahooService;
  final ESGService _esgService;

  PortfolioAnalyticsController({
    this.portfolioHistoricalsFuture,
    this.benchmarkHistoricals = const {},
    this.fallbackHistoricals = const [],
    this.span,
    YahooService? yahooService,
    ESGService? esgService,
  })  : _yahooService = yahooService ?? YahooService(),
        _esgService = esgService ?? ESGService();

  /// Points the controller at freshly-loaded historicals and recomputes.
  ///
  /// The inputs are replaced in place rather than the whole controller, because
  /// the section pages are pushed routes that captured this instance when they
  /// opened. Swapping the instance would leave a visible page listening to a
  /// disposed notifier and showing stale numbers.
  void updateInputs({
    Future<PortfolioHistoricals>? portfolioHistoricalsFuture,
    Map<String, Future<dynamic>?> benchmarkHistoricals = const {},
    List<PortfolioHistoricals> fallbackHistoricals = const [],
    ChartDateSpan? span,
  }) {
    this.portfolioHistoricalsFuture = portfolioHistoricalsFuture;
    this.benchmarkHistoricals = benchmarkHistoricals;
    this.fallbackHistoricals = fallbackHistoricals;
    this.span = span;
    _hasLoaded = false;
    _load();
  }

  Map<String, dynamic> _metrics = {};
  Map<String, dynamic> _esg = {};
  bool _isLoading = false;
  Object? _error;
  bool _hasLoaded = false;
  bool _disposed = false;

  String _selectedBenchmark = 'SPY';
  final List<String> _customBenchmarks = [];
  final Map<String, Future<dynamic>> _customBenchmarkFutures = {};

  Map<String, dynamic> get metrics => _metrics;
  Map<String, dynamic> get esg => _esg;
  bool get isLoading => _isLoading;
  Object? get error => _error;
  bool get hasMetrics => _metrics.isNotEmpty;

  /// True once a computation has actually run against real inputs.
  ///
  /// Sections use this to tell "still waiting on historicals" apart from
  /// "computed, and there genuinely is nothing to show" — the two look
  /// identical from [metrics] alone but need opposite UI.
  bool get hasComputed => _hasLoaded;
  String get selectedBenchmark => _selectedBenchmark;
  List<String> get customBenchmarks => List.unmodifiable(_customBenchmarks);
  List<String> get allBenchmarks =>
      [...builtInBenchmarks, ..._customBenchmarks];

  /// Computes the metrics unless they are already available or in flight.
  Future<void> ensureLoaded() {
    if (_hasLoaded || _isLoading) return Future.value();
    return _load();
  }

  Future<void> refresh() => _load();

  Future<void> selectBenchmark(String symbol) {
    if (_selectedBenchmark == symbol) return Future.value();
    _selectedBenchmark = symbol;
    notifyListeners();
    return _load();
  }

  /// Adds a user-supplied ticker as a benchmark and switches to it.
  Future<void> addCustomBenchmark(String symbol) {
    final normalized = symbol.trim().toUpperCase();
    if (normalized.isEmpty ||
        builtInBenchmarks.contains(normalized) ||
        _customBenchmarks.contains(normalized)) {
      return Future.value();
    }

    _customBenchmarks.add(normalized);
    _customBenchmarkFutures[normalized] =
        _yahooService.getMarketIndexHistoricals(
      symbol: normalized,
      range: _yahooRange,
    );
    _selectedBenchmark = normalized;
    notifyListeners();
    return _load();
  }

  /// Recomputes the ESG roll-up for the supplied holdings.
  ///
  /// Kept separate from [_load] because it depends on positions rather than
  /// historicals and is only rendered by the Taxes section.
  Future<void> loadEsg(List<InstrumentPosition> positions) async {
    final symbols = positions
        .where((position) => position.instrumentObj != null)
        .map((position) => position.instrumentObj!.symbol)
        .toList();
    if (symbols.isEmpty) {
      _esg = {};
      _notify();
      return;
    }

    try {
      final scores = (await _esgService.getESGScores(symbols))
          .whereType<ESGScore>()
          .toList();

      var weightedTotal = 0.0;
      var weightedEnvironmental = 0.0;
      var weightedSocial = 0.0;
      var weightedGovernance = 0.0;
      var totalValue = 0.0;

      for (final position in positions) {
        final symbol = position.instrumentObj?.symbol;
        if (symbol == null) continue;
        final score = scores.firstWhereOrNull((s) => s.symbol == symbol);
        if (score == null) continue;

        final value = position.marketValue;
        weightedTotal += score.totalScore * value;
        weightedEnvironmental += score.environmentalScore * value;
        weightedSocial += score.socialScore * value;
        weightedGovernance += score.governanceScore * value;
        totalValue += value;
      }

      _esg = totalValue == 0
          ? {}
          : {
              'totalScore': weightedTotal / totalValue,
              'environmentalScore': weightedEnvironmental / totalValue,
              'socialScore': weightedSocial / totalValue,
              'governanceScore': weightedGovernance / totalValue,
              'scores': scores,
            };
    } catch (e) {
      debugPrint('Error calculating ESG scores: $e');
      _esg = {};
    }
    _notify();
  }

  /// Whether there is anything to compute from yet.
  ///
  /// False during startup: the Portfolio page resolves accounts before it can
  /// request historicals, so the controller exists for a moment with no inputs.
  bool get hasInputs =>
      portfolioHistoricalsFuture != null || fallbackHistoricals.isNotEmpty;

  Future<void> _load() async {
    if (!hasInputs) {
      // Stay "not loaded" rather than latching an empty result, so the
      // ensureLoaded() that follows once historicals arrive actually runs.
      _metrics = {};
      _hasLoaded = false;
      _isLoading = false;
      _notify();
      return;
    }

    _isLoading = true;
    _error = null;
    _notify();

    try {
      _metrics = await _calculate();
      _hasLoaded = true;
    } catch (e) {
      debugPrint('Error calculating portfolio analytics: $e');
      _error = e;
      _metrics = {};
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  Future<Map<String, dynamic>> _calculate() async {
    final historicals = await _resolveHistoricals();
    if (historicals == null) return {};

    final benchmarkByDate = await _resolveBenchmark();

    final alignedPortfolioPrices = <double>[];
    final alignedBenchmarkPrices = <double>[];
    final alignedDates = <DateTime>[];

    for (final historical in historicals.equityHistoricals) {
      final beginsAt = historical.beginsAt;
      if (beginsAt == null) continue;
      final benchmark = benchmarkByDate[_dateKey(beginsAt)];
      if (benchmark == null) continue;

      alignedPortfolioPrices
          .add(historical.adjustedCloseEquity ?? historical.closeEquity ?? 0.0);
      alignedBenchmarkPrices.add(benchmark);
      alignedDates.add(beginsAt);
    }

    if (alignedPortfolioPrices.length < 2) return {};

    // The chart draws full history while the metrics use the benchmark
    // intersection. Passing both keeps the cumulative-return tile agreeing with
    // the chart above it.
    final fullPortfolioPrices = historicals.equityHistoricals
        .map((h) => h.adjustedCloseEquity ?? h.closeEquity ?? 0.0)
        .where((equity) => equity != 0)
        .toList();

    final periodDays = _periodDays(
      historicals: historicals,
      fullPortfolioPrices: fullPortfolioPrices,
      alignedDates: alignedDates,
    );

    final metrics = AnalyticsUtils.calculatePortfolioMetrics(
      alignedPortfolioPrices: alignedPortfolioPrices,
      alignedBenchmarkPrices: alignedBenchmarkPrices,
      fullPortfolioPrices: fullPortfolioPrices,
      periodYears: periodDays / 365.0,
      alignedDates: alignedDates,
    );
    if (metrics.isEmpty) return {};

    metrics['alignedDates'] = alignedDates;
    metrics['alignedPortfolioPrices'] = alignedPortfolioPrices;
    metrics['alignedBenchmarkPrices'] = alignedBenchmarkPrices;
    metrics['periodDays'] = periodDays;
    metrics['excessReturn'] = (metrics['portfolioCumulative'] ?? 0.0) -
        (metrics['benchmarkCumulative'] ?? 0.0);
    metrics['excessReturnHistory'] = _excessReturnHistory(
      alignedDates: alignedDates,
      alignedPortfolioPrices: alignedPortfolioPrices,
      alignedBenchmarkPrices: alignedBenchmarkPrices,
    );
    metrics['monthlyReturns'] = _monthlyReturns(
      alignedDates: alignedDates,
      alignedPortfolioPrices: alignedPortfolioPrices,
    );
    metrics['benchmarkSymbol'] = _selectedBenchmark;

    return metrics;
  }

  Future<PortfolioHistoricals?> _resolveHistoricals() async {
    if (portfolioHistoricalsFuture != null) {
      try {
        final historicals = await portfolioHistoricalsFuture;
        if (historicals != null) return historicals;
      } catch (e) {
        debugPrint('Error awaiting portfolio historicals: $e');
      }
    }

    if (fallbackHistoricals.isEmpty) return null;
    return fallbackHistoricals
            .firstWhereOrNull((item) => item.span == 'year') ??
        fallbackHistoricals.firstWhereOrNull((item) => item.span == '5year') ??
        fallbackHistoricals.firstWhereOrNull((item) => item.span == '3month') ??
        fallbackHistoricals.first;
  }

  Future<Map<String, double>> _resolveBenchmark() async {
    final future = _customBenchmarkFutures[_selectedBenchmark] ??
        benchmarkHistoricals[_selectedBenchmark];
    if (future == null) return {};

    try {
      final data = await future;
      if (data == null) return {};

      final result = data['chart']?['result']?[0];
      final timestamps = result?['timestamp'] as List?;
      final adjcloses =
          result?['indicators']?['adjclose']?[0]?['adjclose'] as List?;
      if (timestamps == null || adjcloses == null) return {};

      final byDate = <String, double>{};
      for (var i = 0; i < timestamps.length && i < adjcloses.length; i++) {
        final close = adjcloses[i];
        if (close == null) continue;
        final date =
            DateTime.fromMillisecondsSinceEpoch((timestamps[i] as int) * 1000);
        byDate[_dateKey(date)] = (close as num).toDouble();
      }
      return byDate;
    } catch (e) {
      debugPrint('Error using $_selectedBenchmark index data: $e');
      return {};
    }
  }

  int _periodDays({
    required PortfolioHistoricals historicals,
    required List<double> fullPortfolioPrices,
    required List<DateTime> alignedDates,
  }) {
    final validHistory = historicals.equityHistoricals
        .where((historical) => historical.beginsAt != null)
        .toList();

    if (validHistory.isNotEmpty && fullPortfolioPrices.length >= 2) {
      final days = validHistory.last.beginsAt!
          .difference(validHistory.first.beginsAt!)
          .inDays
          .abs();
      return days > 0 ? days : 1;
    }
    if (alignedDates.isNotEmpty) {
      final days =
          alignedDates.last.difference(alignedDates.first).inDays.abs();
      return days > 0 ? days : 1;
    }
    return 1;
  }

  List<Map<String, dynamic>> _excessReturnHistory({
    required List<DateTime> alignedDates,
    required List<double> alignedPortfolioPrices,
    required List<double> alignedBenchmarkPrices,
  }) {
    if (alignedPortfolioPrices.isEmpty ||
        alignedBenchmarkPrices.length != alignedPortfolioPrices.length) {
      return const [];
    }

    final portfolioBase = alignedPortfolioPrices.first;
    final benchmarkBase = alignedBenchmarkPrices.first;
    if (portfolioBase == 0 || benchmarkBase == 0) return const [];

    return [
      for (var i = 0; i < alignedPortfolioPrices.length; i++)
        {
          'date': alignedDates[i],
          'value': (alignedPortfolioPrices[i] / portfolioBase) -
              (alignedBenchmarkPrices[i] / benchmarkBase),
        },
    ];
  }

  /// Monthly returns as `{year: {month: return}}`.
  Map<int, Map<int, double>> _monthlyReturns({
    required List<DateTime> alignedDates,
    required List<double> alignedPortfolioPrices,
  }) {
    final monthlyReturns = <int, Map<int, double>>{};
    if (alignedDates.isEmpty ||
        alignedPortfolioPrices.length != alignedDates.length) {
      return monthlyReturns;
    }

    final monthStartPrice = <String, double>{};
    final monthEndPrice = <String, double>{};

    for (var i = 0; i < alignedDates.length; i++) {
      final date = alignedDates[i];
      final key = '${date.year}-${date.month}';
      // The month's base is the previous trading day's close, so a month's
      // return includes the move on its first day.
      monthStartPrice.putIfAbsent(
          key,
          () => i > 0
              ? alignedPortfolioPrices[i - 1]
              : alignedPortfolioPrices[i]);
      monthEndPrice[key] = alignedPortfolioPrices[i];
    }

    monthEndPrice.forEach((key, endPrice) {
      final startPrice = monthStartPrice[key];
      if (startPrice == null || startPrice == 0) return;

      final parts = key.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      monthlyReturns.putIfAbsent(year, () => {})[month] =
          (endPrice - startPrice) / startPrice;
    });

    return monthlyReturns;
  }

  String get _yahooRange {
    switch (span) {
      case ChartDateSpan.year:
        return '1y';
      case ChartDateSpan.year_2:
        return '2y';
      case ChartDateSpan.year_3:
      case ChartDateSpan.year_5:
        return '5y';
      default:
        return 'ytd';
    }
  }

  static String _dateKey(DateTime date) =>
      date.toIso8601String().split('T').first;

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
