import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/model/gamma_exposure_model.dart';
import 'package:robinhood_options_mobile/model/option_flow_item.dart';
import 'package:robinhood_options_mobile/model/zero_dte_squeeze_radar_model.dart';
import 'package:robinhood_options_mobile/services/zero_dte_squeeze_radar_service.dart';
import 'package:robinhood_options_mobile/widgets/custom_alerts_widget.dart';

/// Interactive radar widget displaying real-time 0DTE call/put flow volume,
/// dealer gamma flip velocity, and a 0-100% gamma squeeze probability gauge.
class ZeroDteSqueezeRadarWidget extends StatefulWidget {
  final String symbol;
  final double? spotPrice;
  final GammaExposureData? gexData;
  final List<OptionFlowItem>? flowItems;
  final ZeroDteSqueezeRadarResult? precomputedResult;
  final VoidCallback? onOpenGexAnalysis;
  final VoidCallback? onOpenFlow;

  const ZeroDteSqueezeRadarWidget({
    super.key,
    required this.symbol,
    this.spotPrice,
    this.gexData,
    this.flowItems,
    this.precomputedResult,
    this.onOpenGexAnalysis,
    this.onOpenFlow,
  });

  @override
  State<ZeroDteSqueezeRadarWidget> createState() =>
      _ZeroDteSqueezeRadarWidgetState();
}

class _ZeroDteSqueezeRadarWidgetState extends State<ZeroDteSqueezeRadarWidget> {
  late ZeroDteSqueezeRadarResult _result;
  final NumberFormat _currencyFormat = NumberFormat.simpleCurrency();
  final NumberFormat _compactCurrency =
      NumberFormat.compactSimpleCurrency(decimalDigits: 1);
  final NumberFormat _intFormat = NumberFormat.decimalPattern();

  @override
  void initState() {
    super.initState();
    _recompute();
  }

  @override
  void didUpdateWidget(ZeroDteSqueezeRadarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.symbol != widget.symbol ||
        oldWidget.spotPrice != widget.spotPrice ||
        oldWidget.gexData != widget.gexData ||
        oldWidget.flowItems != widget.flowItems ||
        oldWidget.precomputedResult != widget.precomputedResult) {
      _recompute();
    }
  }

  void _recompute() {
    if (widget.precomputedResult != null) {
      _result = widget.precomputedResult!;
    } else {
      _result = ZeroDteSqueezeRadarService.computeRadar(
        symbol: widget.symbol,
        spotPrice: widget.spotPrice ?? widget.gexData?.spotPrice ?? 100.0,
        gexData: widget.gexData,
        flowItems: widget.flowItems,
      );
    }
  }

  void _openAlertEditor(BuildContext context) async {
    await CustomAlertsWidget.showAlertEditor(
      context,
      initialSymbol: widget.symbol,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final riskColor = _result.riskLevel.color(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildProbabilityGaugeCard(context, theme, riskColor),
          const SizedBox(height: 16),
          _build0DteFlowVelocityCard(context, theme),
          const SizedBox(height: 16),
          _buildDealerFlipPanel(context, theme),
          const SizedBox(height: 16),
          _buildContributingFactorsCard(context, theme),
          const SizedBox(height: 16),
          _buildQuickActionButtons(context, theme),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildProbabilityGaugeCard(
      BuildContext context, ThemeData theme, Color riskColor) {
    final prob = _result.squeezeProbability;

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: riskColor.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.radar_rounded, color: riskColor, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      '${widget.symbol} 0DTE SQUEEZE RADAR',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: riskColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: riskColor.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_result.riskLevel.icon, size: 14, color: riskColor),
                      const SizedBox(width: 4),
                      Text(
                        _result.riskLevel.shortLabel.toUpperCase(),
                        style: TextStyle(
                          color: riskColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Circular / Arc style gauge indicator
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 150,
                  height: 150,
                  child: CircularProgressIndicator(
                    value: (prob / 100.0).clamp(0.0, 1.0),
                    strokeWidth: 12,
                    strokeCap: StrokeCap.round,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(riskColor),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${prob.toStringAsFixed(0)}%',
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: riskColor,
                      ),
                    ),
                    Text(
                      'SQUEEZE PROB',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _result.summary,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _build0DteFlowVelocityCard(BuildContext context, ThemeData theme) {
    final flow = _result.flowSummary;
    final callPct = (flow.callPutVolumeRatio * 100).toStringAsFixed(0);
    final putPct = ((1.0 - flow.callPutVolumeRatio) * 100).toStringAsFixed(0);

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '0DTE Flow Velocity & Volume',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${flow.sweepCount} Sweeps',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Call vs Put volume bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Row(
                children: [
                  Expanded(
                    flex: max((flow.callPutVolumeRatio * 100).toInt(), 1),
                    child: Container(
                      height: 12,
                      color: Colors.green,
                    ),
                  ),
                  Expanded(
                    flex:
                        max(((1.0 - flow.callPutVolumeRatio) * 100).toInt(), 1),
                    child: Container(
                      height: 12,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Calls: $callPct% (${_intFormat.format(flow.totalCallVolume)})',
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Text(
                  'Puts: $putPct% (${_intFormat.format(flow.totalPutVolume)})',
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            // Metrics grid
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    theme,
                    label: 'Call Velocity',
                    value: '${flow.callVelocity.toStringAsFixed(0)} /min',
                    icon: Icons.speed,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile(
                    theme,
                    label: 'Net Flow Velocity',
                    value:
                        '${flow.netVelocity >= 0 ? "+" : ""}${flow.netVelocity.toStringAsFixed(0)} /min',
                    icon: flow.netVelocity >= 0
                        ? Icons.trending_up
                        : Icons.trending_down,
                    color: flow.netVelocity >= 0 ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    theme,
                    label: '0DTE Call Premium',
                    value: _compactCurrency.format(flow.totalCallPremium),
                    icon: Icons.attach_money,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile(
                    theme,
                    label: 'Unusual Vol / OI',
                    value: '${flow.unusualVolumeOiRatio.toStringAsFixed(1)}x',
                    icon: Icons.local_fire_department_rounded,
                    color: flow.unusualVolumeOiRatio > 2.0
                        ? Colors.deepOrange
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDealerFlipPanel(BuildContext context, ThemeData theme) {
    final flip = _result.flipMetrics;
    final distPct = flip.distanceToFlipPercent != null
        ? (flip.distanceToFlipPercent! * 100).toStringAsFixed(1)
        : null;

    final regimeLabel = flip.inShortGammaZone
        ? 'Dealer Short Gamma (Amplifying)'
        : flip.dealerPositioning.displayLabel;
    final regimeColor = flip.inShortGammaZone ? Colors.deepOrange : Colors.blue;

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Dealer Gamma Flip & Regimes',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: regimeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: regimeColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    regimeLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: regimeColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildFlipItem(
                  theme,
                  label: 'Spot Price',
                  value: _currencyFormat.format(_result.spotPrice),
                  highlight: true,
                ),
                _buildFlipItem(
                  theme,
                  label: 'Gamma Flip',
                  value: flip.gammaFlip != null
                      ? _currencyFormat.format(flip.gammaFlip)
                      : 'N/A',
                  highlight: false,
                ),
                _buildFlipItem(
                  theme,
                  label: 'Flip Distance',
                  value: distPct != null ? '$distPct%' : 'N/A',
                  highlight: false,
                  color: flip.isNearFlip ? Colors.orange : null,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildFlipItem(
                  theme,
                  label: 'Call Wall (Resistance)',
                  value: flip.callWall != null
                      ? _currencyFormat.format(flip.callWall)
                      : 'N/A',
                  highlight: false,
                  color: Colors.green,
                ),
                _buildFlipItem(
                  theme,
                  label: 'Put Wall (Support)',
                  value: flip.putWall != null
                      ? _currencyFormat.format(flip.putWall)
                      : 'N/A',
                  highlight: false,
                  color: Colors.red,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContributingFactorsCard(BuildContext context, ThemeData theme) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Squeeze Probability Factors',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ..._result.factors.map((f) => _buildFactorRow(context, theme, f)),
          ],
        ),
      ),
    );
  }

  Widget _buildFactorRow(
      BuildContext context, ThemeData theme, SqueezeFactor factor) {
    final color =
        factor.isTriggered ? Colors.deepOrange : theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                factor.title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color:
                      factor.isTriggered ? color : theme.colorScheme.onSurface,
                ),
              ),
              Text(
                '${factor.score.toStringAsFixed(0)} / ${factor.maxScore.toStringAsFixed(0)} pts',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: factor.ratio,
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            factor.description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButtons(BuildContext context, ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _openAlertEditor(context),
            icon: const Icon(Icons.add_alert_rounded, size: 18),
            label: const Text('Set Squeeze Alert'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        if (widget.onOpenGexAnalysis != null) ...[
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: widget.onOpenGexAnalysis,
            icon: const Icon(Icons.layers_outlined, size: 18),
            label: const Text('GEX Profile'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMetricTile(
    ThemeData theme, {
    required String label,
    required String value,
    required IconData icon,
    Color? color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color ?? theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color ?? theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlipItem(
    ThemeData theme, {
    required String label,
    required String value,
    required bool highlight,
    Color? color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: highlight ? 15 : 13,
            fontWeight: highlight ? FontWeight.bold : FontWeight.w600,
            color: color ?? theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
