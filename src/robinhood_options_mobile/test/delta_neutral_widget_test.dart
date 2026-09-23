import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/widgets/delta_neutral_builder_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void setLargeTestWindow(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: child,
    );
  }

  group('DeltaNeutralBuilderWidget Widget Tests', () {
    testWidgets('Renders Delta-Neutral Strategy Builder and hero overview',
        (WidgetTester tester) async {
      setLargeTestWindow(tester);

      await tester.pumpWidget(
        buildTestableWidget(
          const DeltaNeutralBuilderWidget(
            symbol: 'NVDA',
            spotPrice: 120.0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check AppBar title and spot text
      expect(find.text('NVDA Delta Neutral'), findsOneWidget);
      expect(find.textContaining('Spot: \$120.00'), findsOneWidget);

      // Check Tabs
      expect(find.text('Legs & Builder'), findsOneWidget);
      expect(find.text('Rebalance & Offsets'), findsOneWidget);
      expect(find.text('Scenario Curve'), findsOneWidget);
      expect(find.text('Templates'), findsOneWidget);

      // Check Hero Overview
      expect(find.text('Net Position Delta'), findsOneWidget);
      expect(find.text('1% Move Risk'), findsOneWidget);
      expect(find.text('Delta (Δ)'), findsOneWidget);
      expect(find.text('Gamma (Γ)'), findsOneWidget);
      expect(find.text('Theta (Θ)'), findsOneWidget);
      expect(find.text('Vega (V)'), findsOneWidget);

      // Check default legs loaded from straddle template
      expect(find.textContaining('Active Legs'), findsOneWidget);
      expect(find.text('Add Leg'), findsOneWidget);
    });

    testWidgets('Switches to Rebalance & Offsets tab and verifies components',
        (WidgetTester tester) async {
      setLargeTestWindow(tester);

      await tester.pumpWidget(
        buildTestableWidget(
          const DeltaNeutralBuilderWidget(
            symbol: 'AAPL',
            spotPrice: 220.0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on Rebalance & Offsets tab
      await tester.tap(find.text('Rebalance & Offsets'));
      await tester.pumpAndSettle();

      // Check Tolerance Band Slider
      expect(find.text('Neutrality Tolerance Band'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);

      // Check Automated Rebalancing Suggestions
      expect(find.text('Automated Rebalancing Suggestions'), findsOneWidget);
      expect(find.textContaining('Rebalancing frequency depends on volatility'),
          findsOneWidget);
    });

    testWidgets('Switches to Scenario Curve tab and renders chart and matrix',
        (WidgetTester tester) async {
      setLargeTestWindow(tester);

      await tester.pumpWidget(
        buildTestableWidget(
          const DeltaNeutralBuilderWidget(
            symbol: 'SPY',
            spotPrice: 550.0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on Scenario Curve tab
      await tester.tap(find.text('Scenario Curve'));
      await tester.pumpAndSettle();

      expect(find.text('Spot Price Shift Curve'), findsOneWidget);
      expect(find.text('Scenario Breakdown Matrix'), findsOneWidget);
      expect(find.text('Spot Move'), findsOneWidget);
      expect(find.text('Underlying'), findsOneWidget);
      expect(find.text('Net Delta'), findsWidgets);
      expect(find.text('Est. P&L'), findsOneWidget);

      // Toggle to P&L curve
      await tester.tap(find.text('P&L (\$)'));
      await tester.pumpAndSettle();

      expect(find.text('Simulated P&L across spot moves'), findsOneWidget);
    });

    testWidgets('Switches to Templates tab and applies Covered Collar preset',
        (WidgetTester tester) async {
      setLargeTestWindow(tester);

      await tester.pumpWidget(
        buildTestableWidget(
          const DeltaNeutralBuilderWidget(
            symbol: 'TSLA',
            spotPrice: 200.0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on Templates tab
      await tester.tap(find.text('Templates'));
      await tester.pumpAndSettle();

      expect(find.text('Delta-Neutral Strategy Presets'), findsOneWidget);
      expect(find.text('ATM Long Straddle'), findsOneWidget);
      expect(find.text('Delta-Neutral Covered Collar'), findsOneWidget);
      expect(find.text('Delta-Neutral Call Ratio Backspread'), findsOneWidget);

      // Tap Covered Collar template
      await tester.tap(find.text('Delta-Neutral Covered Collar'));
      await tester.pumpAndSettle();

      // Should switch back to Legs & Builder tab and display SnackBar
      expect(find.text('Loaded Delta-Neutral Covered Collar template.'),
          findsOneWidget);
      expect(find.textContaining('Active Legs (3)'), findsOneWidget);
    });

    testWidgets(
        'Renders Scenario Curve tab on narrow mobile viewport (370px) without overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(370, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestableWidget(
          const DeltaNeutralBuilderWidget(
            symbol: 'QQQ',
            spotPrice: 480.0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure Scenario Curve tab is scrolled into view in TabBar and tap
      await tester.ensureVisible(find.text('Scenario Curve'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scenario Curve'));
      await tester.pumpAndSettle();

      // Should render without throwing RenderFlex overflow
      expect(find.text('Spot Price Shift Curve'), findsOneWidget);
      expect(find.text('P&L (\$)'), findsOneWidget);
      expect(find.text('Delta (Δ)'), findsWidgets);
    });

    testWidgets(
        'Scenario Curve interactive touch scrubbing and inspection card',
        (WidgetTester tester) async {
      setLargeTestWindow(tester);

      await tester.pumpWidget(
        buildTestableWidget(
          const DeltaNeutralBuilderWidget(
            symbol: 'NVDA',
            spotPrice: 120.0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on Scenario Curve tab
      await tester.tap(find.text('Scenario Curve'));
      await tester.pumpAndSettle();

      // Tap on the chart GestureDetector to trigger inspection
      final chartFinder = find.byKey(const ValueKey('scenario_chart_gesture'));
      expect(chartFinder, findsOneWidget);
      await tester.tap(chartFinder);
      await tester.pumpAndSettle();

      // Live inspection banner should appear with spot price info
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.textContaining('Spot: \$'), findsWidgets);

      // Tap close button on the banner
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Banner should be dismissed
      expect(find.byIcon(Icons.close), findsNothing);

      // Tap a row in the Scenario Breakdown Matrix
      await tester.tap(find.text('\$120.0'));
      await tester.pumpAndSettle();

      // Inspection banner should reappear
      expect(find.byIcon(Icons.close), findsOneWidget);
    });
  });
}
