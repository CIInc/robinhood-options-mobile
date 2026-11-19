import 'dart:math' as math;

import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/model/return_attribution.dart';
import 'package:robinhood_options_mobile/model/stock_loan.dart';

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
  /// today's session, plus dividend, interest/sweep, and stock-lending
  /// [incomePnL] / [incomeBreakdown] for the window.
  static OptionsAttributionResult calculateOptionsGreekAttribution({
    required Iterable<OptionAggregatePosition> positions,
    double incomePnL = 0,
    IncomeAttributionBreakdown? incomeBreakdown,
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

    final resolvedIncome = incomeBreakdown != null
        ? incomeBreakdown.totalIncomePnL
        : (incomePnL.isFinite ? incomePnL : 0.0);
    final resolvedBreakdown = incomeBreakdown ??
        IncomeAttributionBreakdown(dividendIncome: resolvedIncome);

    return OptionsAttributionResult(
      totalDeltaPnL: sum((r) => r.deltaPnL),
      totalGammaPnL: sum((r) => r.gammaPnL),
      totalThetaPnL: sum((r) => r.thetaPnL),
      totalVegaPnL: sum((r) => r.vegaPnL),
      totalResidualPnL: sum((r) => r.residualPnL),
      totalIncomePnL: resolvedIncome.isFinite ? resolvedIncome : 0,
      incomeBreakdown: resolvedBreakdown,
      contractCount: contracts,
      positions: rows,
      windowLabel: windowLabel,
    );
  }

  static const Set<String> _excludedIncomeStatuses = {
    'voided',
    'void',
    'pending',
    'cancelled',
    'canceled',
    'failed',
    'reversed',
  };

  /// Computes disaggregated income and yield attribution in [start, end]
  /// (inclusive) across:
  ///  * Paid dividends
  ///  * Paid cash-sweep / interest payouts, plus daily [SweepsInterest] accrual
  ///    estimates when enrolled and no payout landed in the window
  ///  * Paid/settled SLIP [StockLoanPayment] payouts, plus daily
  ///    [SlipEligibility] lending accrual estimates when enrolled and no SLIP
  ///    payout landed in the window.
  static IncomeAttributionBreakdown calculateIncomeBreakdown({
    Iterable<dynamic> dividends = const [],
    Iterable<dynamic> interest = const [],
    Iterable<dynamic> stockLoanPayments = const [],
    SweepsInterest? sweepsInterest,
    SlipEligibility? slipEligibility,
    required DateTime start,
    required DateTime end,
    double daysElapsed = 1,
  }) {
    DateTime? normalizeDate(DateTime? raw) {
      if (raw == null) return null;
      if (raw.isUtc &&
          !start.isUtc &&
          raw.hour == 0 &&
          raw.minute == 0 &&
          raw.second == 0 &&
          raw.millisecond == 0 &&
          raw.microsecond == 0) {
        return DateTime(raw.year, raw.month, raw.day);
      }
      return raw;
    }

    bool inWindow(DateTime? rawDate) {
      final date = normalizeDate(rawDate);
      return date != null && !date.isBefore(start) && !date.isAfter(end);
    }

    double parseRowAmount(dynamic rawAmount) {
      final amount = rawAmount is Map
          ? double.tryParse('${rawAmount['amount']}')
          : (rawAmount is num
              ? rawAmount.toDouble()
              : double.tryParse('$rawAmount'));
      return (amount != null && amount.isFinite) ? amount : 0.0;
    }

    double sumMapRows(Iterable<dynamic> rows, List<String> dateKeys) {
      var total = 0.0;
      for (final row in rows) {
        if (row is! Map) continue;
        final state = (row['state'] ?? row['status'])?.toString().toLowerCase();
        if (state != null && _excludedIncomeStatuses.contains(state)) continue;
        dynamic rawDate;
        for (final key in dateKeys) {
          if (row[key] != null) {
            rawDate = row[key];
            break;
          }
        }
        final date = rawDate == null ? null : DateTime.tryParse('$rawDate');
        if (!inWindow(date)) continue;
        total += parseRowAmount(
            row['amount'] ?? row['net_amount'] ?? row['total_amount']);
      }
      return total;
    }

    final dividendIncome = sumMapRows(
      dividends,
      const ['payable_date', 'pay_date'],
    );
    final paidInterest = sumMapRows(
      interest,
      const ['pay_date', 'payable_date'],
    );

    var paidStockLoan = 0.0;
    for (final entry in stockLoanPayments) {
      if (entry is StockLoanPayment) {
        final status = entry.status.toLowerCase();
        if (_excludedIncomeStatuses.contains(status) || !entry.isPaid) {
          continue;
        }
        if (!inWindow(entry.paymentDate)) continue;
        if (entry.amount.isFinite) {
          paidStockLoan += entry.amount;
        }
      } else if (entry is Map) {
        final status =
            (entry['status'] ?? entry['state'])?.toString().toLowerCase();
        if (status != null && _excludedIncomeStatuses.contains(status)) {
          continue;
        }
        final rawDate = entry['payment_date'] ??
            entry['paymentDate'] ??
            entry['paid_at'] ??
            entry['settlement_date'] ??
            entry['pay_date'] ??
            entry['date'];
        final date = rawDate == null ? null : DateTime.tryParse('$rawDate');
        if (!inWindow(date)) continue;
        paidStockLoan += parseRowAmount(
          entry['amount'] ?? entry['net_amount'] ?? entry['total_amount'],
        );
      }
    }

    final validDays = daysElapsed.isFinite && daysElapsed > 0;
    var dailySweepAccrualEstimate = 0.0;
    if (paidInterest == 0 &&
        validDays &&
        sweepsInterest != null &&
        sweepsInterest.isEnrolled) {
      final annual = sweepsInterest.estimatedAnnualInterest;
      if (annual.isFinite && annual > 0) {
        dailySweepAccrualEstimate = annual * (daysElapsed / 365.0);
      }
    }

    var dailyStockLoanAccrualEstimate = 0.0;
    if (paidStockLoan == 0 &&
        validDays &&
        slipEligibility != null &&
        slipEligibility.isEnrolled) {
      final loanedValue = slipEligibility.totalLoanedValue ?? 0.0;
      final annualYield = slipEligibility.estimatedAnnualizedYield ?? 0.0;
      final annual = loanedValue * annualYield;
      if (annual.isFinite && annual > 0) {
        dailyStockLoanAccrualEstimate = annual * (daysElapsed / 365.0);
      }
    }

    return IncomeAttributionBreakdown(
      dividendIncome: dividendIncome,
      interestAndSweepIncome: paidInterest + dailySweepAccrualEstimate,
      stockLoanIncome: paidStockLoan + dailyStockLoanAccrualEstimate,
      dailySweepAccrualEstimate: dailySweepAccrualEstimate,
      dailyStockLoanAccrualEstimate: dailyStockLoanAccrualEstimate,
    );
  }

  /// Sums paid dividends, cash sweeps/interest, and SLIP stock lending income
  /// whose date falls in [start, end] (inclusive), plus optional daily accrual
  /// estimates when enrolled. Malformed, pending, and voided rows are ignored.
  static double incomeWithinWindow({
    Iterable<dynamic> dividends = const [],
    Iterable<dynamic> interest = const [],
    Iterable<dynamic> stockLoanPayments = const [],
    SweepsInterest? sweepsInterest,
    SlipEligibility? slipEligibility,
    required DateTime start,
    required DateTime end,
    double daysElapsed = 1,
  }) {
    return calculateIncomeBreakdown(
      dividends: dividends,
      interest: interest,
      stockLoanPayments: stockLoanPayments,
      sweepsInterest: sweepsInterest,
      slipEligibility: slipEligibility,
      start: start,
      end: end,
      daysElapsed: daysElapsed,
    ).totalIncomePnL;
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
