import 'package:flutter/material.dart';

/// Full quantitative configuration view for [AgenticTradingSettingsWidget].
///
/// Unlocks granular strategy templates, all 19 technical indicators, custom
/// indicator formulas, 5-tier GEX structural stop thresholds, sector/correlation
/// caps, notification controls, backtesting, and OEM background execution logs.
class QuantProSettingsView extends StatelessWidget {
  final Widget templateListSection;
  final Widget executionSettingsSection;
  final Widget riskManagementSection;
  final Widget entryStrategiesSection;
  final Widget exitStrategiesSection;
  final Widget notificationSettingsSection;
  final Widget backtestingSection;
  final VoidCallback onSwitchToSimplified;

  const QuantProSettingsView({
    super.key,
    required this.templateListSection,
    required this.executionSettingsSection,
    required this.riskManagementSection,
    required this.entryStrategiesSection,
    required this.exitStrategiesSection,
    required this.notificationSettingsSection,
    required this.backtestingSection,
    required this.onSwitchToSimplified,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const ValueKey('quant-pro-active-banner'),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.science_outlined,
                  size: 18, color: colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quant Pro Mode Active',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      '19 indicators, custom formulas, GEX stops & background logs unlocked',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                key: const ValueKey('switch-to-simplified-button'),
                onPressed: onSwitchToSimplified,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text('Simplified'),
              ),
            ],
          ),
        ),
        templateListSection,
        executionSettingsSection,
        riskManagementSection,
        entryStrategiesSection,
        exitStrategiesSection,
        notificationSettingsSection,
        backtestingSection,
      ],
    );
  }
}
