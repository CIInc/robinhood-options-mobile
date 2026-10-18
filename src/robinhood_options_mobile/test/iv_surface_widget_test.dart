import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/widgets/iv_surface_3d_widget.dart';

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

  group('IvSurface3dWidget Widget Tests', () {
    testWidgets('Renders 3D Surface screen, tabs, and canvas correctly',
        (WidgetTester tester) async {
      setLargeTestWindow(tester);

      await tester.pumpWidget(
        buildTestableWidget(
          const IvSurface3dWidget(
            symbol: 'NVDA',
            spotPrice: 130.0,
            overrideCurrentIv: 0.48,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check AppBar and spot
      expect(find.text('NVDA 3D Volatility Surface'), findsOneWidget);
      expect(find.textContaining('Spot: \$130.00'), findsOneWidget);

      // Check Tabs
      expect(find.text('3D Surface'), findsOneWidget);
      expect(find.text('2D Slices'), findsOneWidget);
      expect(find.text('Diagnostics'), findsOneWidget);

      // Check metrics chip
      expect(find.textContaining('ATM IV:'), findsOneWidget);
      expect(find.textContaining('25Δ Skew:'), findsOneWidget);

      // Check 3D Surface controls
      expect(find.textContaining('Min'), findsOneWidget);
      expect(find.textContaining('Max'), findsOneWidget);
      expect(find.text('Center'), findsOneWidget);
    });

    testWidgets('Switches tabs between 2D Slices and Diagnostics',
        (WidgetTester tester) async {
      setLargeTestWindow(tester);

      await tester.pumpWidget(
        buildTestableWidget(
          const IvSurface3dWidget(
            symbol: 'AAPL',
            spotPrice: 225.0,
            overrideCurrentIv: 0.28,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to 2D Slices tab
      await tester.tap(find.text('2D Slices'));
      await tester.pumpAndSettle();

      expect(find.text('Volatility Smile (Strike Skew)'), findsOneWidget);
      expect(find.text('Term Structure (Moneyness)'), findsOneWidget);

      // Switch to Diagnostics tab
      await tester.tap(find.text('Diagnostics'));
      await tester.pumpAndSettle();

      expect(find.text('Surface Quantitative Breakdown'), findsOneWidget);
      expect(find.text('Term Structure Slope'), findsOneWidget);
      expect(find.text('25-Delta Risk Reversal'), findsOneWidget);
      expect(find.textContaining('Dupire Local Volatility'), findsOneWidget);
    });

    testWidgets('Opens Educational Guide dialog on help icon tap',
        (WidgetTester tester) async {
      setLargeTestWindow(tester);

      await tester.pumpWidget(
        buildTestableWidget(
          const IvSurface3dWidget(
            symbol: 'MSFT',
            spotPrice: 420.0,
            overrideCurrentIv: 0.25,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Help button in AppBar
      await tester.tap(find.byIcon(Icons.help_outline_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Volatility Surface Guide'), findsOneWidget);
      expect(
          find.text('What is an Implied Volatility Surface?'), findsOneWidget);
      expect(find.text('Volatility Smile & Skew'), findsOneWidget);
      expect(find.text('Dupire Local Volatility'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(find.text('Volatility Surface Guide'), findsNothing);
    });

    testWidgets('Renders cleanly on narrow viewport (360px) without overflow',
        (WidgetTester tester) async {
      setNarrowTestWindow(tester);

      await tester.pumpWidget(
        buildTestableWidget(
          const IvSurface3dWidget(
            symbol: 'SPY',
            spotPrice: 520.0,
            overrideCurrentIv: 0.16,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('SPY 3D Volatility Surface'), findsOneWidget);

      // Switch to 2D Slices on narrow viewport
      await tester.tap(find.text('2D Slices'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Switch to Diagnostics on narrow viewport
      await tester.tap(find.text('Diagnostics'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Tapping on 3D canvas selects node and shows inspection card',
        (WidgetTester tester) async {
      setLargeTestWindow(tester);

      await tester.pumpWidget(
        buildTestableWidget(
          const IvSurface3dWidget(
            symbol: 'NVDA',
            spotPrice: 130.0,
            overrideCurrentIv: 0.48,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the CustomPaint of the 3D surface
      final customPaintFinder = find.byType(CustomPaint);
      expect(customPaintFinder, findsWidgets);

      // Tap near the center of the 3D canvas
      await tester.tap(customPaintFinder.first);
      await tester.pumpAndSettle();

      // Verify inspected node card appears
      expect(find.byTooltip('Clear Selection'), findsOneWidget);
      expect(find.textContaining('Strike'), findsWidgets);
      expect(find.textContaining('Local Vol:'), findsOneWidget);

      // Dismiss selection
      await tester.tap(find.byTooltip('Clear Selection'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Clear Selection'), findsNothing);
    });
  });
}
