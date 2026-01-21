import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/model/price_target_analysis.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';

class PriceTargetsWidget extends StatefulWidget {
  final String symbol;
  final GenerativeService generativeService;

  const PriceTargetsWidget(
      {super.key, required this.symbol, required this.generativeService});

  @override
  State<PriceTargetsWidget> createState() => _PriceTargetsWidgetState();
}

class _PriceTargetsWidgetState extends State<PriceTargetsWidget> {
  Future<PriceTargetAnalysis?>? _future;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _future = widget.generativeService.analyzePriceTargets(widget.symbol);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.psychology,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Text('AI Price Targets',
                        style: Theme.of(context).textTheme.titleLarge),
                  ],
                ),
                IconButton(
                    icon: const Icon(Icons.refresh), onPressed: _loadData),
              ],
            ),
            const SizedBox(height: 10),
            FutureBuilder<PriceTargetAnalysis?>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(
                      child: Text('Error: ${snapshot.error}',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)));
                } else if (!snapshot.hasData || snapshot.data == null) {
                  return const Text('No analysis available.');
                }

                final analysis = snapshot.data!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (analysis.confidenceScore != null) ...[
                      Row(
                        children: [
                          Text('Confidence: ',
                              style: Theme.of(context).textTheme.bodyMedium),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: analysis.confidenceScore! / 100,
                                minHeight: 10,
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                color: analysis.confidenceScore! > 70
                                    ? Colors.green
                                    : (analysis.confidenceScore! > 40
                                        ? Colors.orange
                                        : Colors.red),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                              '${analysis.confidenceScore!.toStringAsFixed(0)}%',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (analysis.investmentHorizon != null) ...[
                      Row(
                        children: [
                          const Icon(Icons.timeline,
                              size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text('Horizon: ${analysis.investmentHorizon}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontStyle: FontStyle.italic)),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (analysis.fairValue != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Theme.of(context)
                                  .dividerColor
                                  .withValues(alpha: 0.5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.balance,
                                        size: 18,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary),
                                    const SizedBox(width: 8),
                                    Text('Fair Value Estimate',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                                fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                Text(
                                  '\$${analysis.fairValue!.price.toStringAsFixed(2)}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                ),
                              ],
                            ),
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Range',
                                    style:
                                        Theme.of(context).textTheme.bodySmall),
                                Text(
                                    '\$${analysis.fairValue!.low.toStringAsFixed(2)} - \$${analysis.fairValue!.high.toStringAsFixed(2)}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Method',
                                    style:
                                        Theme.of(context).textTheme.bodySmall),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(analysis.fairValue!.method,
                                      textAlign: TextAlign.end,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                              fontStyle: FontStyle.italic)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Text(analysis.summary,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(height: 1.4)),
                    const SizedBox(height: 20),
                    _buildSectionTitle(context, 'Support Levels'),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: analysis.supportLevels
                          .map((l) => Tooltip(
                                message: l.description,
                                triggerMode: TooltipTriggerMode.tap,
                                showDuration: const Duration(seconds: 3),
                                child: Chip(
                                  label:
                                      Text('\$${l.price.toStringAsFixed(2)}'),
                                  avatar: const Icon(Icons.arrow_downward,
                                      size: 16, color: Colors.green),
                                  backgroundColor:
                                      Colors.green.withValues(alpha: 0.1),
                                  side: BorderSide(
                                      color: Colors.green.withValues(alpha: 0.3)),
                                  padding: const EdgeInsets.all(4),
                                ),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                    _buildSectionTitle(context, 'Resistance Levels'),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: analysis.resistanceLevels
                          .map((l) => Tooltip(
                                message: l.description,
                                triggerMode: TooltipTriggerMode.tap,
                                showDuration: const Duration(seconds: 3),
                                child: Chip(
                                  label:
                                      Text('\$${l.price.toStringAsFixed(2)}'),
                                  avatar: const Icon(Icons.arrow_upward,
                                      size: 16, color: Colors.red),
                                  backgroundColor:
                                      Colors.red.withValues(alpha: 0.1),
                                  side: BorderSide(
                                      color: Colors.red.withValues(alpha: 0.3)),
                                  padding: const EdgeInsets.all(4),
                                ),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 20),
                    if (analysis.bullishTarget != null)
                      _buildTargetCard(context, 'Bullish Target',
                          analysis.bullishTarget!, Colors.green),
                    const SizedBox(height: 12),
                    if (analysis.bearishTarget != null)
                      _buildTargetCard(context, 'Bearish Target',
                          analysis.bearishTarget!, Colors.red),
                    if (analysis.keyRisks.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildSectionTitle(context, 'Key Risks'),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: Colors.orange.withValues(alpha: 0.2)),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: analysis.keyRisks
                              .map((risk) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.warning_amber_rounded,
                                            size: 18, color: Colors.orange),
                                        const SizedBox(width: 8),
                                        Expanded(
                                            child: Text(risk,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(height: 1.3))),
                                      ],
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),
                    ],
                    if (analysis.lastUpdated != null)
                      Padding(
                          padding: const EdgeInsets.only(top: 24.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                  'Last updated: ${analysis.lastUpdated!.toLocal().toString().split('.')[0]}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                          color: Theme.of(context).hintColor)),
                            ],
                          )),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildTargetCard(
      BuildContext context, String title, PriceTargetLevel level, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(color: color, fontWeight: FontWeight.bold)),
              Text('\$${level.price.toStringAsFixed(2)}',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          if (level.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(level.description,
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
