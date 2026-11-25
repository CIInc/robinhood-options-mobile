import 'package:flutter/material.dart';

/// Capital Budget Card
///
/// Surfaces the portfolio equity budget allocation slider, balance-masked dollar estimate,
/// and quick preset chips (10%, 25%, 50%, 75%, 100%) for automated trading.
/// Shared across Simplified and Quant Pro modes.
class CapitalBudgetCard extends StatelessWidget {
  final double allocationPercent;
  final String? formattedDollarCap;
  final ValueChanged<double> onAllocationChanged;
  final String title;
  final String subtitle;
  final Key? cardKey;
  final Key? sliderKey;
  final Key? chipsScrollKey;

  const CapitalBudgetCard({
    super.key,
    required this.allocationPercent,
    this.formattedDollarCap,
    required this.onAllocationChanged,
    this.title = 'Capital Budget',
    this.subtitle = 'Max portfolio equity allocated to automated trading',
    this.cardKey,
    this.sliderKey,
    this.chipsScrollKey,
  });

  static String formatPercent(double value) {
    return value % 1 == 0
        ? '${value.toInt()}%'
        : '${value.toStringAsFixed(1)}%';
  }

  static void showCapitalBudgetDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.pie_chart_outline, size: 24),
            SizedBox(width: 10),
            Expanded(child: Text('Capital Budget Allocation')),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'What is Capital Budget?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 6),
              Text(
                'Capital Budget sets the hard upper ceiling on how much of your total portfolio equity automated trading can deploy across all open positions combined.',
              ),
              SizedBox(height: 12),
              Text(
                'Real-Time Dollar Estimate',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 6),
              Text(
                'The dollar amount displayed next to the percentage is an estimate based on your current total portfolio balance. For example, a 25% allocation on a \$10,000 portfolio allows up to \$2,500 total exposure.',
              ),
              SizedBox(height: 12),
              Text(
                'Cash Preservation & Safeguards',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 6),
              Text(
                '• The unallocated portion of your portfolio remains strictly untouched for your own manual trades or long-term holdings.\n'
                '• Auto-trading will decline new entries once open position market values reach this threshold until existing trades are closed.\n'
                '• You can adjust this slider at any time; changes take effect on the next evaluation cycle.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final clampedPercent = allocationPercent.clamp(5.0, 100.0);

    return Card(
      key: cardKey,
      elevation: 0,
      margin: EdgeInsets.zero,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outline.withValues(alpha: 0.15),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              label:
                  'Capital Budget: ${formatPercent(clampedPercent)} of portfolio equity'
                  '${formattedDollarCap != null ? ", approximately $formattedDollarCap" : ""}',
              child: Row(
                children: [
                  Icon(Icons.pie_chart_outline,
                      size: 20, color: colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                title,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Tooltip(
                              message: 'About Capital Budget allocation',
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => showCapitalBudgetDialog(context),
                                child: Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      formattedDollarCap != null
                          ? '${formatPercent(clampedPercent)} • $formattedDollarCap'
                          : formatPercent(clampedPercent),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Slider(
              key: sliderKey ?? const ValueKey('capital-allocation-slider'),
              value: clampedPercent,
              min: 5,
              max: 100,
              divisions: 19,
              label: formatPercent(clampedPercent),
              onChanged: (value) => onAllocationChanged(value / 100.0),
            ),
            SingleChildScrollView(
              key: chipsScrollKey ??
                  const ValueKey('capital-allocation-chips-scroll'),
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final preset in const [10, 25, 50, 75, 100])
                    Padding(
                      padding: EdgeInsets.only(right: preset == 100 ? 0 : 8),
                      child: ChoiceChip(
                        label: Text('$preset%'),
                        selected: (clampedPercent - preset).abs() < 0.5,
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) => onAllocationChanged(preset / 100.0),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
