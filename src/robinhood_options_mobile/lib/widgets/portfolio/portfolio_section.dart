import 'package:flutter/material.dart';

/// The six drill-down destinations reachable from the Portfolio overview.
///
/// Each one owns a coherent question ("why did it happen?", "how much risk am I
/// taking?") rather than mirroring the shape of the underlying data model.
enum PortfolioSection {
  positions,
  performance,
  risk,
  insights,
  taxes,
  strategies,
}

extension PortfolioSectionDisplay on PortfolioSection {
  String get label {
    switch (this) {
      case PortfolioSection.positions:
        return 'Positions';
      case PortfolioSection.performance:
        return 'Performance';
      case PortfolioSection.risk:
        return 'Risk';
      case PortfolioSection.insights:
        return 'Insights';
      case PortfolioSection.taxes:
        return 'Taxes';
      case PortfolioSection.strategies:
        return 'Strategies';
    }
  }

  String get description {
    switch (this) {
      case PortfolioSection.positions:
        return 'Allocation, sectors & heatmap';
      case PortfolioSection.performance:
        return 'Returns, benchmarks & monthly history';
      case PortfolioSection.risk:
        return 'Risk score, drawdown & correlation';
      case PortfolioSection.insights:
        return 'AI brief, coaching & market assistant';
      case PortfolioSection.taxes:
        return 'Loss harvesting & ESG scoring';
      case PortfolioSection.strategies:
        return 'Automation, options flow, GEX & paper trading';
    }
  }

  IconData get icon {
    switch (this) {
      case PortfolioSection.positions:
        return Icons.pie_chart_outline;
      case PortfolioSection.performance:
        return Icons.show_chart;
      case PortfolioSection.risk:
        return Icons.shield_outlined;
      case PortfolioSection.insights:
        return Icons.auto_awesome;
      case PortfolioSection.taxes:
        return Icons.savings_outlined;
      case PortfolioSection.strategies:
        return Icons.smart_toy_outlined;
    }
  }
}
