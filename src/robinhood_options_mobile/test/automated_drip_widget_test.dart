import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/automated_drip_config.dart';
import 'package:robinhood_options_mobile/services/automated_drip_service.dart';
import 'package:robinhood_options_mobile/widgets/automated_drip_settings_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget createWidgetUnderTest({AutomatedDripService? service}) {
    return MaterialApp(
      theme: ThemeData.light(useMaterial3: true),
      home: AutomatedDripSettingsWidget(
        service: service,
      ),
    );
  }

  void setLargeTestWindow(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('AutomatedDripSettingsWidget Tests', () {
    testWidgets('Renders all main sections and stats when active',
        (tester) async {
      setLargeTestWindow(tester);
      final service = AutomatedDripService(
        initialConfig: AutomatedDripConfig(
          enabled: true,
          defaultMode: DripThresholdMode.belowCostBasis,
          instrumentRules: {
            'AAPL': InstrumentDripRule(
              symbol: 'AAPL',
              targetPrice: 175.0,
              thresholdMode: DripThresholdMode.belowFixedPrice,
            ),
          },
          transactions: [
            DripTransaction(
              id: 'tx_1',
              timestamp: DateTime.now(),
              symbol: 'AAPL',
              dividendAmount: 42.00,
              executionPrice: 172.00,
              thresholdPrice: 175.00,
              sharesPurchased: 0.244,
              status: 'executed',
            ),
          ],
        ),
      );

      await tester.pumpWidget(createWidgetUnderTest(service: service));
      await tester.pumpAndSettle();

      expect(find.text('Automated DRIP'), findsOneWidget);
      expect(find.text('Automated Threshold DRIP'), findsOneWidget);
      expect(find.text('Active • Reinvesting below threshold'), findsOneWidget);
      expect(find.text('Global Reinvestment Strategy'), findsOneWidget);
      expect(find.text('Default Threshold Rule'), findsOneWidget);
      expect(find.text('AAPL'), findsWidgets);
      expect(find.text('EXECUTED'), findsOneWidget);
      expect(find.text('\$42.00'), findsWidgets);
    });

    testWidgets('Toggles master switch dynamically', (tester) async {
      setLargeTestWindow(tester);
      final service = AutomatedDripService(
        initialConfig: AutomatedDripConfig(enabled: false),
      );

      await tester.pumpWidget(createWidgetUnderTest(service: service));
      await tester.pumpAndSettle();

      expect(find.text('Disabled • Dividends remain as cash'), findsOneWidget);

      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(service.config.enabled, true);
      expect(find.text('Active • Reinvesting below threshold'), findsOneWidget);
    });

    testWidgets('Renders empty states when no rules or transactions exist',
        (tester) async {
      setLargeTestWindow(tester);
      final service = AutomatedDripService(
        initialConfig: AutomatedDripConfig(enabled: true),
      );

      await tester.pumpWidget(createWidgetUnderTest(service: service));
      await tester.pumpAndSettle();

      expect(find.textContaining('No custom symbol rules configured'),
          findsOneWidget);
      expect(find.textContaining('No DRIP transactions logged yet'),
          findsOneWidget);
    });

    testWidgets('Opens Add Custom DRIP Rule dialog without overflow on narrow screen',
        (tester) async {
      // Simulate narrow mobile screen (iPhone SE / small mobile: 320x568)
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final service = AutomatedDripService(
        initialConfig: AutomatedDripConfig(enabled: true),
      );

      await tester.pumpWidget(createWidgetUnderTest(service: service));
      await tester.pumpAndSettle();

      // Tap the + (Add Symbol Rule) icon button in the AppBar
      final addIconFinder = find.byIcon(Icons.add);
      expect(addIconFinder, findsOneWidget);
      await tester.tap(addIconFinder);
      await tester.pumpAndSettle();

      // Verify dialog is open and form fields render without overflow
      expect(find.text('Add Custom DRIP Rule'), findsOneWidget);
      expect(find.text('Threshold Type'), findsOneWidget);
      expect(find.text('Below Average Cost Basis'), findsOneWidget);
      expect(find.text('Order Type'), findsOneWidget);

      // Verify cancel button dismisses dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Add Custom DRIP Rule'), findsNothing);
    });
  });
}

