import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/portfolio_alert.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/action_center_widget.dart';

Widget wrap(Widget child) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    );

void main() {
  group('ActionCenterWidget Expanded Capabilities', () {
    testWidgets('renders category filter chips when multiple categories exist',
        (tester) async {
      final alerts = [
        const PortfolioAlert(
          id: 'squeeze_1',
          severity: PortfolioAlertSeverity.critical,
          icon: Icons.bolt,
          title: 'TSLA 0DTE Squeeze Imminent',
          detail: 'High gamma squeeze probability',
          symbol: 'TSLA',
          category: '0DTE Squeeze',
          actionLabel: 'Analyze Radar',
          target: PortfolioAlertTarget.zeroDteRadar,
        ),
        const PortfolioAlert(
          id: 'earnings_1',
          severity: PortfolioAlertSeverity.warning,
          icon: Icons.compress,
          title: 'NVDA Extreme IV Crush Risk',
          detail: 'Options pricing implies ±8.5% move',
          symbol: 'NVDA',
          category: 'Earnings',
          actionLabel: 'IV Crush Analysis',
          target: PortfolioAlertTarget.earningsIvCrush,
        ),
        const PortfolioAlert(
          id: 'div_1',
          severity: PortfolioAlertSeverity.positive,
          icon: Icons.payments,
          title: 'AAPL Dividend Payable Today',
          detail: 'Payout scheduled',
          symbol: 'AAPL',
          category: 'Dividends',
          actionLabel: 'View Dividends',
          target: PortfolioAlertTarget.performance,
        ),
      ];

      await tester.pumpWidget(wrap(
        ActionCenterWidget(
          alerts: alerts,
          onAlertTap: (_) {},
        ),
      ));

      // Chips should be visible as FilterChips
      expect(find.widgetWithText(FilterChip, 'All'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'High Priority'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, '0DTE Squeeze'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Earnings'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Dividends'), findsOneWidget);

      // Initially all 3 alerts are present
      expect(find.text('TSLA 0DTE Squeeze Imminent'), findsOneWidget);
      expect(find.text('NVDA Extreme IV Crush Risk'), findsOneWidget);
      expect(find.text('AAPL Dividend Payable Today'), findsOneWidget);

      // Tap '0DTE Squeeze' filter chip
      await tester.tap(find.widgetWithText(FilterChip, '0DTE Squeeze'));
      await tester.pumpAndSettle();

      // Only TSLA should now be visible
      expect(find.text('TSLA 0DTE Squeeze Imminent'), findsOneWidget);
      expect(find.text('NVDA Extreme IV Crush Risk'), findsNothing);
      expect(find.text('AAPL Dividend Payable Today'), findsNothing);

      // Tap 'High Priority' chip
      await tester.tap(find.widgetWithText(FilterChip, 'High Priority'));
      await tester.pumpAndSettle();

      // TSLA (critical) & NVDA (warning) are high priority, AAPL (positive) is not
      expect(find.text('TSLA 0DTE Squeeze Imminent'), findsOneWidget);
      expect(find.text('NVDA Extreme IV Crush Risk'), findsOneWidget);
      expect(find.text('AAPL Dividend Payable Today'), findsNothing);
    });

    testWidgets('renders ticker badges and contextual action buttons',
        (tester) async {
      PortfolioAlert? tapped;
      final alerts = [
        const PortfolioAlert(
          id: 'vol_1',
          severity: PortfolioAlertSeverity.warning,
          icon: Icons.warning_amber,
          title: 'SPY Volatility Surge',
          detail: 'IV Rank at 92%',
          metric: '92% IVR',
          symbol: 'SPY',
          category: 'Volatility',
          actionLabel: 'Volatility Cone',
          target: PortfolioAlertTarget.volatilityCone,
        ),
      ];

      await tester.pumpWidget(wrap(
        ActionCenterWidget(
          alerts: alerts,
          onAlertTap: (a) => tapped = a,
        ),
      ));

      // Ticker chip and category pill
      expect(find.text('SPY'), findsOneWidget);
      expect(find.text('Volatility'), findsWidgets);

      // Action label and metric
      expect(find.text('92% IVR'), findsOneWidget);
      expect(find.text('Volatility Cone →'), findsOneWidget);

      // Tap on action text
      await tester.tap(find.text('Volatility Cone →'));
      await tester.pump();

      expect(tapped?.id, 'vol_1');
      expect(tapped?.target, PortfolioAlertTarget.volatilityCone);
    });

    testWidgets('dismisses alert and supports undo restoration',
        (tester) async {
      final alerts = [
        const PortfolioAlert(
          id: 'pdt_1',
          severity: PortfolioAlertSeverity.warning,
          icon: Icons.shield,
          title: '1 Day Trade Remaining',
          detail: 'Avoid PDT margin restriction',
          actionLabel: 'Day Trade Monitor',
          target: PortfolioAlertTarget.pdtMonitor,
        ),
      ];

      await tester.pumpWidget(wrap(
        ActionCenterWidget(
          alerts: alerts,
          onAlertTap: (_) {},
        ),
      ));

      expect(find.text('1 Day Trade Remaining'), findsOneWidget);

      // Tap dismiss icon
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Alert should be dismissed and all-dismissed state displayed
      expect(find.text('1 Day Trade Remaining'), findsNothing);
      expect(find.text('All alerts dismissed. You are all caught up!'),
          findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);

      // Tap Undo on SnackBar
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      // Alert restored
      expect(find.text('1 Day Trade Remaining'), findsOneWidget);
    });

    testWidgets('reset button restores all dismissed alerts', (tester) async {
      final alerts = [
        const PortfolioAlert(
          id: 'cash_1',
          severity: PortfolioAlertSeverity.info,
          icon: Icons.savings,
          title: 'Idle Cash Available',
          detail: 'Earn yield with automated DRIP',
          target: PortfolioAlertTarget.dripSettings,
        ),
      ];

      await tester.pumpWidget(wrap(
        ActionCenterWidget(
          alerts: alerts,
          onAlertTap: (_) {},
        ),
      ));

      // Dismiss alert
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('Reset'), findsOneWidget);

      // Tap Reset button on the card
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();

      // Alert restored
      expect(find.text('Idle Cash Available'), findsOneWidget);
    });
  });
}
