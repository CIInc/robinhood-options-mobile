import 'dart:math' as math;

import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/model/return_attribution.dart';

/// Multi-Asset Brinson Performance & Greek Return Attribution Engine (#278).
///
/// Pure, side-effect-free calculations so every identity can be unit tested.
/// Network access (sector ETF quotes) is the caller's responsibility; see
/// [sectorEtfProxies] and [sectorReturnsFromQuotes].
class ReturnAttributionService {
  const ReturnAttributionService._();

  static const String todayWindowLabel = "Today's session";

  static const String infoTech = 'Information Technology';
  static const String financials = 'Financials';
  static const String healthCare = 'Health Care';
  static const String consumerDiscretionary = 'Consumer Discretionary';
  static const String communicationServices = 'Communication Services';
  static const String industrials = 'Industrials';
  static const String consumerStaples = 'Consumer Staples';
  static const String energy = 'Energy';
  static const String utilities = 'Utilities';
  static const String realEstate = 'Real Estate';
  static const String materials = 'Materials';
  static const String other = 'Other / Funds';
  static const String cash = 'Cash';

  /// SPDR Select Sector ETFs used as the benchmark's per-sector return proxy.
  static const Map<String, String> sectorEtfProxies = {
    infoTech: 'XLK',
    financials: 'XLF',
    healthCare: 'XLV',
    consumerDiscretionary: 'XLY',
    communicationServices: 'XLC',
    industrials: 'XLI',
    consumerStaples: 'XLP',
    energy: 'XLE',
    utilities: 'XLU',
    realEstate: 'XLRE',
    materials: 'XLB',
  };

  /// Approximate GICS sector weights (percent) of the built-in benchmarks.
  ///
  /// These are periodically refreshed approximations of published fund
  /// breakdowns and are normalized to sum to 1 before use.
  static const Map<String, Map<String, double>> _benchmarkSectorWeights = {
    'SPY': {
      infoTech: 31.0,
      financials: 13.0,
      healthCare: 10.0,
      consumerDiscretionary: 10.5,
      communicationServices: 9.5,
      industrials: 8.5,
      consumerStaples: 5.5,
      energy: 3.2,
      utilities: 2.4,
      realEstate: 2.1,
      materials: 1.9,
    },
    'QQQ': {
      infoTech: 50.0,
      communicationServices: 16.0,
      consumerDiscretionary: 13.5,
      healthCare: 6.0,
      consumerStaples: 5.0,
      industrials: 4.5,
      utilities: 1.4,
      materials: 1.3,
      energy: 0.5,
      financials: 0.5,
      realEstate: 0.2,
    },
    'DIA': {
      financials: 25.0,
      infoTech: 20.0,
      industrials: 14.0,
      consumerDiscretionary: 13.0,
      healthCare: 12.0,
      consumerStaples: 5.0,
      communicationServices: 4.0,
      energy: 3.0,
      materials: 1.5,
    },
    'IWM': {
      industrials: 18.0,
      financials: 17.0,
      healthCare: 16.0,
      infoTech: 13.0,
      consumerDiscretionary: 10.0,
      realEstate: 6.5,
      energy: 5.0,
      materials: 4.5,
      utilities: 3.0,
      consumerStaples: 3.0,
      communicationServices: 2.5,
    },
  };

  /// Whether [benchmarkSymbol] has its own sector breakdown. Custom
  /// benchmarks fall back to SPY weights and are flagged in the UI.
  static bool hasPublishedSectorWeights(String benchmarkSymbol) =>
      _benchmarkSectorWeights.containsKey(benchmarkSymbol.toUpperCase());

  /// Normalized (sum = 1) sector weights for [benchmarkSymbol].
  static Map<String, double> benchmarkSectorWeightsFor(String benchmarkSymbol) {
    final raw = _benchmarkSectorWeights[benchmarkSymbol.toUpperCase()] ??
        _benchmarkSectorWeights['SPY']!;
    return _normalize(raw);
  }

  /// Maps broker/data-vendor sector labels (Robinhood/FactSet, Yahoo, GICS)
  /// onto the 11 GICS sectors used by the benchmark weights.
  static String normalizeSector(String? raw) {
    final s = (raw ?? '').trim().toLowerCase();
    if (s.isEmpty) return other;
    if (s.contains('real estate') || s.contains('reit')) return realEstate;
    if (s.contains('utilit')) return utilities;
    // Before the energy rule: FactSet's "Non-Energy Minerals" is Materials.
    if (s.contains('non-energy')) return materials;
    if (s.contains('energy')) return energy;
    if (s.contains('health')) return healthCare;
    if (s.contains('financ')) return financials;
    if (s.contains('communication')) return communicationServices;
    if (s.contains('technology') || s.contains('information')) {
      return infoTech;
    }
    if (s.contains('non-durables') ||
        s.contains('defensive') ||
        s.contains('staples')) {
      return consumerStaples;
    }
    if (s.contains('retail') ||
        s.contains('consumer durables') ||
        s.contains('consumer services') ||
        s.contains('cyclical') ||
        s.contains('discretionary')) {
      return consumerDiscretionary;
    }
    if (s.contains('minerals') ||
        s.contains('process industries') ||
        s.contains('materials')) {
      return materials;
    }
    if (s.contains('manufacturing') ||
        s.contains('transportation') ||
        s.contains('industrial') ||
        s.contains('commercial services') ||
        s.contains('distribution')) {
      return industrials;
    }
    return other;
  }

  /// Converts live equity positions into today's-session holdings
  /// (previous close → current price). Positions without a usable quote are
  /// skipped rather than guessed.
  static List<AttributionHolding> holdingsFromPositions(
    Iterable<InstrumentPosition> positions,
  ) {
    final holdings = <AttributionHolding>[];
    for (final position in positions) {
      final quantity = position.quantity;
      final instrument = position.instrumentObj;
      final quote = instrument?.quoteObj;
      if (quantity == null || quantity == 0 || quote == null) continue;
      final previousClose = quote.adjustedPreviousClose ?? quote.previousClose;
      final current = quote.lastExtendedHoursTradePrice ?? quote.lastTradePrice;
      if (!_isPositiveFinite(previousClose) || !_isPositiveFinite(current)) {
        continue;
      }
      holdings.add(AttributionHolding(
        symbol: instrument!.symbol,
        sector: normalizeSector(instrument.fundamentalsObj?.sector),
        beginValue: previousClose! * quantity,
        endValue: current! * quantity,
      ));
    }
    return holdings;
  }

  /// Today's return per GICS sector from sector ETF quotes.
  static Map<String, double> sectorReturnsFromQuotes(Iterable<Quote> quotes) {
    final bySymbol = {for (final q in quotes) q.symbol.toUpperCase(): q};
    final returns = <String, double>{};
    sectorEtfProxies.forEach((sector, etf) {
      final quote = bySymbol[etf];
      if (quote == null) return;
      final previousClose = quote.adjustedPreviousClose ?? quote.previousClose;
      final current = quote.lastExtendedHoursTradePrice ?? quote.lastTradePrice;
      if (!_isPositiveFinite(previousClose) || !_isPositiveFinite(current)) {
        return;
      }
      returns[sector] = current! / previousClose! - 1.0;
    });
    return returns;
  }

  /// Brinson-Fachler decomposition of portfolio vs. benchmark return.
  ///
  /// For each sector i, with beginning weights w and returns R:
  ///  * Allocation  A = (wP − wB) · (RBi − RB)
  ///  * Selection   S = wB · (RPi − RBi)
  ///  * Interaction I = (wP − wB) · (RPi − RBi)
  ///
  /// Both weight sets sum to 1, so Σ(A + S + I) = RP − RB exactly. Sectors
  /// the portfolio does not hold use RPi = RBi (no selection or interaction).
  /// Segments outside the benchmark (wB = 0) use RBi = 0 for Cash, which
  /// surfaces cash drag as an allocation effect, and RBi = RB for Other /
  /// Funds, which surfaces their over/under-performance as interaction.
  static BrinsonAttributionResult calculateBrinsonAttribution({
    required List<AttributionHolding> holdings,
    required Map<String, double> benchmarkSectorWeights,
    required Map<String, double> benchmarkSectorReturns,
    required String benchmarkSymbol,
    double cashBalance = 0,
    String windowLabel = todayWindowLabel,
    bool usesProxyBenchmarkWeights = false,
  }) {
    // Benchmark: only sectors with both a weight and a return, renormalized.
    final benchmarkWeights = _normalize({
      for (final entry in benchmarkSectorWeights.entries)
        if (benchmarkSectorReturns[entry.key]?.isFinite ?? false)
          entry.key: entry.value,
    });
    var benchmarkReturn = 0.0;
    benchmarkWeights.forEach((sector, weight) {
      benchmarkReturn += weight * benchmarkSectorReturns[sector]!;
    });

    // Portfolio: aggregate begin values and P&L per sector.
    final sectorBegin = <String, double>{};
    final sectorPnL = <String, double>{};
    for (final h in holdings) {
      if (!h.beginValue.isFinite || !h.endValue.isFinite || h.beginValue <= 0) {
        continue;
      }
      sectorBegin[h.sector] = (sectorBegin[h.sector] ?? 0) + h.beginValue;
      sectorPnL[h.sector] = (sectorPnL[h.sector] ?? 0) + h.pnl;
    }
    if (cashBalance.isFinite && cashBalance > 0) {
      sectorBegin[cash] = (sectorBegin[cash] ?? 0) + cashBalance;
      sectorPnL[cash] = sectorPnL[cash] ?? 0;
    }

    final totalBegin = sectorBegin.values.fold<double>(0, (a, b) => a + b);
    if (totalBegin <= 0 || benchmarkWeights.isEmpty) {
      return BrinsonAttributionResult(
        benchmarkSymbol: benchmarkSymbol,
        totalPortfolioReturn: 0,
        totalBenchmarkReturn: benchmarkReturn,
        totalAllocationEffect: 0,
        totalSelectionEffect: 0,
        totalInteractionEffect: 0,
        totalPortfolioValue: math.max(0, totalBegin),
        totalPortfolioPnL: 0,
        sectorAttributions: const [],
        windowLabel: windowLabel,
        usesProxyBenchmarkWeights: usesProxyBenchmarkWeights,
      );
    }
    final totalPnL = sectorPnL.values.fold<double>(0, (a, b) => a + b);
    final portfolioReturn = totalPnL / totalBegin;

    final sectors = <String>{...benchmarkWeights.keys, ...sectorBegin.keys};
    final rows = <BrinsonSectorAttribution>[];
    var totalA = 0.0, totalS = 0.0, totalI = 0.0;
    for (final sector in sectors) {
      final wP = (sectorBegin[sector] ?? 0) / totalBegin;
      final wB = benchmarkWeights[sector] ?? 0;
      final rB = benchmarkWeights.containsKey(sector)
          ? benchmarkSectorReturns[sector]!
          : (sector == cash ? 0.0 : benchmarkReturn);
      final begin = sectorBegin[sector] ?? 0;
      final rP = begin > 0 ? (sectorPnL[sector] ?? 0) / begin : rB;

      final allocation = (wP - wB) * (rB - benchmarkReturn);
      final selection = wB * (rP - rB);
      final interaction = (wP - wB) * (rP - rB);
      totalA += allocation;
      totalS += selection;
      totalI += interaction;

      rows.add(BrinsonSectorAttribution(
        sector: sector,
        portfolioWeight: wP,
        benchmarkWeight: wB,
        portfolioReturn: rP,
        benchmarkReturn: rB,
        allocationEffect: allocation,
        selectionEffect: selection,
        interactionEffect: interaction,
        portfolioValue: begin,
        portfolioPnL: sectorPnL[sector] ?? 0,
      ));
    }
    rows.sort((a, b) => b.totalEffect.abs().compareTo(a.totalEffect.abs()));

    return BrinsonAttributionResult(
      benchmarkSymbol: benchmarkSymbol,
      totalPortfolioReturn: portfolioReturn,
      totalBenchmarkReturn: benchmarkReturn,
      totalAllocationEffect: totalA,
      totalSelectionEffect: totalS,
      totalInteractionEffect: totalI,
      totalPortfolioValue: totalBegin,
      totalPortfolioPnL: totalPnL,
      sectorAttributions: rows,
      windowLabel: windowLabel,
      usesProxyBenchmarkWeights: usesProxyBenchmarkWeights,
    );
  }

  /// Taylor-series attribution for one option position.
  ///
  /// [scale] is signed contracts × multiplier (negative for credit/short).
  /// Greeks are per-share and per-contract-unit as reported by the broker:
  /// theta per calendar day, vega per 1 vol point. Vega P&L is implied from
  /// the remainder after Δ, Γ and Θ when the position has vega exposure;
  /// otherwise the remainder is reported as residual.
  static GreekPnLAttribution attributeOptionPosition({
    required String symbol,
    required double scale,
    required double underlyingChange,
    required double optionPriceChange,
    double? delta,
    double? gamma,
    double? theta,
    double? vega,
    double daysElapsed = 1,
  }) {
    final deltaPnL = _finite(delta) * underlyingChange * scale;
    final gammaPnL =
        0.5 * _finite(gamma) * underlyingChange * underlyingChange * scale;
    final thetaPnL = _finite(theta) * daysElapsed * scale;
    final actual = optionPriceChange * scale;
    final remainder = actual - deltaPnL - gammaPnL - thetaPnL;
    final hasVega = _finite(vega).abs() > 1e-9;
    return GreekPnLAttribution(
      symbol: symbol,
      deltaPnL: deltaPnL,
      gammaPnL: gammaPnL,
      thetaPnL: thetaPnL,
      vegaPnL: hasVega ? remainder : 0,
      residualPnL: hasVega ? 0 : remainder,
      actualPnL: actual,
    );
  }

  /// Aggregates [attributeOptionPosition] across live option positions for
  /// today's session, plus dividend/interest [incomePnL] for the window.
  static OptionsAttributionResult calculateOptionsGreekAttribution({
    required Iterable<OptionAggregatePosition> positions,
    double incomePnL = 0,
    double daysElapsed = 1,
    String windowLabel = todayWindowLabel,
  }) {
    final rows = <GreekPnLAttribution>[];
    var contracts = 0;
    for (final position in positions) {
      final marketData = position.optionInstrument?.optionMarketData;
      final quantity = position.quantity;
      if (marketData == null || quantity == null || quantity == 0) continue;
      final multiplier = position.tradeValueMultiplier ?? 100;
      if (!multiplier.isFinite || multiplier <= 0) continue;

      final mark = marketData.adjustedMarkPrice ?? marketData.markPrice;
      final previousMark = marketData.previousClosePrice;
      final underlyingQuote = position.instrumentObj?.quoteObj;
      final underlyingNow = underlyingQuote?.lastExtendedHoursTradePrice ??
          underlyingQuote?.lastTradePrice;
      final underlyingPrev = underlyingQuote?.adjustedPreviousClose ??
          underlyingQuote?.previousClose;
      if (!_isFinite(mark) ||
          !_isFinite(previousMark) ||
          !_isFinite(underlyingNow) ||
          !_isFinite(underlyingPrev)) {
        continue;
      }

      final direction = position.direction.toLowerCase() == 'credit' ? -1 : 1;
      rows.add(attributeOptionPosition(
        symbol: position.symbol,
        scale: quantity * multiplier * direction,
        underlyingChange: underlyingNow! - underlyingPrev!,
        optionPriceChange: mark! - previousMark!,
        delta: marketData.delta,
        gamma: marketData.gamma,
        theta: marketData.theta,
        vega: marketData.vega,
        daysElapsed: daysElapsed,
      ));
      contracts += quantity.abs().round();
    }

    double sum(double Function(GreekPnLAttribution) f) =>
        rows.fold<double>(0, (total, r) => total + f(r));

    return OptionsAttributionResult(
      totalDeltaPnL: sum((r) => r.deltaPnL),
      totalGammaPnL: sum((r) => r.gammaPnL),
      totalThetaPnL: sum((r) => r.thetaPnL),
      totalVegaPnL: sum((r) => r.vegaPnL),
      totalResidualPnL: sum((r) => r.residualPnL),
      totalIncomePnL: incomePnL.isFinite ? incomePnL : 0,
      contractCount: contracts,
      positions: rows,
      windowLabel: windowLabel,
    );
  }

  /// Sums paid dividends and interest whose pay date falls in
  /// [start, end] (inclusive). Accepts the raw broker maps held by
  /// `DividendStore` and `InterestStore`; malformed rows are ignored.
  static double incomeWithinWindow({
    Iterable<dynamic> dividends = const [],
    Iterable<dynamic> interest = const [],
    required DateTime start,
    required DateTime end,
  }) {
    var total = 0.0;
    void addIfInWindow(dynamic row, String dateKey) {
      if (row is! Map) return;
      final state = row['state']?.toString();
      if (state == 'voided' || state == 'pending') return;
      final rawDate = row[dateKey] ?? row['pay_date'] ?? row['payable_date'];
      final date = rawDate == null ? null : DateTime.tryParse('$rawDate');
      if (date == null || date.isBefore(start) || date.isAfter(end)) return;
      final rawAmount = row['amount'];
      final amount = rawAmount is Map
          ? double.tryParse('${rawAmount['amount']}')
          : (rawAmount is num
              ? rawAmount.toDouble()
              : double.tryParse('$rawAmount'));
      if (amount != null && amount.isFinite) total += amount;
    }

    for (final d in dividends) {
      addIfInWindow(d, 'payable_date');
    }
    for (final i in interest) {
      addIfInWindow(i, 'pay_date');
    }
    return total;
  }

  static Map<String, double> _normalize(Map<String, double> raw) {
    final total = raw.values
        .where((v) => v.isFinite && v > 0)
        .fold<double>(0, (a, b) => a + b);
    if (total <= 0) return {};
    return {
      for (final e in raw.entries)
        if (e.value.isFinite && e.value > 0) e.key: e.value / total,
    };
  }

  static double _finite(double? v) => (v != null && v.isFinite) ? v : 0.0;
  static bool _isFinite(double? v) => v != null && v.isFinite;
  static bool _isPositiveFinite(double? v) => v != null && v.isFinite && v > 0;
}
