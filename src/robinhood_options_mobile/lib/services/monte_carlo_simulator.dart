import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';

/// Sampling distribution modes for Monte Carlo return path generation.
enum MonteCarloSamplingMode {
  gbm,
  studentT,
  historicalBootstrap,
}

/// Portfolio-level dollar Greek sensitivities used for non-linear Taylor-series
/// option payoff approximation along simulated daily paths.
class MonteCarloGreekExposure {
  final double deltaDollar;
  final double gammaDollar;
  final double thetaDailyDollar;
  final double vegaDollar;

  const MonteCarloGreekExposure({
    this.deltaDollar = 0.0,
    this.gammaDollar = 0.0,
    this.thetaDailyDollar = 0.0,
    this.vegaDollar = 0.0,
  });

  bool get hasExposure =>
      deltaDollar != 0.0 ||
      gammaDollar != 0.0 ||
      thetaDailyDollar != 0.0 ||
      vegaDollar != 0.0;

  /// Aggregates dollar-normalized Greeks across open option positions.
  factory MonteCarloGreekExposure.fromPositions(
    Iterable<OptionAggregatePosition> positions, {
    double defaultReferencePrice = 100.0,
  }) {
    double deltaDollar = 0.0;
    double gammaDollar = 0.0;
    double thetaDailyDollar = 0.0;
    double vegaDollar = 0.0;

    for (final position in positions) {
      final md = position.optionInstrument?.optionMarketData;
      final quantity = position.quantity;
      if (md == null || quantity == null || !quantity.isFinite) {
        continue;
      }

      final multiplier = position.tradeValueMultiplier ?? 100.0;
      if (!multiplier.isFinite || multiplier <= 0) continue;

      final direction =
          position.direction.toLowerCase() == 'credit' ? -1.0 : 1.0;
      final scale = quantity * multiplier * direction;
      final strike = position.optionInstrument?.strikePrice;
      final refPrice =
          (strike != null && strike > 0) ? strike : defaultReferencePrice;

      if (md.delta != null && md.delta!.isFinite) {
        deltaDollar += md.delta! * scale * refPrice;
      }
      if (md.gamma != null && md.gamma!.isFinite) {
        gammaDollar += md.gamma! * scale * refPrice * refPrice;
      }
      if (md.theta != null && md.theta!.isFinite) {
        thetaDailyDollar += md.theta! * scale;
      }
      if (md.vega != null && md.vega!.isFinite) {
        vegaDollar += md.vega! * scale;
      }
    }

    return MonteCarloGreekExposure(
      deltaDollar: deltaDollar,
      gammaDollar: gammaDollar,
      thetaDailyDollar: thetaDailyDollar,
      vegaDollar: vegaDollar,
    );
  }
}

/// Configuration for a Monte Carlo portfolio stress simulation.
class MonteCarloSimulationInput {
  final double initialEquity;
  final double annualizedDrift;
  final double annualizedVolatility;
  final int horizonDays;
  final int numPaths;
  final MonteCarloSamplingMode samplingMode;
  final double studentTDof;
  final List<double> historicalDailyReturns;
  final MonteCarloGreekExposure greekExposure;
  final double ruinDrawdownThreshold;
  final int? seed;

  const MonteCarloSimulationInput({
    required this.initialEquity,
    this.annualizedDrift = 0.08,
    this.annualizedVolatility = 0.20,
    this.horizonDays = 90,
    this.numPaths = 1000,
    this.samplingMode = MonteCarloSamplingMode.gbm,
    this.studentTDof = 5.0,
    this.historicalDailyReturns = const [],
    this.greekExposure = const MonteCarloGreekExposure(),
    this.ruinDrawdownThreshold = 0.50,
    this.seed,
  });
}

/// Percentile equity trajectories (5th, 25th, 50th, 75th, 95th) across steps
/// `0..horizonDays`.
class MonteCarloPercentileCones {
  final Float64List p5;
  final Float64List p25;
  final Float64List p50;
  final Float64List p75;
  final Float64List p95;

  const MonteCarloPercentileCones({
    required this.p5,
    required this.p25,
    required this.p50,
    required this.p75,
    required this.p95,
  });

  int get length => p50.length;
}

/// Aggregated risk metrics and fan-chart percentiles from a Monte Carlo run.
class MonteCarloSimulationResult {
  final double initialEquity;
  final int horizonDays;
  final int numPaths;
  final MonteCarloSamplingMode samplingMode;
  final MonteCarloPercentileCones cones;
  final double var95Dollar;
  final double var95Pct;
  final double var99Dollar;
  final double var99Pct;
  final double cvar95Dollar;
  final double cvar95Pct;
  final double cvar99Dollar;
  final double cvar99Pct;
  final double medianTerminalEquity;
  final double meanTerminalEquity;
  final double medianMaxDrawdownPct;
  final double p95MaxDrawdownPct;
  final double ruinProbability;
  final int elapsedMs;

  const MonteCarloSimulationResult({
    required this.initialEquity,
    required this.horizonDays,
    required this.numPaths,
    required this.samplingMode,
    required this.cones,
    required this.var95Dollar,
    required this.var95Pct,
    required this.var99Dollar,
    required this.var99Pct,
    required this.cvar95Dollar,
    required this.cvar95Pct,
    required this.cvar99Dollar,
    required this.cvar99Pct,
    required this.medianTerminalEquity,
    required this.meanTerminalEquity,
    required this.medianMaxDrawdownPct,
    required this.p95MaxDrawdownPct,
    required this.ruinProbability,
    required this.elapsedMs,
  });
}

/// High-performance on-device Monte Carlo portfolio & derivatives stress engine.
///
/// Uses pre-allocated [Float64List] buffers so 1,000–5,000 paths run in well
/// under 200ms on mobile without intermediate per-step allocations.
class MonteCarloSimulator {
  static const double _tradingDaysPerYear = 252.0;

  /// Runs a synchronous Monte Carlo simulation.
  static MonteCarloSimulationResult simulate(MonteCarloSimulationInput input) {
    final stopwatch = Stopwatch()..start();

    final initialEq = input.initialEquity;
    final days = input.horizonDays.clamp(1, 730);
    final paths = input.numPaths.clamp(100, 5000);

    if (!initialEq.isFinite || initialEq <= 0) {
      final empty = Float64List(days + 1);
      stopwatch.stop();
      return MonteCarloSimulationResult(
        initialEquity: 0.0,
        horizonDays: days,
        numPaths: paths,
        samplingMode: input.samplingMode,
        cones: MonteCarloPercentileCones(
          p5: empty,
          p25: empty,
          p50: empty,
          p75: empty,
          p95: empty,
        ),
        var95Dollar: 0.0,
        var95Pct: 0.0,
        var99Dollar: 0.0,
        var99Pct: 0.0,
        cvar95Dollar: 0.0,
        cvar95Pct: 0.0,
        cvar99Dollar: 0.0,
        cvar99Pct: 0.0,
        medianTerminalEquity: 0.0,
        meanTerminalEquity: 0.0,
        medianMaxDrawdownPct: 0.0,
        p95MaxDrawdownPct: 0.0,
        ruinProbability: 0.0,
        elapsedMs: stopwatch.elapsedMilliseconds,
      );
    }

    final sigma = input.annualizedVolatility.isFinite
        ? input.annualizedVolatility.clamp(0.01, 3.0)
        : 0.20;
    final mu = input.annualizedDrift.isFinite
        ? input.annualizedDrift.clamp(-1.0, 2.0)
        : 0.08;

    const dt = 1.0 / _tradingDaysPerYear;
    final driftStep = (mu - 0.5 * sigma * sigma) * dt;
    final volStep = sigma * sqrt(dt);

    final dof = input.studentTDof.clamp(3.0, 30.0).round();
    final tNormFactor = sqrt((dof - 2.0) / dof);

    final useBootstrap =
        input.samplingMode == MonteCarloSamplingMode.historicalBootstrap &&
            input.historicalDailyReturns.length >= 5;
    final bootstrapReturns = useBootstrap
        ? Float64List.fromList(input.historicalDailyReturns)
        : Float64List(0);

    final rng = input.seed != null ? Random(input.seed) : Random();

    final currentEquity = Float64List(paths);
    final peakEquity = Float64List(paths);
    final maxDrawdown = Float64List(paths);
    final sortBuffer = Float64List(paths);
    final ruined = Uint8List(paths);

    for (var i = 0; i < paths; i++) {
      currentEquity[i] = initialEq;
      peakEquity[i] = initialEq;
    }

    final p5 = Float64List(days + 1);
    final p25 = Float64List(days + 1);
    final p50 = Float64List(days + 1);
    final p75 = Float64List(days + 1);
    final p95 = Float64List(days + 1);

    p5[0] = initialEq;
    p25[0] = initialEq;
    p50[0] = initialEq;
    p75[0] = initialEq;
    p95[0] = initialEq;

    final hasGreeks = input.greekExposure.hasExposure;
    final deltaDollar = input.greekExposure.deltaDollar;
    final gammaDollar = input.greekExposure.gammaDollar;
    final thetaDailyDollar = input.greekExposure.thetaDailyDollar;
    final vegaDollar = input.greekExposure.vegaDollar;
    final ruinThresh = input.ruinDrawdownThreshold.clamp(0.05, 0.99);

    for (var t = 1; t <= days; t++) {
      for (var i = 0; i < paths; i++) {
        final double r;
        if (useBootstrap) {
          r = bootstrapReturns[rng.nextInt(bootstrapReturns.length)];
        } else if (input.samplingMode == MonteCarloSamplingMode.studentT) {
          final z = _nextGaussian(rng);
          var chi2 = 0.0;
          for (var d = 0; d < dof; d++) {
            final g = _nextGaussian(rng);
            chi2 += g * g;
          }
          final tVal = (z / sqrt(max(1e-9, chi2 / dof))) * tNormFactor;
          r = driftStep + volStep * tVal;
        } else {
          r = driftStep + volStep * _nextGaussian(rng);
        }

        var nextEq = useBootstrap
            ? currentEquity[i] * (1.0 + r.clamp(-0.95, 5.0))
            : currentEquity[i] * exp(r.clamp(-5.0, 5.0));

        if (hasGreeks) {
          var optPnl =
              deltaDollar * r + 0.5 * gammaDollar * r * r + thetaDailyDollar;
          if (vegaDollar != 0.0) {
            // Leverage effect: negative return spikes implied vol (vol points).
            final ivShock = (-0.5 * r + 0.005 * _nextGaussian(rng)) * 100.0;
            optPnl += vegaDollar * ivShock;
          }
          nextEq = max(0.0, nextEq + optPnl);
        }

        currentEquity[i] = nextEq;
        if (nextEq > peakEquity[i]) {
          peakEquity[i] = nextEq;
        }
        final peak = peakEquity[i];
        final dd = peak > 0 ? (peak - nextEq) / peak : 0.0;
        if (dd > maxDrawdown[i]) {
          maxDrawdown[i] = dd;
        }
        final totalLossPct = (initialEq - nextEq) / initialEq;
        if (dd >= ruinThresh || totalLossPct >= ruinThresh) {
          ruined[i] = 1;
        }
        sortBuffer[i] = nextEq;
      }

      sortBuffer.sort();
      p5[t] = _percentileSorted(sortBuffer, 0.05);
      p25[t] = _percentileSorted(sortBuffer, 0.25);
      p50[t] = _percentileSorted(sortBuffer, 0.50);
      p75[t] = _percentileSorted(sortBuffer, 0.75);
      p95[t] = _percentileSorted(sortBuffer, 0.95);
    }

    // Terminal distribution metrics (sortBuffer holds sorted terminal equity).
    double equitySum = 0.0;
    for (var i = 0; i < paths; i++) {
      equitySum += sortBuffer[i];
    }
    final meanTerminalEquity = equitySum / paths;
    final medianTerminalEquity = p50[days];

    final q05 = p5[days];
    final q01 = _percentileSorted(sortBuffer, 0.01);
    final var95Dollar = max(0.0, initialEq - q05);
    final var99Dollar = max(var95Dollar, max(0.0, initialEq - q01));

    final k95 = max(1, (0.05 * paths).floor());
    var tailSum95 = 0.0;
    for (var i = 0; i < k95; i++) {
      tailSum95 += max(0.0, initialEq - sortBuffer[i]);
    }
    final cvar95Dollar = max(var95Dollar, tailSum95 / k95);

    final k99 = max(1, (0.01 * paths).floor());
    var tailSum99 = 0.0;
    for (var i = 0; i < k99; i++) {
      tailSum99 += max(0.0, initialEq - sortBuffer[i]);
    }
    final cvar99Dollar = max(max(var99Dollar, cvar95Dollar), tailSum99 / k99);

    maxDrawdown.sort();
    final medianMaxDrawdownPct = _percentileSorted(maxDrawdown, 0.50) * 100.0;
    final p95MaxDrawdownPct = _percentileSorted(maxDrawdown, 0.95) * 100.0;

    var ruinedCount = 0;
    for (var i = 0; i < paths; i++) {
      ruinedCount += ruined[i];
    }
    final ruinProbability = ruinedCount / paths;

    stopwatch.stop();

    return MonteCarloSimulationResult(
      initialEquity: initialEq,
      horizonDays: days,
      numPaths: paths,
      samplingMode: input.samplingMode,
      cones: MonteCarloPercentileCones(
        p5: p5,
        p25: p25,
        p50: p50,
        p75: p75,
        p95: p95,
      ),
      var95Dollar: var95Dollar,
      var95Pct: (var95Dollar / initialEq) * 100.0,
      var99Dollar: var99Dollar,
      var99Pct: (var99Dollar / initialEq) * 100.0,
      cvar95Dollar: cvar95Dollar,
      cvar95Pct: (cvar95Dollar / initialEq) * 100.0,
      cvar99Dollar: cvar99Dollar,
      cvar99Pct: (cvar99Dollar / initialEq) * 100.0,
      medianTerminalEquity: medianTerminalEquity,
      meanTerminalEquity: meanTerminalEquity,
      medianMaxDrawdownPct: medianMaxDrawdownPct,
      p95MaxDrawdownPct: p95MaxDrawdownPct,
      ruinProbability: ruinProbability,
      elapsedMs: stopwatch.elapsedMilliseconds,
    );
  }

  /// Executes [simulate] off the UI isolate so 60fps animations remain smooth.
  static Future<MonteCarloSimulationResult> simulateAsync(
    MonteCarloSimulationInput input,
  ) {
    return Isolate.run(() => simulate(input));
  }

  static double _nextGaussian(Random rng) {
    final u1 = max(1e-12, rng.nextDouble());
    final u2 = rng.nextDouble();
    return sqrt(-2.0 * log(u1)) * cos(2.0 * pi * u2);
  }

  static double _percentileSorted(Float64List sorted, double p) {
    if (sorted.isEmpty) return 0.0;
    if (sorted.length == 1) return sorted[0];
    final clamped = p.clamp(0.0, 1.0);
    final idx = clamped * (sorted.length - 1);
    final lo = idx.floor();
    final hi = idx.ceil();
    if (lo == hi) return sorted[lo];
    final frac = idx - lo;
    return sorted[lo] * (1.0 - frac) + sorted[hi] * frac;
  }
}
