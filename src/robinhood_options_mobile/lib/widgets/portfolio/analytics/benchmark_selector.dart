import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/portfolio_analytics_controller.dart';

/// Period and benchmark pickers for the Performance section.
///
/// Both rows drive the same controller, so changing either recomputes the
/// metrics once and every card on the page follows.
class BenchmarkSelector extends StatelessWidget {
  final PortfolioAnalyticsController controller;

  /// Fallback selection for the first frame, before the controller has been
  /// pointed at any historicals. Afterwards `controller.span` is authoritative —
  /// this widget lives on a pushed route, so a value captured from the Portfolio
  /// page at push time goes stale the moment the period changes.
  final ChartDateSpan? initialSpan;
  final void Function(ChartDateSpan)? onSpanChanged;

  const BenchmarkSelector({
    super.key,
    required this.controller,
    this.initialSpan,
    this.onSpanChanged,
  });

  static const _spans = <String, ChartDateSpan>{
    'YTD': ChartDateSpan.ytd,
    '1Y': ChartDateSpan.year,
    '2Y': ChartDateSpan.year_2,
    '3Y': ChartDateSpan.year_3,
    '5Y': ChartDateSpan.year_5,
  };

  @override
  Widget build(BuildContext context) {
    final selectedSpan = controller.span ?? initialSpan;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (selectedSpan != null && onSpanChanged != null)
          Wrap(
            spacing: 8,
            children: [
              for (final entry in _spans.entries)
                ChoiceChip(
                  label: Text(entry.key),
                  selected: selectedSpan == entry.value,
                  onSelected: (_) => onSpanChanged!(entry.value),
                ),
            ],
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final symbol in controller.allBenchmarks)
              ChoiceChip(
                label: Text(symbol),
                selected: controller.selectedBenchmark == symbol,
                onSelected: (_) => controller.selectBenchmark(symbol),
              ),
            ActionChip(
              label: const Icon(Icons.add, size: 16),
              tooltip: 'Add Custom Benchmark',
              visualDensity: VisualDensity.compact,
              onPressed: () => _promptForBenchmark(context),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _promptForBenchmark(BuildContext context) async {
    final textController = TextEditingController();
    final symbol = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Custom Benchmark'),
        content: TextField(
          controller: textController,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Ticker Symbol',
            hintText: 'e.g. BTC-USD, AAPL',
          ),
          onSubmitted: (value) =>
              Navigator.pop(context, value.trim().toUpperCase()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(
                context, textController.text.trim().toUpperCase()),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (symbol != null && symbol.isNotEmpty) {
      await controller.addCustomBenchmark(symbol);
    }
  }
}
