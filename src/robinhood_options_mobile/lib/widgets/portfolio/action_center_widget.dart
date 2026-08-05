import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/model/portfolio_alert.dart';
import 'package:robinhood_options_mobile/widgets/analytics_style_card.dart';

/// "What should I do today?" — the ranked alert feed on the Portfolio overview.
///
/// Shows [collapsedCount] alerts and tucks the rest behind a "Show all" row, so
/// a noisy day never pushes the section grid off the screen.
class ActionCenterWidget extends StatefulWidget {
  final List<PortfolioAlert> alerts;
  final void Function(PortfolioAlert alert) onAlertTap;
  final int collapsedCount;

  const ActionCenterWidget({
    super.key,
    required this.alerts,
    required this.onAlertTap,
    this.collapsedCount = 3,
  });

  @override
  State<ActionCenterWidget> createState() => _ActionCenterWidgetState();
}

class _ActionCenterWidgetState extends State<ActionCenterWidget> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    if (widget.alerts.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final visible = _showAll
        ? widget.alerts
        : widget.alerts.take(widget.collapsedCount).toList();
    final hiddenCount = widget.alerts.length - visible.length;

    final actionable = widget.alerts
        .where((alert) => alert.severity != PortfolioAlertSeverity.positive)
        .length;

    return AnalyticsStyleCard(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Row(
              children: [
                Icon(Icons.bolt, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child:
                      Text('Action Center', style: theme.textTheme.titleLarge),
                ),
                if (actionable > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$actionable',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          for (final alert in visible) _buildAlertRow(context, alert),
          if (hiddenCount > 0 || _showAll)
            TextButton(
              onPressed: () => setState(() => _showAll = !_showAll),
              child:
                  Text(_showAll ? 'Show less' : 'Show all $hiddenCount more'),
            ),
        ],
      ),
    );
  }

  Widget _buildAlertRow(BuildContext context, PortfolioAlert alert) {
    final theme = Theme.of(context);
    final color = alert.severity.color(context);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(alert.icon, size: 20, color: color),
      ),
      title: Text(
        alert.title,
        style:
            theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(alert.detail, style: theme.textTheme.bodySmall),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (alert.metric != null)
            Text(
              alert.metric!,
              style: theme.textTheme.titleSmall
                  ?.copyWith(color: color, fontWeight: FontWeight.bold),
            ),
          if (alert.target != PortfolioAlertTarget.none)
            Icon(Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant),
        ],
      ),
      onTap: alert.target == PortfolioAlertTarget.none
          ? null
          : () => widget.onAlertTap(alert),
    );
  }
}
