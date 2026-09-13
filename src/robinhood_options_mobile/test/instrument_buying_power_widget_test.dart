import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/instrument_buying_power.dart';
import 'package:robinhood_options_mobile/widgets/instrument_buying_power_widget.dart';

void main() {
  group('InstrumentTradeWarningsBanner Widget Tests', () {
    testWidgets('does not render when warnings are empty',
        (WidgetTester tester) async {
      const warnings = InstrumentTradeWarnings(
        instrumentId: 'inst_clean',
        warnings: [],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: InstrumentTradeWarningsBanner(warnings: warnings),
          ),
        ),
      );

      expect(find.byType(InstrumentTradeWarningsBanner), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
      expect(find.byIcon(Icons.error_outline_rounded), findsNothing);
    });

    testWidgets('renders warning banner with title, message, and tap callback',
        (WidgetTester tester) async {
      bool tapped = false;
      const warning = InstrumentTradeWarning(
        id: 'w1',
        type: 'volatility',
        title: 'High Volatility Warning',
        message: 'Extreme swings detected in this symbol.',
        severity: InstrumentWarningSeverity.warning,
      );

      const warnings = InstrumentTradeWarnings(
        instrumentId: 'inst_vol',
        warnings: [warning],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InstrumentTradeWarningsBanner(
              warnings: warnings,
              onTapDetails: () {
                tapped = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('High Volatility Warning'), findsOneWidget);
      expect(find.text('Extreme swings detected in this symbol.'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);

      await tester.tap(find.byType(InstrumentTradeWarningsBanner));
      expect(tapped, isTrue);
    });

    testWidgets('renders critical error banner when halted or critical warning',
        (WidgetTester tester) async {
      const warning = InstrumentTradeWarning(
        id: 'w_crit',
        type: 'halt',
        title: 'Trading Halted',
        message: 'Trading halted by regulatory authority.',
        severity: InstrumentWarningSeverity.critical,
      );

      const warnings = InstrumentTradeWarnings(
        instrumentId: 'inst_halt',
        warnings: [warning],
        isHalted: true,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: InstrumentTradeWarningsBanner(warnings: warnings),
          ),
        ),
      );

      expect(find.text('Trading Halted'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    });
  });

  group('InstrumentBuyingPowerSummaryTile Widget Tests', () {
    testWidgets('renders buying power, margin status chip, and currency format',
        (WidgetTester tester) async {
      bool tapped = false;
      const bp = InstrumentBuyingPower(
        instrumentId: 'inst_tile',
        buyingPower: 25000.50,
        shortBuyingPower: 12500.00,
        marginRate: 0.50,
        maintenanceMarginRate: 0.30,
        isMarginable: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InstrumentBuyingPowerSummaryTile(
              buyingPower: bp,
              onTap: () {
                tapped = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Instrument Buying Power'), findsOneWidget);
      expect(find.text('50% Initial Margin'), findsOneWidget);
      expect(find.text('\$25,000.50'), findsOneWidget);

      await tester.tap(find.byType(InstrumentBuyingPowerSummaryTile));
      expect(tapped, isTrue);
    });

    testWidgets('renders short buying power when showShort is true',
        (WidgetTester tester) async {
      const bp = InstrumentBuyingPower(
        instrumentId: 'inst_short',
        buyingPower: 20000.0,
        shortBuyingPower: 8000.0,
        marginRate: 0.50,
        isMarginable: true,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: InstrumentBuyingPowerSummaryTile(
              buyingPower: bp,
              showShort: true,
            ),
          ),
        ),
      );

      expect(find.text('Short Buying Power'), findsOneWidget);
      expect(find.text('\$8,000.00'), findsOneWidget);
    });

    testWidgets('displays 100% Cash Required when cashOnly is true',
        (WidgetTester tester) async {
      const bp = InstrumentBuyingPower(
        instrumentId: 'inst_cash_only',
        buyingPower: 5000.0,
        cashOnly: true,
        marginRate: 1.0,
        isMarginable: false,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: InstrumentBuyingPowerSummaryTile(buyingPower: bp),
          ),
        ),
      );

      expect(find.text('100% Cash Required'), findsOneWidget);
      expect(find.text('\$5,000.00'), findsOneWidget);
    });
  });

  group('InstrumentBuyingPowerSheet Modal Tests', () {
    testWidgets('renders full breakdown of purchasing capacity, margin terms and disclosures',
        (WidgetTester tester) async {
      const bp = InstrumentBuyingPower(
        instrumentId: 'inst_sheet',
        buyingPower: 41505.26,
        shortBuyingPower: 20752.63,
        marginRate: 0.50,
        maintenanceMarginRate: 0.30,
        maxShares: 350.0,
        maxShortShares: 175.0,
        leverageRatio: 2.0,
        isMarginable: true,
      );

      const warnings = InstrumentTradeWarnings(
        instrumentId: 'inst_sheet',
        warnings: [
          InstrumentTradeWarning(
            id: 'w_warn',
            type: 'volatility',
            title: 'High Volatility Warning',
            message: 'Caution: elevated volatility.',
            severity: InstrumentWarningSeverity.warning,
          )
        ],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: InstrumentBuyingPowerSheet(
              symbol: 'NVDA',
              name: 'NVIDIA Corporation',
              buyingPower: bp,
              warnings: warnings,
            ),
          ),
        ),
      );

      expect(find.text('NVDA Buying Power & Risk'), findsOneWidget);
      expect(find.text('NVIDIA Corporation'), findsOneWidget);
      expect(find.text('Purchasing Capacity'), findsOneWidget);
      expect(find.text('Margin & Collateral Terms'), findsOneWidget);
      expect(find.text('Max Purchasable Shares'), findsOneWidget);
      expect(find.text('350.0'), findsOneWidget);
      expect(find.text('Short Buying Power'), findsOneWidget);
      expect(find.text('Max Short Shares'), findsOneWidget);
      expect(find.text('175.0'), findsOneWidget);
      expect(find.text('Initial Margin Requirement'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('Maintenance Margin Requirement'), findsOneWidget);
      expect(find.text('30%'), findsOneWidget);
      expect(find.text('Effective Leverage'), findsOneWidget);
      expect(find.text('2.00x'), findsOneWidget);
      expect(find.text('High Volatility Warning'), findsOneWidget);
      expect(find.text('Caution: elevated volatility.'), findsOneWidget);
    });
  });
}
