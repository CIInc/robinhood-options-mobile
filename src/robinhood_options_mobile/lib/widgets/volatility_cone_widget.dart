import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_historical.dart';
import 'package:robinhood_options_mobile/model/option_marketdata.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/model/volatility_cone_model.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/services/volatility_cone_service.dart';

/// Full-screen interactive widget displaying Realized vs. Implied Volatility (IV) Cone,
/// multi-timeframe IV Rank and Percentiles (30d/60d/90d), strike skew surfaces,
/// term structure curvature, and a tactical strategy playbook.
class VolatilityConeWidget extends StatefulWidget {
  final String symbol;
  final double? spotPrice;
  final User? user;
  final BrokerageUser? brokerageUser;
  final IBrokerageService? service;
  final Instrument? instrument;
  final List<InstrumentHistorical>? historicalCandles;
  final List<Map<String, dynamic>>? optionsChains;
  final List<OptionMarketData>? optionQuotes;
  final DateTime? nextEarningsDate;
  final double? overrideCurrentIv;

  const VolatilityConeWidget({
    super.key,
    required this.symbol,
    this.spotPrice,
    this.user,
    this.brokerageUser,
    this.service,
    this.instrument,
    this.historicalCandles,
    this.optionsChains,
    this.optionQuotes,
    this.nextEarningsDate,
    this.overrideCurrentIv,
  });

  @override
  State<VolatilityConeWidget> createState() => _VolatilityConeWidgetState();
}

class _VolatilityConeWidgetState extends State<VolatilityConeWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  VolatilityConeAnalysis? _analysis;
  bool _isLoading = false;
  String? _errorMessage;
  int? _selectedTenorIndex;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _computeOrFetchAnalysis();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _computeOrFetchAnalysis() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final double effectiveSpot = widget.spotPrice ??
          widget.instrument?.quoteObj?.lastTradePrice ??
          150.0;

      DateTime? resolvedEarnings = widget.nextEarningsDate;
      if (resolvedEarnings == null && widget.instrument?.earningsObj != null) {
        final earningsList = widget.instrument!.earningsObj;
        if (earningsList != null && earningsList.isNotEmpty) {
          final now = DateTime.now();
          for (final e in earningsList) {
            if (e is Map<String, dynamic> && e['report'] != null) {
              final dateStr = e['report']['date'] as String?;
              if (dateStr != null) {
                final d = DateTime.tryParse(dateStr);
                if (d != null &&
                    d.isAfter(now.subtract(const Duration(days: 1)))) {
                  resolvedEarnings = d;
                  break;
                }
              }
            }
          }
        }
      }

      final analysis = VolatilityConeService.computeAnalysis(
        symbol: widget.symbol,
        spotPrice: effectiveSpot,
        historicalCandles: widget.historicalCandles,
        optionsChains: widget.optionsChains,
        optionQuotes: widget.optionQuotes,
        nextEarningsDate: resolvedEarnings,
        overrideCurrentIv: widget.overrideCurrentIv,
      );

      setState(() {
        _analysis = analysis;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to calculate Volatility Cone: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.symbol} Volatility Cone',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (_analysis != null)
              Text(
                'Spot: \$${_analysis!.spotPrice.toStringAsFixed(2)} • ${_analysis!.overallRegime.shortLabel} Volatility',
                style: TextStyle(
                  fontSize: 12,
                  color: _analysis!.overallRegime.color(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Analysis',
            onPressed: () {
              HapticFeedback.lightImpact();
              _computeOrFetchAnalysis();
            },
          ),
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: 'Educational Guide',
            onPressed: _showEducationalGuide,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.onSurfaceVariant,
          indicatorColor: colorScheme.primary,
          tabs: const [
            Tab(
                icon: Icon(Icons.stacked_line_chart_rounded, size: 20),
                text: 'Cone & Rank'),
            Tab(
                icon: Icon(Icons.area_chart_rounded, size: 20),
                text: 'Skew & Smile'),
            Tab(
                icon: Icon(Icons.playlist_add_check_circle_rounded, size: 20),
                text: 'Playbook'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView()
              : _analysis == null
                  ? const Center(child: Text('No volatility data available'))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildConeAndRankTab(_analysis!),
                        _buildSkewAndSmileTab(_analysis!),
                        _buildPlaybookTab(_analysis!),
                      ],
                    ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning_amber_rounded,
                size: 56, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'An error occurred',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _computeOrFetchAnalysis,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  // --- Tab 1: Volatility Cone & IV Rank ---

  Widget _buildConeAndRankTab(VolatilityConeAnalysis analysis) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pre-earnings alert banner if present
          if (analysis.preEarningsIndicator != null)
            _buildPreEarningsBanner(analysis.preEarningsIndicator!),

          // Valuation Hero Banner
          _buildValuationHero(analysis),
          const SizedBox(height: 16),

          // Multi-timeframe IV Rank Cards (30D, 60D, 90D)
          _buildMultiTimeframeCards(analysis),
          const SizedBox(height: 16),

          // Interactive Volatility Cone Chart
          _buildConeChartCard(analysis),
          const SizedBox(height: 16),

          // Volatility Risk Premium (VRP) Card
          _buildVrpCard(analysis),
        ],
      ),
    );
  }

  Widget _buildPreEarningsBanner(PreEarningsCrushIndicator indicator) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      color: indicator.isCrushImminent
          ? Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.6)
          : Colors.amber.shade900.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Row(
          children: [
            Icon(
              indicator.isCrushImminent
                  ? Icons.warning_rounded
                  : Icons.event_note_rounded,
              color: indicator.isCrushImminent
                  ? Theme.of(context).colorScheme.error
                  : Colors.amber.shade700,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    indicator.isCrushImminent
                        ? 'Pre-Earnings IV Crush Hazard (${indicator.daysToEarnings}D)'
                        : 'Upcoming Earnings In ${indicator.daysToEarnings} Days',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: indicator.isCrushImminent
                          ? Theme.of(context).colorScheme.error
                          : Colors.amber.shade700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Current IV is elevated +${indicator.ivElevationPct.toStringAsFixed(1)}% above baseline realized volatility. Prepare for steep post-earnings IV crush.',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValuationHero(VolatilityConeAnalysis analysis) {
    final theme = Theme.of(context);
    final regime = analysis.overallRegime;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: regime.color(context).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child:
                      Icon(regime.icon, color: regime.color(context), size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        regime.label,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: regime.color(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '30D IV: ${(analysis.metrics30d.currentIv * 100).toStringAsFixed(1)}% • 30D RV: ${(analysis.conePoints.firstWhere((p) => p.days == 30, orElse: () => analysis.conePoints.first).currentRv * 100).toStringAsFixed(1)}%',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              regime.guidance,
              style: const TextStyle(fontSize: 13, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiTimeframeCards(VolatilityConeAnalysis analysis) {
    final metrics = [
      analysis.metrics30d,
      analysis.metrics60d,
      analysis.metrics90d
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Multi-Timeframe IV Metrics',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 420;
            if (isNarrow) {
              return Column(
                children: metrics
                    .map((m) => Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: _buildSingleMetricCard(m),
                        ))
                    .toList(),
              );
            }
            return Row(
              children: metrics
                  .map((m) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: _buildSingleMetricCard(m),
                        ),
                      ))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSingleMetricCard(IvRankPercentileMetrics metric) {
    final color = _getRankColor(metric.ivRank);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  metric.label,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  '${(metric.currentIv * 100).toStringAsFixed(1)}% IV',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('IV Rank', style: TextStyle(fontSize: 11)),
                Text(
                  '${metric.ivRank.toStringAsFixed(0)}%',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: color, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (metric.ivRank / 100.0).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('IV Percentile', style: TextStyle(fontSize: 11)),
                Text(
                  '${metric.ivPercentile.toStringAsFixed(0)}%',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '52W: ${(metric.low52Week * 100).toStringAsFixed(0)}% - ${(metric.high52Week * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConeChartCard(VolatilityConeAnalysis analysis) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                const Text(
                  'Volatility Cone Distribution',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Tenor (Days)',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Realized volatility bands (Min to Max) with current RV and IV curves.',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              width: double.infinity,
              child: CustomPaint(
                painter: _VolatilityConePainter(
                  points: analysis.conePoints,
                  selectedTenorIndex: _selectedTenorIndex,
                  context: context,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildChartLegend(),
            const Divider(height: 24),
            _buildTenorChips(analysis),
          ],
        ),
      ),
    );
  }

  Widget _buildChartLegend() {
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        _buildLegendItem(Colors.amber.shade700, 'Current Implied Vol (IV)',
            isLine: true),
        _buildLegendItem(Colors.blue.shade600, 'Current Realized Vol (RV)',
            isLine: true),
        _buildLegendItem(Colors.purple.shade300.withValues(alpha: 0.5),
            '25%–75% Band (IQR)'),
        _buildLegendItem(Colors.grey.withValues(alpha: 0.3), 'Min–Max Range'),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String text, {bool isLine = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: isLine ? 16 : 10,
          height: isLine ? 3 : 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(isLine ? 1 : 2),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(text, style: const TextStyle(fontSize: 11)),
        ),
      ],
    );
  }

  Widget _buildTenorChips(VolatilityConeAnalysis analysis) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: analysis.conePoints.asMap().entries.map((entry) {
          final idx = entry.key;
          final p = entry.value;
          final isSelected = _selectedTenorIndex == idx;

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(
                  '${p.label} (${(p.currentRv * 100).toStringAsFixed(0)}% RV)'),
              selected: isSelected,
              onSelected: (sel) {
                setState(() {
                  _selectedTenorIndex = sel ? idx : null;
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildVrpCard(VolatilityConeAnalysis analysis) {
    final vrp = analysis.vrp;
    final vrpPct = vrp.vrp30d * 100;
    final isRich = vrp.isRich;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                const Text(
                  'Volatility Risk Premium (VRP)',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isRich
                            ? Colors.orange.shade800
                            : Colors.green.shade700)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isRich
                        ? 'IV > RV (+${vrpPct.toStringAsFixed(1)}%)'
                        : 'IV < RV (${vrpPct.toStringAsFixed(1)}%)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isRich
                          ? Colors.orange.shade800
                          : Colors.green.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isRich
                  ? 'Implied Volatility exceeds 30-Day Realized Volatility by ${vrpPct.toStringAsFixed(1)} percentage points (IV/RV Ratio: ${vrp.vrpRatio.toStringAsFixed(2)}x). Historically, options sellers capture this spread as variance risk compensation.'
                  : 'Implied Volatility trades at a discount to trailing 30-Day Realized Volatility. Options buyers enjoy favorable leverage without paying an excessive volatility premium.',
              style: const TextStyle(fontSize: 13, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }

  // --- Tab 2: Skew & Smile Surface ---

  Widget _buildSkewAndSmileTab(VolatilityConeAnalysis analysis) {
    final skew = analysis.skewAnalysis;
    final term = analysis.termStructure;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Skew Hero
          if (skew != null) ...[
            _buildSkewHeroCard(skew),
            const SizedBox(height: 16),
            _buildSkewCurveCard(skew, analysis.spotPrice),
            const SizedBox(height: 16),
          ],

          // Term Structure Card
          if (term != null) ...[
            _buildTermStructureCard(term),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildSkewHeroCard(VolatilitySkewAnalysis skew) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  skew.skewRegime.label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: skew.skewRegime.color(context),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '25Δ Risk Reversal: ${(skew.riskReversal25Delta * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              skew.skewRegime.description,
              style: const TextStyle(fontSize: 13, height: 1.35),
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildSkewMetricChip(
                    'Put Skew (25Δ)',
                    '+${(skew.putSkew25Delta * 100).toStringAsFixed(1)}%',
                    Colors.orange.shade800,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSkewMetricChip(
                    'ATM 30D IV',
                    '${(skew.atmIv * 100).toStringAsFixed(1)}%',
                    Colors.blue.shade600,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSkewMetricChip(
                    'Call Skew (25Δ)',
                    '${(skew.callSkew25Delta * 100).toStringAsFixed(1)}%',
                    Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkewMetricChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildSkewCurveCard(VolatilitySkewAnalysis skew, double spotPrice) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Strike Skew & Smile Curve',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Implied volatility across strikes ($spotPrice spot). High put IV reflects downside hedging.',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              width: double.infinity,
              child: CustomPaint(
                painter: _SkewCurvePainter(
                  points: skew.points,
                  context: context,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 16,
                headingRowHeight: 32,
                dataRowMinHeight: 28,
                dataRowMaxHeight: 32,
                columns: const [
                  DataColumn(
                      label: Text('Strike', style: TextStyle(fontSize: 11))),
                  DataColumn(
                      label: Text('Moneyness', style: TextStyle(fontSize: 11))),
                  DataColumn(
                      label: Text('Type', style: TextStyle(fontSize: 11))),
                  DataColumn(
                      label:
                          Text('Blended IV', style: TextStyle(fontSize: 11))),
                ],
                rows: skew.points.map((p) {
                  return DataRow(cells: [
                    DataCell(Text('\$${p.strike.toStringAsFixed(1)}',
                        style: const TextStyle(fontSize: 11))),
                    DataCell(Text('${(p.moneyness * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(fontSize: 11))),
                    DataCell(Text(p.optionType.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: p.optionType == 'put'
                              ? Colors.orange.shade800
                              : (p.optionType == 'call'
                                  ? Colors.green.shade700
                                  : Colors.blue),
                        ))),
                    DataCell(Text('${(p.blendedIv * 100).toStringAsFixed(1)}%',
                        style: const TextStyle(fontSize: 11))),
                  ]);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermStructureCard(VolatilityTermStructure term) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                const Text(
                  'Volatility Term Structure',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: term.regime.color(context).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    term.regime.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: term.regime.color(context),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              term.regime.description,
              style: const TextStyle(fontSize: 13, height: 1.35),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              width: double.infinity,
              child: CustomPaint(
                painter: _TermStructurePainter(
                  points: term.points,
                  context: context,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Tab 3: Tactical Strategy Playbook ---

  Widget _buildPlaybookTab(VolatilityConeAnalysis analysis) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          color: Theme.of(context)
              .colorScheme
              .primaryContainer
              .withValues(alpha: 0.4),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline_rounded,
                    color: Theme.of(context).colorScheme.primary, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Strategies optimized for ${analysis.symbol}\'s ${analysis.overallRegime.shortLabel} Volatility Regime and ${analysis.metrics30d.ivRank.toStringAsFixed(0)}% IV Rank.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...analysis.recommendations.map((rec) => _buildPlaybookCard(rec)),
      ],
    );
  }

  Widget _buildPlaybookCard(VolatilityTacticalRecommendation rec) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: rec.isRecommended
            ? BorderSide(
                color: Theme.of(context).colorScheme.primary, width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(rec.icon,
                          color: Theme.of(context).colorScheme.primary,
                          size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          rec.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                ),
                if (rec.isRecommended)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'RECOMMENDED',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                rec.strategyType,
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 10),
            Text(rec.description,
                style: const TextStyle(fontSize: 13, height: 1.3)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Rationale: ',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  Expanded(
                    child: Text(rec.rationale,
                        style: const TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEducationalGuide() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.school_rounded),
            SizedBox(width: 8),
            Text('Volatility Cone Guide'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What is a Volatility Cone?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              SizedBox(height: 4),
              Text(
                'A Volatility Cone plots the historical distribution (Min, 25%, Median, 75%, Max) of Realized Volatility across different time horizons (10 to 252 days). It allows you to immediately see whether current Implied Volatility (IV) is statistically cheap or expensive.',
                style: TextStyle(fontSize: 12),
              ),
              SizedBox(height: 12),
              Text(
                'IV Rank vs. IV Percentile',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              SizedBox(height: 4),
              Text(
                '• IV Rank: Measures where current IV sits relative to its 52-week high and low: (IV - Low) / (High - Low).\n• IV Percentile: The percentage of trading days over the past year where IV was lower than current levels.',
                style: TextStyle(fontSize: 12),
              ),
              SizedBox(height: 12),
              Text(
                'Volatility Risk Premium (VRP)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              SizedBox(height: 4),
              Text(
                'VRP = IV - Realized Volatility. Implied volatility typically trades higher than actual realized volatility ~85% of the time, rewarding premium sellers who harvest this spread.',
                style: TextStyle(fontSize: 12),
              ),
              SizedBox(height: 12),
              Text(
                'Strike Skew & Risk Reversal',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              SizedBox(height: 4),
              Text(
                'Equities typically exhibit Put Skew (downside puts priced higher than upside calls). A steep 25Δ Risk Reversal indicates aggressive downside disaster hedging.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Color _getRankColor(double rank) {
    if (rank >= 80) return Colors.red;
    if (rank >= 60) return Colors.orange.shade800;
    if (rank <= 25) return Colors.green.shade700;
    return Colors.blue.shade600;
  }
}

/// Custom painter for the Volatility Cone and Realized/Implied Vol curves.
class _VolatilityConePainter extends CustomPainter {
  final List<VolatilityConePoint> points;
  final int? selectedTenorIndex;
  final BuildContext context;

  _VolatilityConePainter({
    required this.points,
    this.selectedTenorIndex,
    required this.context,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    const leftPad = 32.0;
    const rightPad = 16.0;
    const topPad = 16.0;
    const bottomPad = 24.0;

    final chartWidth = size.width - leftPad - rightPad;
    final chartHeight = size.height - topPad - bottomPad;

    // Determine max vol for Y-axis scale
    double maxVol = 0.50;
    for (final p in points) {
      maxVol = max(maxVol, max(p.maxRv, p.currentIv ?? 0));
    }
    maxVol = (maxVol * 1.15).clamp(0.40, 1.50);

    // X coordinates
    final xCoords = <double>[];
    for (int i = 0; i < points.length; i++) {
      final x = leftPad + (i / (points.length - 1)) * chartWidth;
      xCoords.add(x);
    }

    double getY(double vol) {
      final norm = (vol / maxVol).clamp(0.0, 1.0);
      return topPad + (1.0 - norm) * chartHeight;
    }

    // Draw Y-axis gridlines
    final gridPaint = Paint()
      ..color = colorScheme.outlineVariant.withValues(alpha: 0.25)
      ..strokeWidth = 1;

    final textStyle = TextStyle(
      fontSize: 9,
      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
    );

    for (double v = 0.10; v <= maxVol; v += 0.15) {
      final y = getY(v);
      canvas.drawLine(
          Offset(leftPad, y), Offset(size.width - rightPad, y), gridPaint);
      final tp = TextPainter(
        text: TextSpan(
            text: '${(v * 100).toStringAsFixed(0)}%', style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(2, y - 6));
    }

    // Draw Min-Max shaded cone
    final minMaxPath = Path();
    minMaxPath.moveTo(xCoords[0], getY(points[0].maxRv));
    for (int i = 1; i < points.length; i++) {
      minMaxPath.lineTo(xCoords[i], getY(points[i].maxRv));
    }
    for (int i = points.length - 1; i >= 0; i--) {
      minMaxPath.lineTo(xCoords[i], getY(points[i].minRv));
    }
    minMaxPath.close();

    final minMaxPaint = Paint()
      ..color = colorScheme.surfaceContainerHighest.withValues(alpha: 0.45)
      ..style = PaintingStyle.fill;
    canvas.drawPath(minMaxPath, minMaxPaint);

    // Draw 25%-75% Interquartile Range (IQR) shaded band
    final iqrPath = Path();
    iqrPath.moveTo(xCoords[0], getY(points[0].p75Rv));
    for (int i = 1; i < points.length; i++) {
      iqrPath.lineTo(xCoords[i], getY(points[i].p75Rv));
    }
    for (int i = points.length - 1; i >= 0; i--) {
      iqrPath.lineTo(xCoords[i], getY(points[i].p25Rv));
    }
    iqrPath.close();

    final iqrPaint = Paint()
      ..color = Colors.purple.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    canvas.drawPath(iqrPath, iqrPaint);

    // Draw Median line
    final medianPaint = Paint()
      ..color = Colors.purple.shade300
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final medianPath = Path();
    medianPath.moveTo(xCoords[0], getY(points[0].medianRv));
    for (int i = 1; i < points.length; i++) {
      medianPath.lineTo(xCoords[i], getY(points[i].medianRv));
    }
    canvas.drawPath(medianPath, medianPaint);

    // Draw Current RV Line (Blue)
    final rvPaint = Paint()
      ..color = Colors.blue.shade600
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final rvPath = Path();
    rvPath.moveTo(xCoords[0], getY(points[0].currentRv));
    for (int i = 1; i < points.length; i++) {
      rvPath.lineTo(xCoords[i], getY(points[i].currentRv));
    }
    canvas.drawPath(rvPath, rvPaint);

    // Draw Current IV Line (Amber/Gold)
    final ivPaint = Paint()
      ..color = Colors.amber.shade700
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final ivPath = Path();
    bool hasStartedIv = false;
    for (int i = 0; i < points.length; i++) {
      if (points[i].currentIv != null) {
        final y = getY(points[i].currentIv!);
        if (!hasStartedIv) {
          ivPath.moveTo(xCoords[i], y);
          hasStartedIv = true;
        } else {
          ivPath.lineTo(xCoords[i], y);
        }
      }
    }
    canvas.drawPath(ivPath, ivPaint);

    // Draw Points & X-Labels
    for (int i = 0; i < points.length; i++) {
      final x = xCoords[i];
      final p = points[i];

      // RV point
      final rvY = getY(p.currentRv);
      canvas.drawCircle(
          Offset(x, rvY), 4, Paint()..color = Colors.blue.shade600);
      canvas.drawCircle(Offset(x, rvY), 2, Paint()..color = Colors.white);

      // IV point
      if (p.currentIv != null) {
        final ivY = getY(p.currentIv!);
        canvas.drawCircle(
            Offset(x, ivY), 4, Paint()..color = Colors.amber.shade700);
        canvas.drawCircle(Offset(x, ivY), 2, Paint()..color = Colors.white);
      }

      // Selected Tenor highlight
      if (selectedTenorIndex == i) {
        canvas.drawLine(
          Offset(x, topPad),
          Offset(x, topPad + chartHeight),
          Paint()
            ..color = colorScheme.primary
            ..strokeWidth = 1.5,
        );
      }

      // X Label
      final tp = TextPainter(
        text: TextSpan(text: p.label, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, size.height - bottomPad + 4));
    }
  }

  @override
  bool shouldRepaint(covariant _VolatilityConePainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.selectedTenorIndex != selectedTenorIndex;
  }
}

/// Custom painter for strike-by-strike Volatility Skew / Smile.
class _SkewCurvePainter extends CustomPainter {
  final List<VolatilitySkewPoint> points;
  final BuildContext context;

  _SkewCurvePainter({required this.points, required this.context});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    const leftPad = 32.0;
    const rightPad = 16.0;
    const topPad = 16.0;
    const bottomPad = 24.0;

    final chartWidth = size.width - leftPad - rightPad;
    final chartHeight = size.height - topPad - bottomPad;

    double minIv = points.map((p) => p.blendedIv).reduce(min);
    double maxIv = points.map((p) => p.blendedIv).reduce(max);
    minIv = max(0.05, minIv * 0.85);
    maxIv = max(minIv + 0.10, maxIv * 1.15);

    double minM = points.map((p) => p.moneyness).reduce(min);
    double maxM = points.map((p) => p.moneyness).reduce(max);
    final spanM = max(0.05, maxM - minM);

    double getX(double moneyness) =>
        leftPad + ((moneyness - minM) / spanM) * chartWidth;

    double getY(double iv) {
      final norm = ((iv - minIv) / (maxIv - minIv)).clamp(0.0, 1.0);
      return topPad + (1.0 - norm) * chartHeight;
    }

    // ATM vertical marker at 1.0
    if (minM <= 1.0 && maxM >= 1.0) {
      final atmX = getX(1.0);
      canvas.drawLine(
        Offset(atmX, topPad),
        Offset(atmX, topPad + chartHeight),
        Paint()
          ..color = colorScheme.outlineVariant.withValues(alpha: 0.5)
          ..strokeWidth = 1,
      );
    }

    final path = Path();
    path.moveTo(getX(points[0].moneyness), getY(points[0].blendedIv));
    for (int i = 1; i < points.length; i++) {
      path.lineTo(getX(points[i].moneyness), getY(points[i].blendedIv));
    }

    final paint = Paint()
      ..color = Colors.teal.shade500
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, paint);

    for (final p in points) {
      final x = getX(p.moneyness);
      final y = getY(p.blendedIv);
      final ptColor = p.optionType == 'put'
          ? Colors.orange.shade800
          : (p.optionType == 'call' ? Colors.green.shade700 : Colors.blue);
      canvas.drawCircle(Offset(x, y), 3.5, Paint()..color = ptColor);
    }
  }

  @override
  bool shouldRepaint(covariant _SkewCurvePainter oldDelegate) => true;
}

/// Custom painter for the Volatility Term Structure curve.
class _TermStructurePainter extends CustomPainter {
  final List<TermStructurePoint> points;
  final BuildContext context;

  _TermStructurePainter({required this.points, required this.context});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    const leftPad = 32.0;
    const rightPad = 16.0;
    const topPad = 16.0;
    const bottomPad = 24.0;

    final chartWidth = size.width - leftPad - rightPad;
    final chartHeight = size.height - topPad - bottomPad;

    double minIv = points.map((p) => p.atmIv).reduce(min);
    double maxIv = points.map((p) => p.atmIv).reduce(max);
    minIv = max(0.05, minIv * 0.90);
    maxIv = max(minIv + 0.10, maxIv * 1.10);

    final maxDte = points.map((p) => p.dte).reduce(max);
    final minDte = points.map((p) => p.dte).reduce(min);
    final spanDte = max(1, maxDte - minDte);

    double getX(int dte) => leftPad + ((dte - minDte) / spanDte) * chartWidth;
    double getY(double iv) {
      final norm = ((iv - minIv) / (maxIv - minIv)).clamp(0.0, 1.0);
      return topPad + (1.0 - norm) * chartHeight;
    }

    final path = Path();
    path.moveTo(getX(points[0].dte), getY(points[0].atmIv));
    for (int i = 1; i < points.length; i++) {
      path.lineTo(getX(points[i].dte), getY(points[i].atmIv));
    }

    final paint = Paint()
      ..color = colorScheme.primary
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, paint);

    for (final p in points) {
      final x = getX(p.dte);
      final y = getY(p.atmIv);
      canvas.drawCircle(Offset(x, y), 4, Paint()..color = colorScheme.primary);
      canvas.drawCircle(Offset(x, y), 2, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _TermStructurePainter oldDelegate) => true;
}
