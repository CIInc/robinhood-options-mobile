import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/model/schwab_order_preview.dart';

/// Renders pre-trade Schwab verification metrics, margin requirements,
/// estimated commissions/fees, and any rule warnings or rejections.
class SchwabOrderPreviewCard extends StatelessWidget {
  final SchwabOrderPreview preview;

  const SchwabOrderPreviewCard({
    super.key,
    required this.preview,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatCurrency = NumberFormat.simpleCurrency();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (preview.hasRejections) ...[
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              border: Border.all(color: Colors.red),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      "Schwab Order Validation Rejected",
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                for (final msg in preview.rejectMessages)
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Text(
                      "• $msg",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.red,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (preview.hasWarnings) ...[
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.12),
              border: Border.all(color: Colors.amber.shade700),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.amber.shade800, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      "Schwab Order Notices & Warnings",
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.amber.shade900,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                for (final msg in [
                  ...preview.warningMessages,
                  ...preview.alertMessages
                ])
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Text(
                      "• $msg",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.shield_outlined,
                      size: 18, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    "Schwab Pre-Trade Verification",
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildRow(
                theme,
                "Estimated Commission",
                preview.estimatedCommission > 0
                    ? formatCurrency.format(preview.estimatedCommission)
                    : "\$0.00 (Commission-free)",
              ),
              if (preview.estimatedFees > 0)
                _buildRow(
                  theme,
                  "Estimated Regulatory Fees",
                  formatCurrency.format(preview.estimatedFees),
                ),
              if (preview.marginRequirement != null)
                _buildRow(
                  theme,
                  "Margin / Cash Impact",
                  formatCurrency.format(preview.marginRequirement),
                ),
              if (preview.projectedBuyingPower != null)
                _buildRow(
                  theme,
                  "Projected Buying Power",
                  formatCurrency.format(preview.projectedBuyingPower),
                  isBold: true,
                ),
              if (preview.projectedAvailableFunds != null)
                _buildRow(
                  theme,
                  "Projected Available Funds",
                  formatCurrency.format(preview.projectedAvailableFunds),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRow(ThemeData theme, String label, String value,
      {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
