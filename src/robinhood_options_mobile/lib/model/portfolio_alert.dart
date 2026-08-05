import 'package:flutter/material.dart';

/// Where an alert sends the user when tapped.
enum PortfolioAlertTarget {
  positions,
  performance,
  risk,
  insights,
  taxes,
  strategies,
  rebalance,
  none,
}

/// Ranked highest to lowest so alerts can be sorted by `index`.
enum PortfolioAlertSeverity { critical, warning, info, positive }

extension PortfolioAlertSeverityDisplay on PortfolioAlertSeverity {
  Color color(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    switch (this) {
      case PortfolioAlertSeverity.critical:
        return scheme.error;
      case PortfolioAlertSeverity.warning:
        return Colors.orange;
      case PortfolioAlertSeverity.info:
        return scheme.primary;
      case PortfolioAlertSeverity.positive:
        return Colors.green;
    }
  }
}

/// A single "what should I do today?" item rendered by the Action Center.
///
/// Alerts are produced by [PortfolioAlertService] from the position stores and,
/// when available, the computed analytics metrics. Keeping them as data rather
/// than widgets lets the Overview rank, cap, and summarize them.
class PortfolioAlert {
  /// Stable identifier, used for dedupe and dismissal.
  final String id;
  final PortfolioAlertSeverity severity;
  final IconData icon;
  final String title;
  final String detail;

  /// Optional headline figure shown on the trailing edge, already formatted.
  final String? metric;
  final PortfolioAlertTarget target;

  const PortfolioAlert({
    required this.id,
    required this.severity,
    required this.icon,
    required this.title,
    required this.detail,
    this.metric,
    this.target = PortfolioAlertTarget.none,
  });
}
