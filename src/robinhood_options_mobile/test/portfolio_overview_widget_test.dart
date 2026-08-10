import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/portfolio_alert.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/action_center_widget.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/metric_disclosure_card.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/portfolio_risk_summary_widget.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/portfolio_section.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/analytics/risk_analytics_card.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/portfolio_section_grid_widget.dart';

import 'portfolio_alert_service_test.dart' show buildPosition;

Widget wrap(Widget child) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    );

PortfolioAlert alert(String id, PortfolioAlertSeverity severity) =>
    PortfolioAlert(
      id: id,
      severity: severity,
      icon: Icons.warning_amber,
      title: 'Alert $id',
      detail: 'Detail for $id',
      metric: '\$1,357',
      target: PortfolioAlertTarget.taxes,
    );

void main() {
  group('ActionCenterWidget', () {
    testWidgets('renders nothing when there is nothing to act on',
        (tester) async {
      await tester.pumpWidget(wrap(
        ActionCenterWidget(alerts: const [], onAlertTap: (_) {}),
      ));

      expect(find.text('Action Center'), findsNothing);
    });

    testWidgets('collapses past the third alert and expands on demand',
        (tester) async {
      await tester.pumpWidget(wrap(
        ActionCenterWidget(
          alerts: [
            alert('a', PortfolioAlertSeverity.critical),
            alert('b', PortfolioAlertSeverity.warning),
            alert('c', PortfolioAlertSeverity.warning),
            alert('d', PortfolioAlertSeverity.info),
            alert('e', PortfolioAlertSeverity.info),
          ],
          onAlertTap: (_) {},
        ),
      ));

      expect(find.text('Alert a'), findsOneWidget);
      expect(find.text('Alert d'), findsNothing);

      await tester.tap(find.text('Show all 2 more'));
      await tester.pumpAndSettle();

      expect(find.text('Alert d'), findsOneWidget);
      expect(find.text('Alert e'), findsOneWidget);
    });

    testWidgets('counts only actionable alerts in the badge', (tester) async {
      await tester.pumpWidget(wrap(
        ActionCenterWidget(
          alerts: [
            alert('a', PortfolioAlertSeverity.critical),
            alert('b', PortfolioAlertSeverity.positive),
          ],
          onAlertTap: (_) {},
        ),
      ));

      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('routes a tapped alert to its target', (tester) async {
      PortfolioAlert? tapped;
      await tester.pumpWidget(wrap(
        ActionCenterWidget(
          alerts: [alert('a', PortfolioAlertSeverity.critical)],
          onAlertTap: (value) => tapped = value,
        ),
      ));

      await tester.tap(find.text('Alert a'));
      await tester.pump();

      expect(tapped?.target, PortfolioAlertTarget.taxes);
    });
  });

  group('MetricDisclosureCard', () {
    testWidgets('hides the advanced tier until it is asked for',
        (tester) async {
      await tester.pumpWidget(wrap(
        const MetricDisclosureCard(
          icon: Icons.shield_outlined,
          title: 'Risk',
          headline: '64',
          status: 'Moderate Risk',
          tiles: [DisclosureTile(label: 'Volatility', value: '14.2%')],
          advanced: Text('Sharpe 1.2'),
        ),
      ));

      expect(find.text('64'), findsOneWidget);
      expect(find.text('Moderate Risk'), findsOneWidget);
      expect(find.text('Sharpe 1.2'), findsNothing);

      await tester.tap(find.text('Advanced Metrics'));
      await tester.pumpAndSettle();

      expect(find.text('Sharpe 1.2'), findsOneWidget);
    });

    testWidgets('starts expanded for advanced users', (tester) async {
      await tester.pumpWidget(wrap(
        const MetricDisclosureCard(
          icon: Icons.shield_outlined,
          title: 'Risk',
          headline: '64',
          initiallyExpanded: true,
          advanced: Text('Sharpe 1.2'),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Sharpe 1.2'), findsOneWidget);
    });

    testWidgets('omits the disclosure row when there is no advanced tier',
        (tester) async {
      await tester.pumpWidget(wrap(
        const MetricDisclosureCard(
          icon: Icons.shield_outlined,
          title: 'Risk',
          headline: '64',
        ),
      ));

      expect(find.text('Advanced Metrics'), findsNothing);
    });
  });

  group('PortfolioRiskSummaryWidget', () {
    testWidgets('leads with a qualitative score, not the raw metrics',
        (tester) async {
      await tester.pumpWidget(wrap(
        PortfolioRiskSummaryWidget(
          positions: [
            buildPosition(symbol: 'NVDA', price: 100, quantity: 40),
            buildPosition(symbol: 'AAPL', price: 100, quantity: 10),
          ],
        ),
      ));

      expect(find.text('High Risk'), findsOneWidget);
      // HHI is detail, so it stays behind the disclosure.
      expect(find.textContaining('Herfindahl'), findsNothing);

      await tester.tap(find.text('Concentration Detail'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Herfindahl'), findsOneWidget);
      expect(find.text('Top 1 Holding'), findsOneWidget);
    });

    testWidgets('reads as diversified for an even book', (tester) async {
      await tester.pumpWidget(wrap(
        PortfolioRiskSummaryWidget(
          positions: [
            for (final symbol in ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'])
              buildPosition(symbol: symbol, price: 100, quantity: 10),
          ],
        ),
      ));

      expect(find.text('Well Diversified'), findsOneWidget);
    });

    testWidgets('renders nothing without holdings', (tester) async {
      await tester
          .pumpWidget(wrap(const PortfolioRiskSummaryWidget(positions: [])));

      expect(find.text('Concentration'), findsNothing);
    });
  });

  group('PortfolioSectionGridWidget', () {
    testWidgets('shows every section and reports taps', (tester) async {
      PortfolioSection? tapped;
      await tester.pumpWidget(wrap(
        PortfolioSectionGridWidget(
          onSectionTap: (section) => tapped = section,
          summaries: const {PortfolioSection.risk: 'Moderate'},
          flagged: const {PortfolioSection.taxes},
        ),
      ));

      for (final section in PortfolioSection.values) {
        expect(find.text(section.label), findsOneWidget);
      }
      final cardHeights = PortfolioSection.values.map((section) {
        final card = find.ancestor(
          of: find.text(section.label),
          matching: find.byType(Card),
        );
        return tester.getSize(card).height;
      }).toSet();
      expect(cardHeights, hasLength(1));
      final titleBottom = tester.getBottomLeft(find.text('Browse')).dy;
      final firstCardTop = tester
          .getTopLeft(find.ancestor(
            of: find.text(PortfolioSection.positions.label),
            matching: find.byType(Card),
          ))
          .dy;
      expect(firstCardTop - titleBottom, 12);
      // A summary replaces the static description on its tile.
      expect(find.text('Moderate'), findsOneWidget);

      await tester.tap(find.text('Performance'));
      await tester.pump();

      expect(tapped, PortfolioSection.performance);
    });
  });

  group('RiskAnalyticsCard', () {
    const metrics = {
      'volatility': 0.22,
      'maxDrawdown': 0.28,
      'beta': 1.45,
      'sharpe': 1.2,
      'sortino': 1.6,
      'treynor': 0.09,
      'calmar': 0.8,
      'omega': 1.4,
      'correlation': 0.82,
      'alpha': 0.03,
      'trackingError': 0.06,
      'kellyCriterion': 0.08,
      'ulcerIndex': 0.07,
      'tailRatio': 1.2,
      'var95': -0.018,
      'cvar95': -0.027,
      'currentDrawdown': -0.04,
    };

    testWidgets('shows one score and keeps the metrics collapsed',
        (tester) async {
      await tester.pumpWidget(wrap(const RiskAnalyticsCard(data: metrics)));

      expect(find.text('Risk Score'), findsOneWidget);
      expect(find.text('Moderate Risk'), findsOneWidget);
      // The eighteen quantitative metrics stay behind the disclosure.
      expect(find.text('Sharpe'), findsNothing);
      expect(find.text('Kelly Criterion'), findsNothing);
    });

    testWidgets('reveals all four metric groups when expanded', (tester) async {
      await tester.pumpWidget(wrap(const RiskAnalyticsCard(data: metrics)));

      await tester.tap(find.text('Advanced Metrics'));
      await tester.pumpAndSettle();

      for (final group in [
        'Risk Metrics',
        'Risk-Adjusted Return',
        'Market Comparison',
        'Advanced Edge',
      ]) {
        expect(find.text(group), findsOneWidget, reason: group);
      }
      for (final metric in [
        'Sharpe',
        'Sortino',
        'Treynor',
        'Calmar',
        'Omega',
        'Correlation',
        'Alpha',
        'Tracking Error',
        'Kelly Criterion',
        'Ulcer Index',
        'Tail Ratio',
        'Current Drawdown',
        'VaR (95%)',
        'CVaR (95%)',
      ]) {
        expect(find.text(metric), findsOneWidget, reason: metric);
      }
      // These three are both summary tiles and full stat tiles: the tile row
      // is the headline, the grid is the complete tap-for-definition set.
      for (final metric in ['Volatility', 'Max Drawdown', 'Beta']) {
        expect(find.text(metric), findsNWidgets(2), reason: metric);
      }
    });

    testWidgets('scores a calm portfolio as low risk', (tester) async {
      await tester.pumpWidget(wrap(const RiskAnalyticsCard(
        data: {'volatility': 0.05, 'maxDrawdown': 0.03, 'beta': 1.0},
      )));

      expect(find.text('Low Risk'), findsOneWidget);
    });

    testWidgets('scores a wild portfolio as high risk', (tester) async {
      await tester.pumpWidget(wrap(const RiskAnalyticsCard(
        data: {'volatility': 0.45, 'maxDrawdown': 0.55, 'beta': 2.4},
      )));

      expect(find.text('High Risk'), findsOneWidget);
      expect(find.text('100'), findsOneWidget);
    });

    testWidgets('renders nothing without metrics', (tester) async {
      await tester.pumpWidget(wrap(const RiskAnalyticsCard(data: {})));

      expect(find.text('Risk Score'), findsNothing);
    });
  });
}
