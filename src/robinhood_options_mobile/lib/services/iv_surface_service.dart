import 'dart:math';
import 'package:robinhood_options_mobile/model/iv_surface_model.dart';
import 'package:robinhood_options_mobile/model/option_marketdata.dart';

/// Pure quantitative engine for extracting, interpolating, and analyzing 3D Implied
/// Volatility Surfaces, Dupire local volatility matrices, and arbitrage diagnostics.
class IvSurfaceService {
  /// Regular grid dimensions
  static const int defaultStrikeGridCount = 17;
  static const int defaultDteGridCount = 10;

  /// Default moneyness range [0.75, 1.25]
  static const double minMoneyness = 0.75;
  static const double maxMoneyness = 1.25;

  /// Standard DTE evaluation tenors
  static const List<int> defaultGridDtes = [
    7,
    14,
    21,
    30,
    45,
    60,
    90,
    120,
    180,
    252,
  ];

  /// Computes a full [IvSurfaceAnalysis] from spot price, options chains, and quotes.
  static IvSurfaceAnalysis computeAnalysis({
    required String symbol,
    required double spotPrice,
    List<Map<String, dynamic>>? optionsChains,
    List<OptionMarketData>? optionQuotes,
    double? overrideIv,
    DateTime? simulatedNow,
  }) {
    final now = simulatedNow ?? DateTime.now();
    final double effectiveSpot = spotPrice > 0 ? spotPrice : 100.0;
    final double baseIv = (overrideIv != null && overrideIv > 0)
        ? overrideIv
        : _deriveBaseIv(optionQuotes) ?? 0.32;

    // 1. Extract raw observation points from option chains & marketdata
    final List<IvSurfacePoint> rawPoints = _extractRawPoints(
      spotPrice: effectiveSpot,
      optionsChains: optionsChains,
      optionQuotes: optionQuotes,
      baseIv: baseIv,
      now: now,
    );

    // 2. Build regularized (K, T) grid and interpolate implied volatility surface
    final IvSurfaceGrid grid = _buildRegularizedGrid(
      spotPrice: effectiveSpot,
      baseIv: baseIv,
      rawPoints: rawPoints,
    );

    // 3. Detect Calendar & Butterfly Arbitrage anomalies
    final List<ArbitrageViolation> arbitrageViolations = _detectArbitrage(
      grid: grid,
      spotPrice: effectiveSpot,
    );

    // 4. Derive quantitative metrics & regime classification
    final IvSurfaceMetrics metrics = _deriveMetrics(
      grid: grid,
      baseIv: baseIv,
      arbitrageCount: arbitrageViolations.length,
    );

    // 5. Generate 2D cross-sectional slices (Smiles & Term Structures)
    final List<IvSurfaceSlice> smileSlices = _generateSmileSlices(grid);
    final List<IvSurfaceSlice> termSlices =
        _generateTermSlices(grid, effectiveSpot);

    return IvSurfaceAnalysis(
      symbol: symbol,
      spotPrice: effectiveSpot,
      timestamp: now,
      grid: grid,
      rawPoints: rawPoints,
      metrics: metrics,
      arbitrageViolations: arbitrageViolations,
      smileSlices: smileSlices,
      termSlices: termSlices,
    );
  }

  /// Extracts individual option observations into [IvSurfacePoint]s.
  static List<IvSurfacePoint> _extractRawPoints({
    required double spotPrice,
    List<Map<String, dynamic>>? optionsChains,
    List<OptionMarketData>? optionQuotes,
    required double baseIv,
    required DateTime now,
  }) {
    final List<IvSurfacePoint> points = [];

    if (optionQuotes != null && optionQuotes.isNotEmpty) {
      for (final quote in optionQuotes) {
        final double? iv = quote.impliedVolatility;
        if (iv == null || iv <= 0.01 || iv > 5.0) continue;

        double? strike = _extractStrikeFromOcc(quote.occSymbol);
        int dte = 30;
        final expDate = _extractExpirationFromOcc(quote.occSymbol);
        if (expDate != null) {
          final diff = expDate.difference(now).inDays;
          if (diff > 0) dte = diff;
        }

        final type = quote.occSymbol.contains('P') ? 'put' : 'call';
        strike ??= spotPrice;
        final double moneyness = strike / spotPrice;

        points.add(
          IvSurfacePoint(
            strike: strike,
            dte: dte,
            moneyness: moneyness,
            iv: iv,
            optionType: type,
            delta: quote.delta,
            bid: quote.bidPrice,
            ask: quote.askPrice,
            volume: quote.volume,
            openInterest: quote.openInterest,
          ),
        );
      }
    }

    // If optionsChains was provided with raw JSON maps
    if (points.isEmpty && optionsChains != null && optionsChains.isNotEmpty) {
      for (final chain in optionsChains) {
        final expDates = chain['expiration_dates'] as List<dynamic>?;
        if (expDates == null) continue;

        for (final exp in expDates) {
          if (exp is! String) continue;
          final dt = DateTime.tryParse(exp);
          if (dt == null) continue;
          final dte = max(1, dt.difference(now).inDays);

          // Synthesize standard strikes around spot
          for (final m in [0.85, 0.90, 0.95, 1.00, 1.05, 1.10, 1.15]) {
            final strike = spotPrice * m;
            final iv = _syntheticIv(m, dte, baseIv);
            points.add(
              IvSurfacePoint(
                strike: strike,
                dte: dte,
                moneyness: m,
                iv: iv,
                optionType: m < 1.0 ? 'put' : 'call',
              ),
            );
          }
        }
      }
    }

    // If no market points exist, generate synthetic calibration points
    if (points.isEmpty) {
      for (final dte in defaultGridDtes) {
        for (double m = minMoneyness; m <= maxMoneyness + 0.001; m += 0.05) {
          final strike = spotPrice * m;
          final iv = _syntheticIv(m, dte, baseIv);
          points.add(
            IvSurfacePoint(
              strike: strike,
              dte: dte,
              moneyness: m,
              iv: iv,
              optionType: m < 1.0 ? 'put' : 'call',
            ),
          );
        }
      }
    }

    return points;
  }

  /// Builds a regular $(N \times M)$ grid and interpolates implied volatility values.
  static IvSurfaceGrid _buildRegularizedGrid({
    required double spotPrice,
    required double baseIv,
    required List<IvSurfacePoint> rawPoints,
  }) {
    // Generate strike / moneyness regular axis
    final List<double> moneynessValues = [];
    final List<double> strikes = [];
    final double mStep =
        (maxMoneyness - minMoneyness) / (defaultStrikeGridCount - 1);
    for (int i = 0; i < defaultStrikeGridCount; i++) {
      final double m = minMoneyness + (i * mStep);
      moneynessValues.add(m);
      strikes.add(spotPrice * m);
    }

    final List<int> dtes = List<int>.from(defaultGridDtes);

    // Build 2D IV Matrix: ivMatrix[strikeIdx][dteIdx]
    final List<List<double>> ivMatrix = List.generate(
      strikes.length,
      (_) => List.filled(dtes.length, 0.0),
    );

    // Surface interpolation
    for (int sIdx = 0; sIdx < strikes.length; sIdx++) {
      final double m = moneynessValues[sIdx];
      final double strike = strikes[sIdx];

      for (int dIdx = 0; dIdx < dtes.length; dIdx++) {
        final int dte = dtes[dIdx];
        final double interpolated = _interpolateIv(
          strike: strike,
          dte: dte,
          moneyness: m,
          rawPoints: rawPoints,
          baseIv: baseIv,
        );
        ivMatrix[sIdx][dIdx] = interpolated;
      }
    }

    // Build 2D Local Volatility Matrix via Dupire's formula
    final List<List<double>> localVolMatrix = _computeDupireLocalVol(
      strikes: strikes,
      moneynessValues: moneynessValues,
      dtes: dtes,
      ivMatrix: ivMatrix,
    );

    return IvSurfaceGrid(
      strikes: strikes,
      moneynessValues: moneynessValues,
      dtes: dtes,
      ivMatrix: ivMatrix,
      localVolMatrix: localVolMatrix,
    );
  }

  /// Interpolates implied volatility at $(K, T)$ using weighted inverse distance
  /// anchored to parametric skew.
  static double _interpolateIv({
    required double strike,
    required int dte,
    required double moneyness,
    required List<IvSurfacePoint> rawPoints,
    required double baseIv,
  }) {
    if (rawPoints.isEmpty) {
      return _syntheticIv(moneyness, dte, baseIv);
    }

    double weightSum = 0.0;
    double ivSum = 0.0;

    for (final p in rawPoints) {
      // Normalized distances in log-moneyness and log-time
      final double dm = (p.moneyness - moneyness).abs();
      final double dt = (log(max(1, p.dte)) - log(max(1, dte))).abs();
      final double dist = sqrt(dm * dm * 4.0 + dt * dt);

      if (dist < 0.001) {
        return p.iv.clamp(0.05, 3.0);
      }

      final double weight = 1.0 / pow(dist, 2.5);
      weightSum += weight;
      ivSum += weight * p.iv;
    }

    if (weightSum > 0.0001) {
      final double candidate = ivSum / weightSum;
      return candidate.clamp(0.05, 3.0);
    }

    return _syntheticIv(moneyness, dte, baseIv);
  }

  /// Parametric synthetic IV fallback anchored to base IV, standard skew, and term structure.
  static double _syntheticIv(double moneyness, int dte, double baseIv) {
    // Term structure curvature: slight contango (long term IV slightly higher)
    final double tYears = dte / 365.0;
    final double termFactor = 1.0 + 0.08 * log(max(0.05, tYears * 3.0 + 0.2));

    // Volatility smile / skew: asymmetric skew (puts steeper than calls)
    final double logM = log(max(0.1, moneyness));
    final double skew = -0.32 * logM + 0.45 * logM * logM;

    final double iv = baseIv * termFactor * (1.0 + skew);
    return iv.clamp(0.05, 3.0);
  }

  /// Computes Dupire Local Volatility $\sigma_{loc}(K, T)$ on the regularized grid:
  /// w(y, T) = \sigma^2(y, T) * T
  /// \sigma_{loc}^2 = \frac{ \partial w / \partial T }{ 1 - \frac{y}{w} \frac{\partial w}{\partial y} + ... }
  static List<List<double>> _computeDupireLocalVol({
    required List<double> strikes,
    required List<double> moneynessValues,
    required List<int> dtes,
    required List<List<double>> ivMatrix,
  }) {
    final int sCount = strikes.length;
    final int tCount = dtes.length;

    final List<List<double>> localVol = List.generate(
      sCount,
      (_) => List.filled(tCount, 0.0),
    );

    for (int s = 0; s < sCount; s++) {
      final double m = moneynessValues[s];
      final double y = log(max(0.01, m)); // Log-moneyness

      for (int t = 0; t < tCount; t++) {
        final double sigma = ivMatrix[s][t];
        final double tYears = dtes[t] / 365.0;
        final double w = sigma * sigma * tYears;

        // Finite differences for \partial w / \partial T
        double dwDt;
        if (t == 0) {
          final double tNext = dtes[t + 1] / 365.0;
          final double wNext =
              ivMatrix[s][t + 1] * ivMatrix[s][t + 1] * tNext;
          dwDt = (wNext - w) / max(0.001, tNext - tYears);
        } else if (t == tCount - 1) {
          final double tPrev = dtes[t - 1] / 365.0;
          final double wPrev =
              ivMatrix[s][t - 1] * ivMatrix[s][t - 1] * tPrev;
          dwDt = (w - wPrev) / max(0.001, tYears - tPrev);
        } else {
          final double tPrev = dtes[t - 1] / 365.0;
          final double tNext = dtes[t + 1] / 365.0;
          final double wPrev =
              ivMatrix[s][t - 1] * ivMatrix[s][t - 1] * tPrev;
          final double wNext =
              ivMatrix[s][t + 1] * ivMatrix[s][t + 1] * tNext;
          dwDt = (wNext - wPrev) / max(0.001, tNext - tPrev);
        }

        // Finite differences for \partial w / \partial y and \partial^2 w / \partial y^2
        double dwDy = 0.0;
        double d2wDy2 = 0.0;

        if (s > 0 && s < sCount - 1) {
          final double yPrev = log(moneynessValues[s - 1]);
          final double yNext = log(moneynessValues[s + 1]);
          final double wPrev =
              ivMatrix[s - 1][t] * ivMatrix[s - 1][t] * tYears;
          final double wNext =
              ivMatrix[s + 1][t] * ivMatrix[s + 1][t] * tYears;

          final double dy = yNext - yPrev;
          dwDy = (wNext - wPrev) / max(0.001, dy);
          d2wDy2 = (wNext - 2.0 * w + wPrev) / max(0.0001, (dy * 0.5) * (dy * 0.5));
        }

        // Dupire denominator
        final double safeW = max(0.001, w);
        final double term1 = 1.0 - (y / safeW) * dwDy;
        final double term2 = 0.25 *
            (-0.25 - (1.0 / safeW) + (y * y) / (safeW * safeW)) *
            (dwDy * dwDy);
        final double term3 = 0.5 * d2wDy2;

        final double denominator = max(0.05, term1 + term2 + term3);
        final double numerator = max(0.0001, dwDt);

        final double localVariance = numerator / denominator;
        localVol[s][t] = sqrt(max(0.001, localVariance)).clamp(0.05, 3.5);
      }
    }

    return localVol;
  }

  /// Detects calendar spread arbitrage (total variance decreasing with DTE)
  /// and butterfly strike arbitrage (concavity in strike space).
  static List<ArbitrageViolation> _detectArbitrage({
    required IvSurfaceGrid grid,
    required double spotPrice,
  }) {
    final List<ArbitrageViolation> violations = [];

    // 1. Calendar Arbitrage: Along each strike, w = sigma^2 * T must be non-decreasing
    for (int s = 0; s < grid.strikes.length; s++) {
      final double strike = grid.strikes[s];
      for (int t = 0; t < grid.dtes.length - 1; t++) {
        final double iv1 = grid.ivMatrix[s][t];
        final double iv2 = grid.ivMatrix[s][t + 1];
        final double t1 = grid.dtes[t] / 365.0;
        final double t2 = grid.dtes[t + 1] / 365.0;

        final double w1 = iv1 * iv1 * t1;
        final double w2 = iv2 * iv2 * t2;

        // If total variance drops by more than 0.002
        if (w2 < w1 - 0.002) {
          final double diff = w1 - w2;
          violations.add(
            ArbitrageViolation(
              type: ArbitrageType.calendarArbitrage,
              strike: strike,
              dte: grid.dtes[t],
              description:
                  'Calendar arbitrage at strike \$${strike.toStringAsFixed(1)}: total variance drops from ${w1.toStringAsFixed(3)} (${grid.dtes[t]}D) to ${w2.toStringAsFixed(3)} (${grid.dtes[t + 1]}D).',
              severity: diff > 0.02 ? 'critical' : (diff > 0.008 ? 'medium' : 'low'),
              discrepancy: diff,
            ),
          );
        }
      }
    }

    // 2. Butterfly Arbitrage: Along each DTE, check strike convexity
    for (int t = 0; t < grid.dtes.length; t++) {
      final int dte = grid.dtes[t];
      for (int s = 1; s < grid.strikes.length - 1; s++) {
        final double ivPrev = grid.ivMatrix[s - 1][t];
        final double ivMid = grid.ivMatrix[s][t];
        final double ivNext = grid.ivMatrix[s + 1][t];

        // Strike convexity check
        final double concavity = 2.0 * ivMid - (ivPrev + ivNext);
        if (concavity > 0.12) {
          // Sharp spike violating smooth arbitrage-free butterfly bounds
          violations.add(
            ArbitrageViolation(
              type: ArbitrageType.butterflyArbitrage,
              strike: grid.strikes[s],
              dte: dte,
              description:
                  'Butterfly arbitrage at \$${grid.strikes[s].toStringAsFixed(1)} (${dte}D): localized IV spike of ${(ivMid * 100).toStringAsFixed(1)}% creates strike concavity.',
              severity: concavity > 0.25 ? 'critical' : 'medium',
              discrepancy: concavity,
            ),
          );
        }
      }
    }

    return violations;
  }

  /// Extracts key geometry metrics, slope, skews, and overall surface regime.
  static IvSurfaceMetrics _deriveMetrics({
    required IvSurfaceGrid grid,
    required double baseIv,
    required int arbitrageCount,
  }) {
    double minIv = double.infinity;
    double maxIv = double.negativeInfinity;
    double sumIv = 0.0;
    int count = 0;

    for (final row in grid.ivMatrix) {
      for (final val in row) {
        if (val < minIv) minIv = val;
        if (val > maxIv) maxIv = val;
        sumIv += val;
        count++;
      }
    }

    final double meanIv = count > 0 ? sumIv / count : baseIv;
    if (minIv == double.infinity) minIv = baseIv * 0.8;
    if (maxIv == double.negativeInfinity) maxIv = baseIv * 1.5;

    // Find ATM strike index (closest to moneyness 1.0)
    int atmIdx = 0;
    double bestAtmDist = double.infinity;
    for (int i = 0; i < grid.moneynessValues.length; i++) {
      final dist = (grid.moneynessValues[i] - 1.0).abs();
      if (dist < bestAtmDist) {
        bestAtmDist = dist;
        atmIdx = i;
      }
    }

    // Find 25-Delta Put index (approx moneyness ~0.92) and Call index (~1.08)
    int put25Idx = 0;
    int call25Idx = grid.strikes.length - 1;
    double bestPutDist = double.infinity;
    double bestCallDist = double.infinity;
    for (int i = 0; i < grid.moneynessValues.length; i++) {
      final pDist = (grid.moneynessValues[i] - 0.92).abs();
      final cDist = (grid.moneynessValues[i] - 1.08).abs();
      if (pDist < bestPutDist) {
        bestPutDist = pDist;
        put25Idx = i;
      }
      if (cDist < bestCallDist) {
        bestCallDist = cDist;
        call25Idx = i;
      }
    }

    // Short-term DTE (~30D, index ~3) and Long-term DTE (~180D, index ~8)
    final int shortDteIdx = min(3, grid.dtes.length - 1);
    final int longDteIdx = min(8, grid.dtes.length - 1);

    final double atmShortTermIv = grid.ivMatrix[atmIdx][shortDteIdx];
    final double atmLongTermIv = grid.ivMatrix[atmIdx][longDteIdx];

    final double dtYears =
        max(0.01, (grid.dtes[longDteIdx] - grid.dtes[shortDteIdx]) / 365.0);
    final double termSlope = (atmLongTermIv - atmShortTermIv) / dtYears;

    final double ivPut25 = grid.ivMatrix[put25Idx][shortDteIdx];
    final double ivCall25 = grid.ivMatrix[call25Idx][shortDteIdx];
    final double riskReversal25D = ivPut25 - ivCall25;
    final double butterflySkew =
        ivPut25 + ivCall25 - 2.0 * atmShortTermIv;

    // Regime classification
    IvSurfaceRegime regime;
    String regimeDesc;

    if (termSlope < -0.15) {
      regime = IvSurfaceRegime.backwardation;
      regimeDesc =
          'Inverted surface: short-term IV trades at a sharp premium to back months, signaling immediate catalyst or panic pricing.';
    } else if (riskReversal25D > 0.12) {
      regime = IvSurfaceRegime.extremePutSkew;
      regimeDesc =
          'Steep downside put skew: heavy institutional demand for downside tail-risk hedging relative to calls.';
    } else if (riskReversal25D < -0.04) {
      regime = IvSurfaceRegime.callSkew;
      regimeDesc =
          'Inverted call skew: upside call IV exceeds put IV, signaling aggressive upside retail or institutional call squeeze flow.';
    } else if ((maxIv - minIv) < 0.08) {
      regime = IvSurfaceRegime.flat;
      regimeDesc =
          'Flat surface: uniform volatility distribution across strikes and expiries with muted directional hedging.';
    } else {
      regime = IvSurfaceRegime.contango;
      regimeDesc =
          'Normal contango surface: upward sloping term structure with healthy structural put skew and stable time decay.';
    }

    return IvSurfaceMetrics(
      minIv: minIv,
      maxIv: maxIv,
      meanIv: meanIv,
      atmShortTermIv: atmShortTermIv,
      atmLongTermIv: atmLongTermIv,
      termSlope: termSlope,
      riskReversal25D: riskReversal25D,
      butterflySkew: butterflySkew,
      regime: regime,
      regimeDescription: regimeDesc,
      hasArbitrage: arbitrageCount > 0,
      arbitrageCount: arbitrageCount,
    );
  }

  /// Generates 2D Volatility Smile cross-sections at specific DTE horizons.
  static List<IvSurfaceSlice> _generateSmileSlices(IvSurfaceGrid grid) {
    final List<IvSurfaceSlice> slices = [];
    final List<int> targetDtes = [14, 30, 60, 90, 180];

    for (final target in targetDtes) {
      // Find closest DTE index
      int bestIdx = 0;
      int bestDist = 9999;
      for (int i = 0; i < grid.dtes.length; i++) {
        final dist = (grid.dtes[i] - target).abs();
        if (dist < bestDist) {
          bestDist = dist;
          bestIdx = i;
        }
      }

      final actualDte = grid.dtes[bestIdx];
      final List<double> xVals = [];
      final List<String> xLabels = [];
      final List<double> ivVals = [];

      for (int s = 0; s < grid.strikes.length; s++) {
        xVals.add(grid.strikes[s]);
        xLabels.add(
            '\$${grid.strikes[s].toStringAsFixed(0)} (${(grid.moneynessValues[s] * 100).toStringAsFixed(0)}%)');
        ivVals.add(grid.ivMatrix[s][bestIdx]);
      }

      slices.add(
        IvSurfaceSlice(
          sliceType: SliceType.smileByDte,
          paramValue: actualDte.toDouble(),
          paramLabel: '${actualDte}D Expiry',
          xValues: xVals,
          xLabels: xLabels,
          ivValues: ivVals,
        ),
      );
    }

    return slices;
  }

  /// Generates 2D Term Structure cross-sections at specific moneyness levels.
  static List<IvSurfaceSlice> _generateTermSlices(
    IvSurfaceGrid grid,
    double spotPrice,
  ) {
    final List<IvSurfaceSlice> slices = [];
    final List<Map<String, dynamic>> targetMoneyness = [
      {'m': 0.85, 'label': '15% OTM Put (0.85x)'},
      {'m': 0.95, 'label': '5% OTM Put (0.95x)'},
      {'m': 1.00, 'label': 'ATM Strike (1.00x)'},
      {'m': 1.05, 'label': '5% OTM Call (1.05x)'},
      {'m': 1.15, 'label': '15% OTM Call (1.15x)'},
    ];

    for (final tm in targetMoneyness) {
      final double targetM = tm['m'] as double;
      final String label = tm['label'] as String;

      int bestIdx = 0;
      double bestDist = 9999.0;
      for (int i = 0; i < grid.moneynessValues.length; i++) {
        final dist = (grid.moneynessValues[i] - targetM).abs();
        if (dist < bestDist) {
          bestDist = dist;
          bestIdx = i;
        }
      }

      final List<double> xVals = [];
      final List<String> xLabels = [];
      final List<double> ivVals = [];

      for (int t = 0; t < grid.dtes.length; t++) {
        xVals.add(grid.dtes[t].toDouble());
        xLabels.add('${grid.dtes[t]}D');
        ivVals.add(grid.ivMatrix[bestIdx][t]);
      }

      slices.add(
        IvSurfaceSlice(
          sliceType: SliceType.termStructureByMoneyness,
          paramValue: targetM,
          paramLabel: label,
          xValues: xVals,
          xLabels: xLabels,
          ivValues: ivVals,
        ),
      );
    }

    return slices;
  }

  /// Helper to derive an empirical base IV from option quotes.
  static double? _deriveBaseIv(List<OptionMarketData>? quotes) {
    if (quotes == null || quotes.isEmpty) return null;
    final valid = quotes
        .map((q) => q.impliedVolatility)
        .where((iv) => iv != null && iv > 0.05 && iv < 4.0)
        .cast<double>()
        .toList();
    if (valid.isEmpty) return null;
    valid.sort();
    return valid[valid.length ~/ 2]; // Median
  }

  static double? _extractStrikeFromOcc(String occSymbol) {
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

  static DateTime? _extractExpirationFromOcc(String occSymbol) {
    try {
      final clean = occSymbol.trim();
      final cIdx = clean.lastIndexOf('C');
      final pIdx = clean.lastIndexOf('P');
      final splitIdx = max(cIdx, pIdx);
      if (splitIdx >= 6) {
        final datePart = clean.substring(splitIdx - 6, splitIdx);
        if (datePart.length == 6) {
          final yy = int.tryParse(datePart.substring(0, 2));
          final mm = int.tryParse(datePart.substring(2, 4));
          final dd = int.tryParse(datePart.substring(4, 6));
          if (yy != null && mm != null && dd != null) {
            final year = 2000 + yy;
            return DateTime(year, mm, dd);
          }
        }
      }
    } catch (_) {}
    return null;
  }
}
