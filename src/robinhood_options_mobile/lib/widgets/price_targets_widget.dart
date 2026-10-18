import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/model/price_target_analysis.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';

class PriceTargetsWidget extends StatefulWidget {
  final String symbol;
  final GenerativeService? generativeService;
  final PriceTargetAnalysis? preloadedAnalysis;

  const PriceTargetsWidget({
    super.key,
    required this.symbol,
    this.generativeService,
    this.preloadedAnalysis,
  });

  @override
  State<PriceTargetsWidget> createState() => _PriceTargetsWidgetState();
}

class _PriceTargetsWidgetState extends State<PriceTargetsWidget> {
  Future<PriceTargetAnalysis?>? _future;
  bool _isExpanded = false;

  final DateFormat _dateFormat = DateFormat('MMM d, yyyy h:mm a');

  @override
  void initState() {
    super.initState();
    if (widget.preloadedAnalysis != null) {
      _future = Future.value(widget.preloadedAnalysis);
    } else {
      _loadData();
    }
  }

  @override
  void didUpdateWidget(covariant PriceTargetsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.symbol != widget.symbol ||
        oldWidget.preloadedAnalysis != widget.preloadedAnalysis) {
      if (widget.preloadedAnalysis != null) {
        _future = Future.value(widget.preloadedAnalysis);
      } else {
        _loadData();
      }
    }
  }

  void _loadData() {
    setState(() {
      _future = widget.generativeService?.analyzePriceTargets(widget.symbol);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PriceTargetAnalysis?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Theme.of(context)
                      .colorScheme
                      .outlineVariant
                      .withValues(alpha: 0.4),
                ),
              ),
              child: ListTile(
                leading: Icon(Icons.error_outline,
                    color: Theme.of(context).colorScheme.error),
                title: const Text('AI price targets unavailable'),
                subtitle: Text('${snapshot.error}'),
                trailing: IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadData,
                ),
              ),
            ),
          );
        }

        final analysis = snapshot.data;
        if (analysis == null) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              context: context,
              title: 'AI Price Targets',
              icon: Icons.psychology,
              trailing: IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
                tooltip: 'Refresh price targets',
                onPressed: _loadData,
              ),
            ),
            Card(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              elevation: 0,
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.25),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Theme.of(context)
                      .colorScheme
                      .outlineVariant
                      .withValues(alpha: 0.4),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBadges(context, analysis),
                    const SizedBox(height: 16),
                    _buildTargetsAndFairValueRow(context, analysis),
                    if (analysis.confidenceScore != null) ...[
                      const SizedBox(height: 16),
                      _buildConfidenceIndicator(context, analysis),
                    ],
                    if (analysis.supportLevels.isNotEmpty ||
                        analysis.resistanceLevels.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildLevelsSection(context, analysis),
                    ],
                    if (analysis.summary.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(
                        analysis.summary,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(height: 1.4),
                      ),
                    ],
                    if (_isExpanded) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 12),
                      _buildDetailedSection(context, analysis),
                    ],
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _isExpanded = !_isExpanded;
                          });
                        },
                        icon: Icon(
                          _isExpanded ? Icons.expand_less : Icons.expand_more,
                          size: 20,
                        ),
                        label: Text(
                          _isExpanded
                              ? 'Hide Detailed Breakdown'
                              : 'View Detailed Rationale & Risks',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader({
    required BuildContext context,
    required String title,
    Widget? trailing,
    String? subtitle,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 2.0),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 19,
                      ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildBadges(BuildContext context, PriceTargetAnalysis analysis) {
    Color confidenceColor;
    if ((analysis.confidenceScore ?? 0) > 70) {
      confidenceColor = Colors.green;
    } else if ((analysis.confidenceScore ?? 0) > 40) {
      confidenceColor = Colors.orange;
    } else {
      confidenceColor = Colors.red;
    }

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        if (analysis.confidenceScore != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: confidenceColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: confidenceColor.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_outlined, size: 14, color: confidenceColor),
                const SizedBox(width: 4),
                Text(
                  '${analysis.confidenceScore!.toStringAsFixed(0)}% Confidence',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: confidenceColor,
                  ),
                ),
              ],
            ),
          ),
        if (analysis.investmentHorizon != null &&
            analysis.investmentHorizon!.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.schedule,
                    size: 14, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 4),
                Text(
                  analysis.investmentHorizon!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        if (analysis.fairValue != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .secondary
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .secondary
                    .withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.balance,
                    size: 14, color: Theme.of(context).colorScheme.secondary),
                const SizedBox(width: 4),
                Text(
                  'Fair Value: \$${analysis.fairValue!.price.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTargetsAndFairValueRow(
      BuildContext context, PriceTargetAnalysis analysis) {
    return Row(
      children: [
        if (analysis.bearishTarget != null) ...[
          Expanded(
            child: _buildMetricPill(
              context: context,
              title: 'Bearish Target',
              value: '\$${analysis.bearishTarget!.price.toStringAsFixed(2)}',
              icon: Icons.trending_down,
              color: Colors.red,
            ),
          ),
          const SizedBox(width: 8),
        ],
        if (analysis.fairValue != null) ...[
          Expanded(
            child: _buildMetricPill(
              context: context,
              title: 'Fair Value',
              value: '\$${analysis.fairValue!.price.toStringAsFixed(2)}',
              subtitle:
                  '\$${analysis.fairValue!.low.toStringAsFixed(0)} - \$${analysis.fairValue!.high.toStringAsFixed(0)}',
              icon: Icons.balance,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
        ],
        if (analysis.bullishTarget != null) ...[
          Expanded(
            child: _buildMetricPill(
              context: context,
              title: 'Bullish Target',
              value: '\$${analysis.bullishTarget!.price.toStringAsFixed(2)}',
              icon: Icons.trending_up,
              color: Colors.green,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMetricPill({
    required BuildContext context,
    required String title,
    required String value,
    String? subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConfidenceIndicator(
      BuildContext context, PriceTargetAnalysis analysis) {
    final score = analysis.confidenceScore!;
    final color =
        score > 70 ? Colors.green : (score > 40 ? Colors.orange : Colors.red);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Model Confidence',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            Text(
              '${score.toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: (score / 100).clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.5),
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildLevelsSection(
      BuildContext context, PriceTargetAnalysis analysis) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (analysis.supportLevels.isNotEmpty) ...[
          Text(
            'Support Levels',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8.0,
            runSpacing: 6.0,
            children: analysis.supportLevels
                .map((l) => Tooltip(
                      message: l.description,
                      triggerMode: TooltipTriggerMode.tap,
                      showDuration: const Duration(seconds: 3),
                      child: Chip(
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        avatar: const Icon(Icons.arrow_downward,
                            size: 14, color: Colors.green),
                        label: Text(
                          '\$${l.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        backgroundColor: Colors.green.withValues(alpha: 0.08),
                        side: BorderSide(
                            color: Colors.green.withValues(alpha: 0.25)),
                      ),
                    ))
                .toList(),
          ),
        ],
        if (analysis.supportLevels.isNotEmpty &&
            analysis.resistanceLevels.isNotEmpty)
          const SizedBox(height: 10),
        if (analysis.resistanceLevels.isNotEmpty) ...[
          Text(
            'Resistance Levels',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8.0,
            runSpacing: 6.0,
            children: analysis.resistanceLevels
                .map((l) => Tooltip(
                      message: l.description,
                      triggerMode: TooltipTriggerMode.tap,
                      showDuration: const Duration(seconds: 3),
                      child: Chip(
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        avatar: const Icon(Icons.arrow_upward,
                            size: 14, color: Colors.red),
                        label: Text(
                          '\$${l.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        backgroundColor: Colors.red.withValues(alpha: 0.08),
                        side: BorderSide(
                            color: Colors.red.withValues(alpha: 0.25)),
                      ),
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildDetailedSection(
      BuildContext context, PriceTargetAnalysis analysis) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (analysis.fairValue != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .outlineVariant
                    .withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.balance,
                        size: 16, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Valuation Methodology',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  analysis.fairValue!.method,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        height: 1.3,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (analysis.bullishTarget != null &&
            analysis.bullishTarget!.description.isNotEmpty) ...[
          _buildTargetDetailCard(
            context: context,
            title: 'Bullish Scenario',
            level: analysis.bullishTarget!,
            color: Colors.green,
            icon: Icons.trending_up,
          ),
          const SizedBox(height: 10),
        ],
        if (analysis.bearishTarget != null &&
            analysis.bearishTarget!.description.isNotEmpty) ...[
          _buildTargetDetailCard(
            context: context,
            title: 'Bearish Scenario',
            level: analysis.bearishTarget!,
            color: Colors.red,
            icon: Icons.trending_down,
          ),
          const SizedBox(height: 10),
        ],
        if (analysis.keyRisks.isNotEmpty) ...[
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.orange.withValues(alpha: 0.25),
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.warning_amber_rounded,
                        size: 16, color: Colors.orange),
                    SizedBox(width: 6),
                    Text(
                      'Key Risk Factors',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...analysis.keyRisks.map(
                  (risk) => Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ',
                            style: TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.bold)),
                        Expanded(
                          child: Text(
                            risk,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (analysis.lastUpdated != null)
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Last updated: ${_dateFormat.format(analysis.lastUpdated!.toLocal())}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).hintColor, fontSize: 11),
            ),
          ),
      ],
    );
  }

  Widget _buildTargetDetailCard({
    required BuildContext context,
    required String title,
    required PriceTargetLevel level,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                '\$${level.price.toStringAsFixed(2)}',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (level.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              level.description,
              style:
                  Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.3),
            ),
          ],
        ],
      ),
    );
  }
}
