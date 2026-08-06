import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/portfolio_analytics_controller.dart';

const _spans = <String, ChartDateSpan>{
  'YTD': ChartDateSpan.ytd,
  '1Y': ChartDateSpan.year,
  '2Y': ChartDateSpan.year_2,
  '3Y': ChartDateSpan.year_3,
  '5Y': ChartDateSpan.year_5,
};

/// The period chips shared by every analytics section, pinned under the app bar.
///
/// Volatility, max drawdown, beta and Sharpe are all functions of the period,
/// and they are read on Risk as often as on Performance. Living in the section
/// scaffold's `bottom` slot on both pages — rather than as a card on Performance
/// alone — means neither page can show numbers keyed to a window the reader can
/// neither see nor change from where they are standing.
class AnalyticsPeriodBar extends StatelessWidget implements PreferredSizeWidget {
  final PortfolioAnalyticsController controller;

  /// Fallback selection for the first frame, before the controller has been
  /// pointed at any historicals. Afterwards `controller.span` is authoritative —
  /// this widget lives on a pushed route, so a value captured from the Portfolio
  /// page at push time goes stale the moment the period changes.
  final ChartDateSpan? initialSpan;
  final void Function(ChartDateSpan)? onSpanChanged;

  const AnalyticsPeriodBar({
    super.key,
    required this.controller,
    this.initialSpan,
    this.onSpanChanged,
  });

  ChartDateSpan? get _selectedSpan => controller.span ?? initialSpan;

  bool get _isVisible => _selectedSpan != null && onSpanChanged != null;

  /// Collapses to nothing rather than reserving a strip the chips never fill,
  /// for the sections reached before any period is known.
  @override
  Size get preferredSize => Size.fromHeight(_isVisible ? 52 : 0);

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();
    final selected = _selectedSpan;

    return SizedBox(
      height: 52,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Wrap(
          spacing: 8,
          children: [
            for (final entry in _spans.entries)
              ChoiceChip(
                label: Text(entry.key),
                selected: selected == entry.value,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => onSpanChanged!(entry.value),
              ),
          ],
        ),
      ),
    );
  }
}

/// Benchmark picker as an app-bar action, showing the live selection.
///
/// Beta and correlation depend on the benchmark just as the return comparison
/// does, so it belongs on Risk too — but as a menu rather than a second chip
/// row, since it is changed far less often than the period.
class BenchmarkMenuButton extends StatelessWidget {
  final PortfolioAnalyticsController controller;

  const BenchmarkMenuButton({super.key, required this.controller});

  static const _addCustomValue = '__add_custom__';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopupMenuButton<String>(
      tooltip: 'Benchmark',
      onSelected: (value) {
        if (value == _addCustomValue) {
          _promptForBenchmark(context);
        } else {
          controller.selectBenchmark(value);
        }
      },
      itemBuilder: (context) => [
        for (final symbol in controller.allBenchmarks)
          CheckedPopupMenuItem(
            value: symbol,
            checked: symbol == controller.selectedBenchmark,
            child: Text(symbol),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: _addCustomValue,
          child: ListTile(
            leading: Icon(Icons.add),
            title: Text('Add Custom'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('vs ${controller.selectedBenchmark}',
                style: theme.textTheme.labelLarge),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
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
            onPressed: () =>
                Navigator.pop(context, textController.text.trim().toUpperCase()),
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
