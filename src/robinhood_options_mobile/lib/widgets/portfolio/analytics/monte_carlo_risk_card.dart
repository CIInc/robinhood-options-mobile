import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/services/monte_carlo_simulator.dart';
import 'package:robinhood_options_mobile/widgets/analytics_style_card.dart';

typedef MonteCarloRunner = Future<MonteCarloSimulationResult> Function(
  MonteCarloSimulationInput input,
);

/// Interactive Monte Carlo Portfolio & Derivatives Stress Card rendering
/// forward percentile cones (5th/25th/50th/75th/95th) and path-dependent tail
/// risk metrics (VaR, CVaR, Max Drawdown distribution, and Ruin Probability).
class MonteCarloRiskCard extends StatefulWidget {
  final List<InstrumentPosition> positions;
  final List<OptionAggregatePosition> optionPositions;
  final Map<String, dynamic> metrics;
  final MonteCarloSimulationResult? initialResult;
  final MonteCarloRunner? simulatorRunner;

  const MonteCarloRiskCard({
    super.key,
    required this.positions,
    required this.optionPositions,
    required this.metrics,
    this.initialResult,
    this.simulatorRunner,
  });

  @override
  State<MonteCarloRiskCard> createState() => _MonteCarloRiskCardState();
}

class _MonteCarloRiskCardState extends State<MonteCarloRiskCard> {
  static const String _masked = r'$••••••';
  static const List<int> _horizons = [30, 90, 180, 365];
  static const List<int> _pathCounts = [1000, 2500, 5000];

  int _horizonDays = 90;
  int _numPaths = 1000;
  MonteCarloSamplingMode _samplingMode = MonteCarloSamplingMode.gbm;
  MonteCarloSimulationResult? _result;
  bool _isRunning = false;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialResult != null) {
      _result = widget.initialResult;
      _horizonDays = widget.initialResult!.horizonDays;
      _numPaths = widget.initialResult!.numPaths;
      _samplingMode = widget.initialResult!.samplingMode;
    } else {
      _scheduleSimulation();
    }
  }

  @override
  void didUpdateWidget(MonteCarloRiskCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialResult != null &&
        widget.initialResult != oldWidget.initialResult) {
      _result = widget.initialResult;
      return;
    }
    if (widget.positions.length != oldWidget.positions.length ||
        widget.optionPositions.length != oldWidget.optionPositions.length ||
        widget.metrics['volatility'] != oldWidget.metrics['volatility']) {
      _scheduleSimulation();
    }
  }

  double _resolveInitialEquity() {
    double total = 0.0;
    for (final p in widget.positions) {
      final mv = p.marketValue;
      if (mv.isFinite) total += mv;
    }
    for (final o in widget.optionPositions) {
      final mv = o.marketValue;
      if (mv.isFinite) total += mv;
    }
    if (total > 0) return total;

    final prices = widget.metrics['alignedPortfolioPrices'];
    if (prices is List && prices.isNotEmpty) {
      final last = prices.last;
      if (last is num && last.isFinite && last > 0) {
        return last.toDouble();
      }
    }
    return 0.0;
  }

  List<double> _extractHistoricalDailyReturns() {
    final prices = widget.metrics['alignedPortfolioPrices'];
    if (prices is! List || prices.length < 2) return const [];
    final returns = <double>[];
    for (var i = 1; i < prices.length; i++) {
      final prev = (prices[i - 1] as num?)?.toDouble() ?? 0.0;
      final curr = (prices[i] as num?)?.toDouble() ?? 0.0;
      if (prev > 0 && curr > 0) {
        returns.add((curr - prev) / prev);
      }
    }
    return returns;
  }

  double _resolveAnnualizedVolatility(List<double> dailyReturns) {
    final mVol = widget.metrics['volatility'];
    if (mVol is num && mVol.isFinite && mVol > 0) {
      return mVol.toDouble().clamp(0.05, 2.5);
    }
    if (dailyReturns.length >= 5) {
      final mean = dailyReturns.reduce((a, b) => a + b) / dailyReturns.length;
      double sumSq = 0.0;
      for (final r in dailyReturns) {
        final d = r - mean;
        sumSq += d * d;
      }
      final std = sqrt(sumSq / max(1, dailyReturns.length - 1));
      final ann = std * sqrt(252.0);
      if (ann.isFinite && ann > 0) {
        return ann.clamp(0.05, 2.5);
      }
    }
    return 0.22;
  }

  double _resolveAnnualizedDrift(List<double> dailyReturns) {
    final cagr = widget.metrics['cagr'];
    if (cagr is num && cagr.isFinite) {
      return cagr.toDouble().clamp(-0.5, 0.8);
    }
    if (dailyReturns.length >= 5) {
      final mean = dailyReturns.reduce((a, b) => a + b) / dailyReturns.length;
      return (mean * 252.0).clamp(-0.5, 0.8);
    }
    return 0.08;
  }

  void _scheduleSimulation() {
    final initialEq = _resolveInitialEquity();
    if (initialEq <= 0) {
      setState(() {
        _result = null;
        _isRunning = false;
      });
      return;
    }

    final returns = _extractHistoricalDailyReturns();
    final vol = _resolveAnnualizedVolatility(returns);
    final drift = _resolveAnnualizedDrift(returns);
    final greeks =
        MonteCarloGreekExposure.fromPositions(widget.optionPositions);

    final input = MonteCarloSimulationInput(
      initialEquity: initialEq,
      annualizedDrift: drift,
      annualizedVolatility: vol,
      horizonDays: _horizonDays,
      numPaths: _numPaths,
      samplingMode: _samplingMode,
      historicalDailyReturns: returns,
      greekExposure: greeks,
      seed: 42,
    );

    final reqId = ++_requestId;
    setState(() => _isRunning = true);

    final runner = widget.simulatorRunner ?? MonteCarloSimulator.simulateAsync;
    runner(input).then((res) {
      if (!mounted || reqId != _requestId) return;
      setState(() {
        _result = res;
        _isRunning = false;
      });
    }).catchError((Object _) {
      if (!mounted || reqId != _requestId) return;
      setState(() => _isRunning = false);
    });
  }

  bool _showBalances(BuildContext context) {
    try {
      return Provider.of<AccountStore>(context).showBalances;
    } catch (_) {
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showBalances = _showBalances(context);
    final currency = NumberFormat.simpleCurrency(decimalDigits: 0);
    final initialEq = _resolveInitialEquity();

    return AnalyticsStyleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_graph, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Monte Carlo Stress',
                        style: theme.textTheme.titleLarge),
                    const SizedBox(height: 2),
                    Text(
                      'Path-dependent VaR, CVaR & ruin probability',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.info_outline, size: 20),
                tooltip: 'Monte Carlo Methodology',
                onPressed: () => _showMethodologySheet(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (initialEq <= 0 && _result == null)
            Text(
              'Monte Carlo stress simulation needs priced holdings.',
              style: theme.textTheme.bodyMedium,
            )
          else ...[
            // Horizon selector
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Horizon:',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                for (final h in _horizons)
                  ChoiceChip(
                    label: Text('${h}D'),
                    selected: _horizonDays == h,
                    visualDensity: VisualDensity.compact,
                    onSelected: (sel) {
                      if (!sel || _horizonDays == h) return;
                      setState(() => _horizonDays = h);
                      _scheduleSimulation();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // Distribution & path count controls
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Model:',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                ChoiceChip(
                  label: const Text('GBM'),
                  selected: _samplingMode == MonteCarloSamplingMode.gbm,
                  visualDensity: VisualDensity.compact,
                  onSelected: (sel) {
                    if (!sel || _samplingMode == MonteCarloSamplingMode.gbm) {
                      return;
                    }
                    setState(() => _samplingMode = MonteCarloSamplingMode.gbm);
                    _scheduleSimulation();
                  },
                ),
                ChoiceChip(
                  label: const Text('Student-t'),
                  selected: _samplingMode == MonteCarloSamplingMode.studentT,
                  visualDensity: VisualDensity.compact,
                  onSelected: (sel) {
                    if (!sel ||
                        _samplingMode == MonteCarloSamplingMode.studentT) {
                      return;
                    }
                    setState(
                        () => _samplingMode = MonteCarloSamplingMode.studentT);
                    _scheduleSimulation();
                  },
                ),
                ChoiceChip(
                  label: const Text('Bootstrap'),
                  selected: _samplingMode ==
                      MonteCarloSamplingMode.historicalBootstrap,
                  visualDensity: VisualDensity.compact,
                  onSelected: (sel) {
                    if (!sel ||
                        _samplingMode ==
                            MonteCarloSamplingMode.historicalBootstrap) {
                      return;
                    }
                    setState(() => _samplingMode =
                        MonteCarloSamplingMode.historicalBootstrap);
                    _scheduleSimulation();
                  },
                ),
                const SizedBox(width: 4),
                for (final p in _pathCounts)
                  ChoiceChip(
                    label: Text(p == 1000 ? '1K' : (p == 2500 ? '2.5K' : '5K')),
                    selected: _numPaths == p,
                    visualDensity: VisualDensity.compact,
                    onSelected: (sel) {
                      if (!sel || _numPaths == p) return;
                      setState(() => _numPaths = p);
                      _scheduleSimulation();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if (_isRunning && _result == null)
              const SizedBox(
                height: 170,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_result != null) ...[
              _buildFanChart(context, _result!, showBalances, currency),
              const SizedBox(height: 12),
              _buildMetricsGrid(context, _result!, showBalances, currency),
              const SizedBox(height: 10),
              Text(
                '${_result!.numPaths} paths · ${_result!.horizonDays}D · '
                '${_samplingLabel(_result!.samplingMode)} · '
                'computed in ${_result!.elapsedMs}ms'
                '${widget.optionPositions.isNotEmpty ? ' (Greek Taylor Δ/Γ/Θ/ν active)' : ''}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  String _samplingLabel(MonteCarloSamplingMode mode) {
    switch (mode) {
      case MonteCarloSamplingMode.gbm:
        return 'GBM';
      case MonteCarloSamplingMode.studentT:
        return "Student's t (fat tails)";
      case MonteCarloSamplingMode.historicalBootstrap:
        return 'Historical Bootstrap';
    }
  }

  Widget _buildFanChart(
    BuildContext context,
    MonteCarloSimulationResult res,
    bool showBalances,
    NumberFormat currency,
  ) {
    final theme = Theme.of(context);
    final last = res.cones.length - 1;
    final p95End =
        showBalances ? currency.format(res.cones.p95[last]) : _masked;
    final p50End =
        showBalances ? currency.format(res.cones.p50[last]) : _masked;
    final p5End = showBalances ? currency.format(res.cones.p5[last]) : _masked;

    return Semantics(
      container: true,
      label:
          'Monte Carlo fan chart over ${res.horizonDays} days. 95th percentile $p95End, median $p50End, 5th percentile $p5End.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 170,
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(12),
            ),
            child: CustomPaint(
              painter: _MonteCarloFanChartPainter(
                cones: res.cones,
                initialEquity: res.initialEquity,
                primaryColor: theme.colorScheme.primary,
                baselineColor: theme.colorScheme.outline,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 4,
            children: [
              Text('5th: $p5End',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.error)),
              Text('Median: $p50End',
                  style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary)),
              Text('95th: $p95End',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: Colors.green)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(
    BuildContext context,
    MonteCarloSimulationResult res,
    bool showBalances,
    NumberFormat currency,
  ) {
    final theme = Theme.of(context);
    String fmtLoss(double dollar, double pct) {
      final pctStr = '${pct.toStringAsFixed(1)}%';
      if (!showBalances) return '$_masked ($pctStr)';
      return '-${currency.format(dollar)} ($pctStr)';
    }

    final tiles = [
      (
        '95% VaR',
        fmtLoss(res.var95Dollar, res.var95Pct),
        theme.colorScheme.error
      ),
      (
        '95% CVaR',
        fmtLoss(res.cvar95Dollar, res.cvar95Pct),
        theme.colorScheme.error
      ),
      (
        '99% CVaR',
        fmtLoss(res.cvar99Dollar, res.cvar99Pct),
        theme.colorScheme.error
      ),
      (
        '95th % Max DD',
        '${res.p95MaxDrawdownPct.toStringAsFixed(1)}%',
        Colors.orange
      ),
      (
        'Ruin Prob',
        '${(res.ruinProbability * 100.0).toStringAsFixed(1)}%',
        res.ruinProbability > 0.05 ? theme.colorScheme.error : Colors.green
      ),
      (
        'Median Outcome',
        showBalances ? currency.format(res.medianTerminalEquity) : _masked,
        theme.colorScheme.primary
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 480 ? 3 : 2;
        final width = (constraints.maxWidth - (cols - 1) * 8) / cols;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in tiles)
              SizedBox(
                width: width,
                child: _metricTile(context, item.$1, item.$2, item.$3),
              ),
          ],
        );
      },
    );
  }

  Widget _metricTile(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: '$label: $value',
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showMethodologySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Monte Carlo Stress Engine',
              style: Theme.of(ctx).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            const Text(
              '• GBM: Log-normal diffusion calibrated to portfolio volatility.\n'
              '• Student-t: Fat-tailed return shocks (df = 5) capturing crash clustering.\n'
              '• Bootstrap: Resamples realized historical daily portfolio returns.\n'
              '• Options Non-Linearity: Applies Δ, Γ, Θ, and ν Taylor-series decay per step.\n'
              '• Analytical simulation only — historical distributions do not guarantee future performance.',
            ),
          ],
        ),
      ),
    );
  }
}

class _MonteCarloFanChartPainter extends CustomPainter {
  final MonteCarloPercentileCones cones;
  final double initialEquity;
  final Color primaryColor;
  final Color baselineColor;

  _MonteCarloFanChartPainter({
    required this.cones,
    required this.initialEquity,
    required this.primaryColor,
    required this.baselineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final len = cones.length;
    if (len < 2 || size.width <= 0 || size.height <= 0) return;

    double minVal = cones.p5[0];
    double maxVal = cones.p95[0];
    for (var i = 0; i < len; i++) {
      if (cones.p5[i] < minVal) minVal = cones.p5[i];
      if (cones.p95[i] > maxVal) maxVal = cones.p95[i];
    }
    if ((maxVal - minVal).abs() < 1e-6) {
      maxVal = minVal + 1.0;
    }

    double xOf(int i) => (i / (len - 1)) * size.width;
    double yOf(double v) =>
        size.height - ((v - minVal) / (maxVal - minVal)) * size.height;

    void drawBand(List<double> lower, List<double> upper, double alpha) {
      final path = Path()..moveTo(xOf(0), yOf(upper[0]));
      for (var i = 1; i < len; i++) {
        path.lineTo(xOf(i), yOf(upper[i]));
      }
      for (var i = len - 1; i >= 0; i--) {
        path.lineTo(xOf(i), yOf(lower[i]));
      }
      path.close();
      canvas.drawPath(
        path,
        Paint()
          ..color = primaryColor.withValues(alpha: alpha)
          ..style = PaintingStyle.fill,
      );
    }

    drawBand(cones.p5, cones.p95, 0.14);
    drawBand(cones.p25, cones.p75, 0.28);

    // Baseline at initialEquity
    final baseY = yOf(initialEquity);
    final basePaint = Paint()
      ..color = baselineColor.withValues(alpha: 0.6)
      ..strokeWidth = 1.0;
    const dashWidth = 4.0;
    const dashSpace = 4.0;
    double dx = 0;
    while (dx < size.width) {
      canvas.drawLine(
        Offset(dx, baseY),
        Offset(min(dx + dashWidth, size.width), baseY),
        basePaint,
      );
      dx += dashWidth + dashSpace;
    }

    // Median trajectory (p50)
    final medianPath = Path()..moveTo(xOf(0), yOf(cones.p50[0]));
    for (var i = 1; i < len; i++) {
      medianPath.lineTo(xOf(i), yOf(cones.p50[i]));
    }
    canvas.drawPath(
      medianPath,
      Paint()
        ..color = primaryColor
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _MonteCarloFanChartPainter oldDelegate) {
    return oldDelegate.cones != cones ||
        oldDelegate.initialEquity != initialEquity ||
        oldDelegate.primaryColor != primaryColor;
  }
}
