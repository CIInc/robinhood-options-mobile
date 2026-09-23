import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/widgets/volatility_cone_widget.dart';

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

  void setNarrowTestWindow(WidgetTester tester) {
    tester.view.physicalSize = const Size(360, 800);
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

  group('VolatilityConeWidget Widget Tests', () {
    testWidgets('Renders Volatility Cone Screen and tabs successfully',
        (WidgetTester tester) async {
      setLargeTestWindow(tester);

      await tester.pumpWidget(
        buildTestableWidget(
          const VolatilityConeWidget(
            symbol: 'NVDA',
            spotPrice: 125.0,
            overrideCurrentIv: 0.52,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check AppBar title and spot text
      expect(find.text('NVDA Volatility Cone'), findsOneWidget);
      expect(find.textContaining('Spot: \$125.00'), findsOneWidget);

      // Check Tab headers
      expect(find.text('Cone & Rank'), findsOneWidget);
      expect(find.text('Skew & Smile'), findsOneWidget);
      expect(find.text('Playbook'), findsOneWidget);

      // Check Hero & Multi-Timeframe metrics
      expect(find.text('Multi-Timeframe IV Metrics'), findsOneWidget);
      expect(find.text('Volatility Cone Distribution'), findsOneWidget);
      expect(find.text('Volatility Risk Premium (VRP)'), findsOneWidget);

      // Check IV metric labels
      expect(find.text('30D'), findsWidgets);
      expect(find.text('60D'), findsWidgets);
      expect(find.text('90D'), findsWidgets);
    });

    testWidgets('Switches tabs between Skew & Smile and Playbook',
        (WidgetTester tester) async {
      setLargeTestWindow(tester);

      await tester.pumpWidget(
        buildTestableWidget(
          const VolatilityConeWidget(
            symbol: 'AAPL',
            spotPrice: 230.0,
            overrideCurrentIv: 0.28,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on 'Skew & Smile' tab
      await tester.tap(find.text('Skew & Smile'));
      await tester.pumpAndSettle();

      // Check Skew & Term Structure content
      expect(find.text('Strike Skew & Smile Curve'), findsOneWidget);
      expect(find.text('Volatility Term Structure'), findsOneWidget);
      expect(find.textContaining('25Δ Risk Reversal:'), findsOneWidget);

      // Tap on 'Playbook' tab
      await tester.tap(find.text('Playbook'));
      await tester.pumpAndSettle();

      // Check Playbook content
      expect(
          find.textContaining('Strategies optimized for AAPL'), findsOneWidget);
      expect(find.textContaining('Rationale:'), findsWidgets);
    });

    testWidgets('Opens Educational Guide dialog when help icon is tapped',
        (WidgetTester tester) async {
      setLargeTestWindow(tester);

      await tester.pumpWidget(
        buildTestableWidget(
          const VolatilityConeWidget(
            symbol: 'MSFT',
            spotPrice: 430.0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Help icon in AppBar
      await tester.tap(find.byIcon(Icons.help_outline_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Volatility Cone Guide'), findsOneWidget);
      expect(find.text('What is a Volatility Cone?'), findsOneWidget);
      expect(find.text('IV Rank vs. IV Percentile'), findsOneWidget);

      // Tap Close button
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(find.text('Volatility Cone Guide'), findsNothing);
    });

    testWidgets('Renders properly without overflow on narrow viewport',
        (WidgetTester tester) async {
      setNarrowTestWindow(tester);

      await tester.pumpWidget(
        buildTestableWidget(
          const VolatilityConeWidget(
            symbol: 'TSLA',
            spotPrice: 245.0,
            overrideCurrentIv: 0.65,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('TSLA Volatility Cone'), findsOneWidget);
    });
  });
}
