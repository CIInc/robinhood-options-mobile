import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/model/portfolio_alert.dart';
import 'package:robinhood_options_mobile/widgets/analytics_style_card.dart';

/// "What should I do today?" — the ranked alert feed on the Portfolio overview.
///
/// Features:
/// - Interactive category filter chips (All, High Priority, and dynamic categories)
/// - Contextual direct action buttons (e.g. "Analyze Radar →", "View TSLA →")
/// - Ticker badges and severity tags for quick scanning
/// - Quick dismissal with undo snackbar
/// - Collapses past [collapsedCount] alerts with an expand toggle
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
  String _selectedCategory = 'All';
  final Set<String> _dismissedAlertIds = <String>{};

  @override
  Widget build(BuildContext context) {
    // If no alerts at all, render nothing
    if (widget.alerts.isEmpty) return const SizedBox.shrink();

    // Filter out dismissed alerts
    final activeAlerts = widget.alerts
        .where((alert) => !_dismissedAlertIds.contains(alert.id))
        .toList();

    // If all alerts were dismissed, show clean state or shrink if no initial alerts
    if (activeAlerts.isEmpty && _dismissedAlertIds.isNotEmpty) {
      return _buildAllDismissedCard(context);
    }
    if (activeAlerts.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    // Extract unique categories present in the active alerts
    final categories = <String>{'All'};
    final hasHighPriority = activeAlerts.any(
      (a) =>
          a.severity == PortfolioAlertSeverity.critical ||
          a.severity == PortfolioAlertSeverity.warning,
    );
    if (hasHighPriority) {
      categories.add('High Priority');
    }
    for (final alert in activeAlerts) {
      if (alert.category != null && alert.category!.isNotEmpty) {
        categories.add(alert.category!);
      }
    }

    // Filter by selected category
    List<PortfolioAlert> filteredAlerts;
    if (_selectedCategory == 'All') {
      filteredAlerts = activeAlerts;
    } else if (_selectedCategory == 'High Priority') {
      filteredAlerts = activeAlerts
          .where((a) =>
              a.severity == PortfolioAlertSeverity.critical ||
              a.severity == PortfolioAlertSeverity.warning)
          .toList();
    } else {
      filteredAlerts = activeAlerts
          .where((a) => a.category == _selectedCategory)
          .toList();
    }

    final visible = _showAll
        ? filteredAlerts
        : filteredAlerts.take(widget.collapsedCount).toList();
    final hiddenCount = filteredAlerts.length - visible.length;

    final actionable = activeAlerts
        .where((alert) => alert.severity != PortfolioAlertSeverity.positive)
        .length;

    return AnalyticsStyleCard(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.bolt,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Action Center',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          )),
                      Text(
                        actionable > 0
                            ? '$actionable actionable item${actionable == 1 ? '' : 's'} require review'
                            : 'All systems nominal',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (actionable > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
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

          // Category filter chips row (shown when 2+ categories exist)
          if (categories.length > 2)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 6),
              child: SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final category in categories)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: Text(category),
                          selected: _selectedCategory == category,
                          onSelected: (selected) {
                            setState(() {
                              _selectedCategory = selected ? category : 'All';
                            });
                          },
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: _selectedCategory == category
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

          // Alert cards
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Text(
                  'No alerts in this category.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            for (final alert in visible) _buildAlertCard(context, alert),

          // Show all / Show less toggle
          if (hiddenCount > 0 || _showAll)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextButton(
                onPressed: () => setState(() => _showAll = !_showAll),
                child: Text(
                  _showAll ? 'Show less' : 'Show all $hiddenCount more',
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAllDismissedCard(BuildContext context) {
    final theme = Theme.of(context);
    return AnalyticsStyleCard(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, color: Colors.green.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Action Center', style: theme.textTheme.titleMedium),
                Text(
                  'All alerts dismissed. You are all caught up!',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _dismissedAlertIds.clear();
              });
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(BuildContext context, PortfolioAlert alert) {
    final theme = Theme.of(context);
    final color = alert.severity.color(context);
    final actionText = alert.actionLabel ??
        (alert.target != PortfolioAlertTarget.none ? 'View Details' : null);

    return InkWell(
      onTap: alert.target == PortfolioAlertTarget.none
          ? null
          : () => widget.onAlertTap(alert),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: theme.dividerColor.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Leading severity icon
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(alert.icon, size: 20, color: color),
            ),
            const SizedBox(width: 12),

            // Content body
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badges row: category & symbol pills
                  if (alert.symbol != null || alert.category != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (alert.symbol != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: theme.colorScheme.outline
                                      .withValues(alpha: 0.25),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                alert.symbol!,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          if (alert.category != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                alert.category!,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: color,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                  // Title
                  Text(
                    alert.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),

                  // Detail message
                  Text(
                    alert.detail,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),

                  // Bottom action / metric row
                  if (actionText != null || alert.metric != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Row(
                        children: [
                          if (alert.metric != null)
                            Text(
                              alert.metric!,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: color,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          if (alert.metric != null && actionText != null)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6.0),
                              child: Text(
                                '•',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          if (actionText != null)
                            Text(
                              '$actionText →',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Trailing dismiss button
            IconButton(
              icon: Icon(
                Icons.close,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              tooltip: 'Dismiss alert',
              onPressed: () {
                final alertId = alert.id;
                setState(() {
                  _dismissedAlertIds.add(alertId);
                });
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Dismissed: ${alert.title}'),
                    action: SnackBarAction(
                      label: 'Undo',
                      onPressed: () {
                        setState(() {
                          _dismissedAlertIds.remove(alertId);
                        });
                      },
                    ),
                    duration: const Duration(seconds: 4),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
