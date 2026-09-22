import 'dart:math';
import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/model/instrument_historical.dart';
import 'package:robinhood_options_mobile/model/option_marketdata.dart';
import 'package:robinhood_options_mobile/model/volatility_cone_model.dart';

/// Pure quantitative service for computing rolling Realized Volatility (HV/RV) cones,
/// multi-timeframe Implied Volatility (IV) Rank & Percentile, volatility skew surfaces,
/// term structure curvature, and Volatility Risk Premium (VRP).
class VolatilityConeService {
  /// Computes a full [VolatilityConeAnalysis] from historical candles, options chains,
  /// and option market data.
  static VolatilityConeAnalysis computeAnalysis({
    required String symbol,
    required double spotPrice,
    List<InstrumentHistorical>? historicalCandles,
    List<double>? closePrices,
    List<Map<String, dynamic>>? optionsChains,
    List<OptionMarketData>? optionQuotes,
    DateTime? nextEarningsDate,
    double? overrideCurrentIv,
    DateTime? simulatedNow,
  }) {
    final now = simulatedNow ?? DateTime.now();

    // 1. Extract and sanitize historical daily close prices
    final List<double> prices = _extractClosePrices(
      historicalCandles: historicalCandles,
      closePrices: closePrices,
      spotPrice: spotPrice,
    );

    // 2. Extract Term Structure & Strike Skew from option market data
    final termStructure = _extractTermStructure(
      spotPrice: spotPrice,
      optionsChains: optionsChains,
      optionQuotes: optionQuotes,
      overrideIv: overrideCurrentIv,
      now: now,
    );

    final skewAnalysis = _extractSkewAnalysis(
      spotPrice: spotPrice,
      optionsChains: optionsChains,
      optionQuotes: optionQuotes,
      overrideIv: overrideCurrentIv,
      now: now,
    );

    // Baseline current 30D IV
    final double currentIv30 = overrideCurrentIv ??
        termStructure?.points.firstWhere(
          (p) => p.dte >= 15 && p.dte <= 45,
          orElse: () => termStructure.points.isNotEmpty
              ? termStructure.points.first
              : const TermStructurePoint(dte: 30, atmIv: 0.32),
        ).atmIv ??
        0.32;

    // 3. Compute Volatility Cone across standard tenors
    final List<VolatilityConePoint> conePoints = _buildVolatilityCone(
      prices: prices,
      currentIv30: currentIv30,
      termStructure: termStructure,
    );

    // 4. Compute multi-timeframe IV Rank & Percentile (30D, 60D, 90D)
    final metrics30d = _computeIvMetrics(
      tenorDays: 30,
      label: '30D',
      currentIv: currentIv30,
      conePoints: conePoints,
      prices: prices,
    );

    final currentIv60 = _findIvForTenor(60, termStructure, currentIv30 * 1.02);
    final metrics60d = _computeIvMetrics(
      tenorDays: 60,
      label: '60D',
      currentIv: currentIv60,
      conePoints: conePoints,
      prices: prices,
    );

    final currentIv90 = _findIvForTenor(90, termStructure, currentIv30 * 1.04);
    final metrics90d = _computeIvMetrics(
      tenorDays: 90,
      label: '90D',
      currentIv: currentIv90,
      conePoints: conePoints,
      prices: prices,
    );

    // 5. Volatility Risk Premium (VRP) calculation
    final conePoint30 = conePoints.firstWhere(
      (p) => p.days == 30,
      orElse: () => conePoints.isNotEmpty ? conePoints[0] : _defaultConePoint(30, '30D'),
    );
    final double rv30 = conePoint30.currentRv > 0 ? conePoint30.currentRv : 0.25;
    final double vrp30 = currentIv30 - rv30;
    final double vrpRatio = rv30 > 0 ? currentIv30 / rv30 : 1.0;
    final vrp = VolatilityRiskPremium(
      vrp30d: vrp30,
      vrpRatio: vrpRatio,
      isRich: vrp30 > 0,
      historicalVrpAvg: 0.035, // Typical index/equity long-run variance premium ~3.5%
    );

    // 6. Pre-earnings IV elevation / crush warning
    PreEarningsCrushIndicator? preEarningsIndicator;
    if (nextEarningsDate != null) {
      final daysToEarnings = max(0, nextEarningsDate.difference(now).inDays);
      if (daysToEarnings <= 21) {
        final baselineIv = conePoint30.medianRv > 0 ? conePoint30.medianRv : 0.25;
        final elevation = baselineIv > 0 ? (currentIv30 - baselineIv) / baselineIv : 0.0;
        final isCrushImminent = daysToEarnings <= 7 && elevation > 0.15;
        preEarningsIndicator = PreEarningsCrushIndicator(
          daysToEarnings: daysToEarnings,
          currentIv: currentIv30,
          baselineIv: baselineIv,
          ivElevationPct: max(0.0, elevation * 100),
          isCrushImminent: isCrushImminent,
        );
      }
    }

    // 7. Determine overall regime
    final overallRegime = _determineRegime(
      metrics30d: metrics30d,
      conePoint30: conePoint30,
      preEarnings: preEarningsIndicator,
    );

    // 8. Generate tactical strategy playbook
    final recommendations = _generatePlaybook(
      regime: overallRegime,
      metrics30d: metrics30d,
      skew: skewAnalysis,
      termStructure: termStructure,
      vrp: vrp,
    );

    return VolatilityConeAnalysis(
      symbol: symbol,
      spotPrice: spotPrice,
      conePoints: conePoints,
      metrics30d: metrics30d,
      metrics60d: metrics60d,
      metrics90d: metrics90d,
      skewAnalysis: skewAnalysis,
      termStructure: termStructure,
      vrp: vrp,
      overallRegime: overallRegime,
      recommendations: recommendations,
      preEarningsIndicator: preEarningsIndicator,
      calculatedAt: now,
    );
  }

  /// Calculates annualized Realized Volatility from a series of prices over a lookback.
  /// $r_t = \ln(P_t / P_{t-1})$
  /// $\sigma = \sqrt{252} \times \sqrt{\frac{1}{N-1} \sum (r_t - \bar{r})^2}$
  static double calculateAnnualizedRv(List<double> prices) {
    if (prices.length < 3) return 0.25;

    final returns = <double>[];
    for (int i = 1; i < prices.length; i++) {
      final prev = prices[i - 1];
      final curr = prices[i];
      if (prev > 0 && curr > 0) {
        returns.add(log(curr / prev));
      }
    }

    if (returns.length < 2) return 0.25;

    final mean = returns.reduce((a, b) => a + b) / returns.length;
    double varianceSum = 0.0;
    for (final r in returns) {
      varianceSum += pow(r - mean, 2);
    }
    final sampleVariance = varianceSum / (returns.length - 1);
    final dailyVol = sqrt(sampleVariance);
    final annualizedVol = dailyVol * sqrt(252.0);

    return double.parse(annualizedVol.toStringAsFixed(4));
  }

  /// Constructs the full Volatility Cone across standard tenors.
  static List<VolatilityConePoint> _buildVolatilityCone({
    required List<double> prices,
    required double currentIv30,
    VolatilityTermStructure? termStructure,
  }) {
    final List<VolatilityConePoint> points = [];
    final tenors = VolatilityTenor.values;

    for (final tenor in tenors) {
      final windowSize = tenor.days;

      if (prices.length >= windowSize + 5) {
        // Compute rolling RV across all historical windows of size windowSize
        final rollingRvs = <double>[];
        for (int i = 0; i <= prices.length - windowSize; i++) {
          final windowPrices = prices.sublist(i, i + windowSize);
          final rv = calculateAnnualizedRv(windowPrices);
          if (rv > 0.01 && rv < 5.0) {
            rollingRvs.add(rv);
          }
        }

        if (rollingRvs.length >= 5) {
          rollingRvs.sort();
          final minRv = rollingRvs.first;
          final maxRv = rollingRvs.last;
          final p25Rv = _percentile(rollingRvs, 0.25);
          final medianRv = _percentile(rollingRvs, 0.50);
          final p75Rv = _percentile(rollingRvs, 0.75);

          // Current RV is the most recent rolling window of this size
          final latestWindow = prices.sublist(prices.length - windowSize);
          final currentRv = calculateAnnualizedRv(latestWindow);

          final iv = _findIvForTenor(windowSize, termStructure, currentIv30);

          points.add(VolatilityConePoint(
            days: windowSize,
            label: tenor.label,
            minRv: minRv,
            p25Rv: p25Rv,
            medianRv: medianRv,
            p75Rv: p75Rv,
            maxRv: maxRv,
            currentRv: currentRv,
            currentIv: iv,
          ));
          continue;
        }
      }

      // Fallback synthetic empirical cone if historical candle depth is insufficient
      points.add(_syntheticConePoint(tenor, currentIv30, termStructure));
    }

    return points;
  }

  /// Finds or interpolates the Implied Volatility for a specific tenor in days.
  static double _findIvForTenor(
    int tenorDays,
    VolatilityTermStructure? termStructure,
    double fallbackIv,
  ) {
    if (termStructure == null || termStructure.points.isEmpty) {
      // Slightly scale IV by tenor square root rule if term structure is unavailable
      final slopeFactor = 1.0 + (tenorDays - 30) * 0.0003;
      return max(0.10, double.parse((fallbackIv * slopeFactor).toStringAsFixed(4)));
    }

    // Exact match
    for (final p in termStructure.points) {
      if ((p.dte - tenorDays).abs() <= 3) return p.atmIv;
    }

    // Linear interpolation between nearest expiries
    TermStructurePoint? lower;
    TermStructurePoint? upper;
    for (final p in termStructure.points) {
      if (p.dte <= tenorDays) {
        if (lower == null || p.dte > lower.dte) lower = p;
      } else {
        if (upper == null || p.dte < upper.dte) upper = p;
      }
    }

    if (lower != null && upper != null && upper.dte != lower.dte) {
      final ratio = (tenorDays - lower.dte) / (upper.dte - lower.dte);
      final interpolated = lower.atmIv + ratio * (upper.atmIv - lower.atmIv);
      return double.parse(interpolated.toStringAsFixed(4));
    }

    if (lower != null) return lower.atmIv;
    if (upper != null) return upper.atmIv;

    return fallbackIv;
  }

  /// Computes IV Rank and IV Percentile over the trailing period.
  static IvRankPercentileMetrics _computeIvMetrics({
    required int tenorDays,
    required String label,
    required double currentIv,
    required List<VolatilityConePoint> conePoints,
    required List<double> prices,
  }) {
    // Determine 52-week High and Low bounds for this volatility tenor
    final matchingCone = conePoints.firstWhere(
      (p) => p.days == tenorDays,
      orElse: () => conePoints.isNotEmpty ? conePoints[0] : _defaultConePoint(tenorDays, label),
    );

    // Realistic annual volatility extremes
    final low52 = max(0.08, matchingCone.minRv * 0.9);
    final high52 = max(low52 + 0.10, matchingCone.maxRv * 1.1);

    // IV Rank = (Current - Low) / (High - Low) * 100
    final range = high52 - low52;
    final ivRank = range > 0
        ? ((currentIv - low52) / range * 100.0).clamp(0.0, 100.0)
        : 50.0;

    // IV Percentile: estimate percentile against historical realized volatility distribution
    double ivPercentile = 50.0;
    if (currentIv <= matchingCone.minRv) {
      ivPercentile = 2.0;
    } else if (currentIv >= matchingCone.maxRv) {
      ivPercentile = 98.0;
    } else if (currentIv < matchingCone.medianRv) {
      final span = matchingCone.medianRv - matchingCone.minRv;
      ivPercentile = span > 0
          ? 2.0 + (currentIv - matchingCone.minRv) / span * 48.0
          : 25.0;
    } else {
      final span = matchingCone.maxRv - matchingCone.medianRv;
      ivPercentile = span > 0
          ? 50.0 + (currentIv - matchingCone.medianRv) / span * 48.0
          : 75.0;
    }

    return IvRankPercentileMetrics(
      tenorDays: tenorDays,
      label: label,
      currentIv: currentIv,
      ivRank: double.parse(ivRank.toStringAsFixed(1)),
      ivPercentile: double.parse(ivPercentile.clamp(1.0, 99.0).toStringAsFixed(1)),
      high52Week: double.parse(high52.toStringAsFixed(3)),
      low52Week: double.parse(low52.toStringAsFixed(3)),
    );
  }

  /// Extracts strike-by-strike volatility skew and calculates 25Δ Risk Reversal.
  static VolatilitySkewAnalysis? _extractSkewAnalysis({
    required double spotPrice,
    List<Map<String, dynamic>>? optionsChains,
    List<OptionMarketData>? optionQuotes,
    double? overrideIv,
    required DateTime now,
  }) {
    if (spotPrice <= 0) return null;

    final effectiveAtmIv = overrideIv ?? 0.30;
    final points = <VolatilitySkewPoint>[];

    if (optionQuotes != null && optionQuotes.isNotEmpty) {
      // Group quotes by strike
      final quotesByStrike = <double, List<OptionMarketData>>{};
      for (final q in optionQuotes) {
        // Parse strike from OCC symbol or mark price if present
        final strike = _extractStrikeFromOcc(q.occSymbol, spotPrice);
        if (strike != null && q.impliedVolatility != null && q.impliedVolatility! > 0) {
          quotesByStrike.putIfAbsent(strike, () => []).add(q);
        }
      }

      final sortedStrikes = quotesByStrike.keys.toList()..sort();
      for (final strike in sortedStrikes) {
        final quotes = quotesByStrike[strike]!;
        double? callIv;
        double? putIv;
        double? delta;

        for (final q in quotes) {
          final isCall = q.occSymbol.contains('C');
          final iv = q.impliedVolatility;
          if (isCall) {
            callIv = iv;
            delta ??= q.delta;
          } else {
            putIv = iv;
            delta ??= q.delta;
          }
        }

        final blended = (callIv != null && putIv != null)
            ? (callIv + putIv) / 2.0
            : (callIv ?? putIv ?? effectiveAtmIv);

        final moneyness = strike / spotPrice;
        String type = 'atm';
        if (moneyness < 0.985) type = 'put';
        if (moneyness > 1.015) type = 'call';

        points.add(VolatilitySkewPoint(
          strike: strike,
          moneyness: double.parse(moneyness.toStringAsFixed(3)),
          delta: delta,
          callIv: callIv,
          putIv: putIv,
          blendedIv: double.parse(blended.toStringAsFixed(4)),
          optionType: type,
        ));
      }
    }

    // Synthetic skew generation if quotes are sparse or missing
    if (points.length < 5) {
      points.clear();
      // Generate standard equity skew (90% to 110% moneyness)
      final moneynessSteps = [0.85, 0.90, 0.925, 0.95, 0.975, 1.00, 1.025, 1.05, 1.075, 1.10, 1.15];
      for (final m in moneynessSteps) {
        final strike = double.parse((spotPrice * m).toStringAsFixed(1));
        // Downside put skew: IV increases as strike drops below 1.0
        final skewAdjustment = (1.0 - m) * 0.35 + pow(max(0, 1.0 - m), 2) * 0.8;
        final blended = max(0.12, effectiveAtmIv + skewAdjustment);

        points.add(VolatilitySkewPoint(
          strike: strike,
          moneyness: m,
          delta: m < 1.0 ? -(1.0 - m) * 2.5 : (1.15 - m) * 2.5,
          callIv: m >= 1.0 ? blended : blended * 0.96,
          putIv: m <= 1.0 ? blended : blended * 1.04,
          blendedIv: double.parse(blended.toStringAsFixed(4)),
          optionType: m < 0.99 ? 'put' : (m > 1.01 ? 'call' : 'atm'),
        ));
      }
    }

    // Derive 25-Delta Put, ATM, and 25-Delta Call IVs
    final atmPoint = points.reduce((curr, next) =>
        (curr.moneyness - 1.0).abs() < (next.moneyness - 1.0).abs() ? curr : next);
    final atmIv = atmPoint.blendedIv;

    // Approximate 25-delta put (~93-95% moneyness) and 25-delta call (~105-107% moneyness)
    final put25 = points.firstWhere(
      (p) => p.moneyness >= 0.92 && p.moneyness <= 0.96,
      orElse: () => points.first,
    );
    final call25 = points.firstWhere(
      (p) => p.moneyness >= 1.04 && p.moneyness <= 1.08,
      orElse: () => points.last,
    );

    final putSkew = double.parse((put25.blendedIv - atmIv).toStringAsFixed(4));
    final callSkew = double.parse((call25.blendedIv - atmIv).toStringAsFixed(4));
    final riskReversal = double.parse((put25.blendedIv - call25.blendedIv).toStringAsFixed(4));

    VolatilitySkewRegime regime;
    if (riskReversal > 0.04) {
      regime = VolatilitySkewRegime.steepPutSkew;
    } else if (riskReversal < -0.025) {
      regime = VolatilitySkewRegime.callSkewSqueeze;
    } else if (riskReversal.abs() <= 0.025 && (putSkew.abs() <= 0.015 && callSkew.abs() <= 0.015)) {
      regime = VolatilitySkewRegime.flat;
    } else {
      regime = VolatilitySkewRegime.balancedSmile;
    }

    final targetExp = now.add(const Duration(days: 30));

    return VolatilitySkewAnalysis(
      expirationDate: targetExp,
      daysToExpiration: 30,
      atmIv: atmIv,
      putSkew25Delta: putSkew,
      callSkew25Delta: callSkew,
      riskReversal25Delta: riskReversal,
      skewRegime: regime,
      points: points,
    );
  }

  /// Extracts the Term Structure curve across option expiries.
  static VolatilityTermStructure? _extractTermStructure({
    required double spotPrice,
    List<Map<String, dynamic>>? optionsChains,
    List<OptionMarketData>? optionQuotes,
    double? overrideIv,
    required DateTime now,
  }) {
    final points = <TermStructurePoint>[];
    final baseIv = overrideIv ?? 0.30;

    if (optionsChains != null && optionsChains.isNotEmpty) {
      final chain = optionsChains.first;
      final expDates = chain['expiration_dates'] as List<dynamic>?;
      if (expDates != null && expDates.isNotEmpty) {
        for (final exp in expDates) {
          final expStr = exp.toString();
          final parsed = DateTime.tryParse(expStr);
          if (parsed != null && parsed.isAfter(now)) {
            final dte = parsed.difference(now).inDays;
            if (dte >= 5 && dte <= 365) {
              // Extract ATM quote IV if available
              double iv = baseIv;
              if (optionQuotes != null && optionQuotes.isNotEmpty) {
                final match = optionQuotes.firstWhere(
                  (q) => q.occSymbol.contains(expStr.replaceAll('-', '').substring(2)) &&
                      q.impliedVolatility != null,
                  orElse: () => optionQuotes.first,
                );
                if (match.impliedVolatility != null && match.impliedVolatility! > 0) {
                  iv = match.impliedVolatility!;
                }
              }
              points.add(TermStructurePoint(
                expirationDate: parsed,
                dte: dte,
                atmIv: double.parse(iv.toStringAsFixed(4)),
              ));
            }
          }
        }
      }
    }

    // Synthetic fallback if term structure points are fewer than 3
    if (points.length < 3) {
      points.clear();
      final standardDtes = [7, 14, 30, 60, 90, 180, 252];
      for (final dte in standardDtes) {
        // Natural calm equity contango: slight upward slope (+0.02 across a year)
        final slopeTerm = (dte - 30) * 0.00015;
        final iv = max(0.12, baseIv + slopeTerm);
        points.add(TermStructurePoint(
          expirationDate: now.add(Duration(days: dte)),
          dte: dte,
          atmIv: double.parse(iv.toStringAsFixed(4)),
        ));
      }
    }

    points.sort((a, b) => a.dte.compareTo(b.dte));

    // Slope calculation: (Back IV - Front IV) / Days Delta
    final front = points.first;
    final back = points.last;
    final dteDiff = max(1, back.dte - front.dte);
    final slope = (back.atmIv - front.atmIv) / dteDiff;

    TermStructureRegime regime;
    if (slope > 0.00015) {
      regime = TermStructureRegime.contango;
    } else if (slope < -0.00015) {
      regime = TermStructureRegime.backwardation;
    } else {
      regime = TermStructureRegime.flat;
    }

    return VolatilityTermStructure(
      points: points,
      regime: regime,
      frontToBackSlope: double.parse(slope.toStringAsFixed(6)),
    );
  }

  /// Classifies overall volatility regime based on 30D IV metrics and cone positioning.
  static VolatilityRegime _determineRegime({
    required IvRankPercentileMetrics metrics30d,
    required VolatilityConePoint conePoint30,
    PreEarningsCrushIndicator? preEarnings,
  }) {
    if (preEarnings != null && preEarnings.isCrushImminent) {
      return VolatilityRegime.extreme;
    }

    if (metrics30d.ivRank >= 85 || (metrics30d.currentIv >= conePoint30.p75Rv && metrics30d.ivRank >= 75)) {
      return VolatilityRegime.extreme;
    }

    if (metrics30d.ivRank >= 65 || metrics30d.currentIv >= conePoint30.p75Rv) {
      return VolatilityRegime.expensive;
    }

    if (metrics30d.ivRank <= 30 || metrics30d.currentIv <= conePoint30.p25Rv) {
      return VolatilityRegime.cheap;
    }

    return VolatilityRegime.fair;
  }

  /// Generates tactical options strategy recommendations grounded in the current
  /// volatility regime, VRP, skew structure, and term structure.
  static List<VolatilityTacticalRecommendation> _generatePlaybook({
    required VolatilityRegime regime,
    required IvRankPercentileMetrics metrics30d,
    VolatilitySkewAnalysis? skew,
    VolatilityTermStructure? termStructure,
    required VolatilityRiskPremium vrp,
  }) {
    final list = <VolatilityTacticalRecommendation>[];

    final isPutSkewSteep = skew?.skewRegime == VolatilitySkewRegime.steepPutSkew;
    final isBackwardation = termStructure?.regime == TermStructureRegime.backwardation;

    switch (regime) {
      case VolatilityRegime.extreme:
      case VolatilityRegime.expensive:
        list.add(VolatilityTacticalRecommendation(
          title: 'Iron Condor (Delta 15-20)',
          strategyType: 'Net Credit',
          description:
              'Sell out-of-the-money call and put spreads simultaneously to capture high IV contraction.',
          rationale:
              'IV Rank is ${metrics30d.ivRank}% (Expensive). Historical variance risk premium is elevated (+${(vrp.vrp30d * 100).toStringAsFixed(1)}%), strongly favoring range-bound delta-neutral theta decay.',
          icon: Icons.compress_rounded,
          isRecommended: true,
        ));
        list.add(VolatilityTacticalRecommendation(
          title: isPutSkewSteep
              ? 'Bull Put Credit Spread (Elevated Put Premium)'
              : 'Defined-Risk Credit Spreads',
          strategyType: 'Net Credit',
          description: isPutSkewSteep
              ? 'Sell rich 25-30Δ put and buy protective lower put to harvest skewed downside premium.'
              : 'Sell credit spreads targeting 30-45 DTE with probability of profit > 70%.',
          rationale: isPutSkewSteep
              ? 'Downside put skew is steep (+${(skew!.putSkew25Delta * 100).toStringAsFixed(1)}% vs ATM), maximizing credit collected.'
              : 'Statistical edge lies with premium collection while options trade above historical realized move bands.',
          icon: Icons.shield_rounded,
          isRecommended: isPutSkewSteep,
        ));
        list.add(VolatilityTacticalRecommendation(
          title: 'Covered Calls / Cash-Secured Puts',
          strategyType: 'Income & Acquisition',
          description:
              'Write front-month 30Δ calls on long stock or write cash-secured puts below support.',
          rationale:
              'Premium collection yields top-quartile cash flow with built-in volatility cushion.',
          icon: Icons.monetization_on_outlined,
          isRecommended: false,
        ));
        break;

      case VolatilityRegime.cheap:
        list.add(VolatilityTacticalRecommendation(
          title: 'Long Straddle / Strangle (Cheap Volatility)',
          strategyType: 'Long Volatility',
          description:
              'Buy both ATM call and put contracts targeting a volatility expansion or explosive price breakout.',
          rationale:
              'IV is in the lowest historical quartile (IV Rank: ${metrics30d.ivRank}%, below 25% cone). Options are statistically underpricing potential price movement.',
          icon: Icons.trending_up_rounded,
          isRecommended: true,
        ));
        list.add(VolatilityTacticalRecommendation(
          title: 'Calendar / Diagonal Spreads',
          strategyType: 'Net Debit',
          description:
              'Sell short-dated front-month options and purchase long-dated back-month options at cheap baseline IV.',
          rationale:
              'Term structure favors owning underpriced distant volatility while harvesting rapid theta decay on front-month legs.',
          icon: Icons.calendar_today_rounded,
          isRecommended: true,
        ));
        list.add(VolatilityTacticalRecommendation(
          title: 'Long Directional Calls / Puts (Unhedged)',
          strategyType: 'Directional Speculation',
          description:
              'Low extrinsic value makes outright directional contracts cost-effective with low IV crush penalty.',
          rationale:
              'Unfavorable volatility drag is minimal; leverage ratio is at annual peak efficiency.',
          icon: Icons.call_made_rounded,
          isRecommended: false,
        ));
        break;

      case VolatilityRegime.fair:
        list.add(VolatilityTacticalRecommendation(
          title: 'Vertical Debit Spreads',
          strategyType: 'Directional Defined Risk',
          description:
              'Express directional conviction with balanced risk-reward ratios by selling further OTM leg.',
          rationale:
              'IV aligns with median historical movement (IV Rank: ${metrics30d.ivRank}%). Debit spreads insulate against adverse volatility shifts.',
          icon: Icons.swap_horiz_rounded,
          isRecommended: true,
        ));
        list.add(VolatilityTacticalRecommendation(
          title: 'Ratio Spreads / Jade Lizard',
          strategyType: 'Skew-Exploitation',
          description:
              'Exploit local strike asymmetries without exposing capital to directional volatility spikes.',
          rationale: isBackwardation
              ? 'Near-term backwardation provides elevated front-month premium to finance back-month protection.'
              : 'Implied volatility is within normal historical distribution, favoring balanced tactical setups.',
          icon: Icons.auto_awesome_rounded,
          isRecommended: false,
        ));
        break;
    }

    return list;
  }

  // --- Helper Methods ---

  static List<double> _extractClosePrices({
    List<InstrumentHistorical>? historicalCandles,
    List<double>? closePrices,
    required double spotPrice,
  }) {
    if (closePrices != null && closePrices.length >= 5) {
      return closePrices.where((p) => p > 0).toList();
    }

    if (historicalCandles != null && historicalCandles.isNotEmpty) {
      final list = <double>[];
      for (final h in historicalCandles) {
        final cp = h.closePrice;
        if (cp != null && cp > 0) {
          list.add(cp);
        }
      }
      if (list.length >= 5) return list;
    }

    // Generate fallback synthetic daily price series from spot price
    return _generateSyntheticPrices(spotPrice: spotPrice, count: 252);
  }

  static List<double> _generateSyntheticPrices({
    required double spotPrice,
    int count = 252,
  }) {
    final prices = <double>[];
    final random = Random(42);
    double price = max(10.0, spotPrice * 0.85);

    for (int i = 0; i < count; i++) {
      final dailyReturn = (random.nextDouble() - 0.49) * 0.024;
      price = max(1.0, price * exp(dailyReturn));
      prices.add(double.parse(price.toStringAsFixed(2)));
    }
    // Ensure final price ends near current spot price
    prices[prices.length - 1] = spotPrice;
    return prices;
  }

  static double? _extractStrikeFromOcc(String occSymbol, double spotPrice) {
    try {
      final clean = occSymbol.trim();
      final cIdx = clean.lastIndexOf('C');
      final pIdx = clean.lastIndexOf('P');
      final splitIdx = max(cIdx, pIdx);
      if (splitIdx != -1 && splitIdx < clean.length - 1) {
        final rawNum = clean.substring(splitIdx + 1);
        final parsed = double.tryParse(rawNum);
        if (parsed != null) {
          return parsed / 1000.0;
        }
      }
    } catch (_) {}
    return null;
  }

  static double _percentile(List<double> sortedValues, double p) {
    if (sortedValues.isEmpty) return 0.0;
    if (sortedValues.length == 1) return sortedValues.first;
    final index = (sortedValues.length - 1) * p;
    final lower = index.floor();
    final upper = index.ceil();
    if (lower == upper) return sortedValues[lower];
    final weight = index - lower;
    return sortedValues[lower] * (1.0 - weight) + sortedValues[upper] * weight;
  }

  static VolatilityConePoint _syntheticConePoint(
    VolatilityTenor tenor,
    double currentIv,
    VolatilityTermStructure? termStructure,
  ) {
    // Term structure dampening: longer windows have tighter min/max dispersion
    final decay = 1.0 / sqrt(tenor.days / 10.0);
    final median = max(0.15, currentIv * 0.95);
    final spread = median * 0.45 * decay;

    final minRv = double.parse(max(0.08, median - spread * 1.4).toStringAsFixed(3));
    final p25Rv = double.parse(max(minRv + 0.02, median - spread * 0.6).toStringAsFixed(3));
    final medianRv = double.parse(median.toStringAsFixed(3));
    final p75Rv = double.parse((median + spread * 0.6).toStringAsFixed(3));
    final maxRv = double.parse((median + spread * 1.5).toStringAsFixed(3));
    final currentRv = double.parse((median + (tenor.days.isEven ? 0.02 : -0.01)).toStringAsFixed(3));

    final iv = _findIvForTenor(tenor.days, termStructure, currentIv);

    return VolatilityConePoint(
      days: tenor.days,
      label: tenor.label,
      minRv: minRv,
      p25Rv: p25Rv,
      medianRv: medianRv,
      p75Rv: p75Rv,
      maxRv: maxRv,
      currentRv: currentRv,
      currentIv: iv,
    );
  }

  static VolatilityConePoint _defaultConePoint(int days, String label) {
    return VolatilityConePoint(
      days: days,
      label: label,
      minRv: 0.15,
      p25Rv: 0.20,
      medianRv: 0.26,
      p75Rv: 0.33,
      maxRv: 0.48,
      currentRv: 0.25,
      currentIv: 0.28,
    );
  }
}
