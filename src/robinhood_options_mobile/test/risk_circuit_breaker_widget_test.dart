import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/risk_circuit_breaker_config.dart';
import 'package:robinhood_options_mobile/services/risk_circuit_breaker_service.dart';
import 'package:robinhood_options_mobile/widgets/risk_circuit_breaker_settings_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget createWidgetUnderTest({RiskCircuitBreakerService? service}) {
    return MaterialApp(
      theme: ThemeData.light(useMaterial3: true),
      home: RiskCircuitBreakerSettingsWidget(
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

  group('RiskCircuitBreakerSettingsWidget Tests', () {
    testWidgets('Renders all main sections and controls', (tester) async {
      setLargeTestWindow(tester);
      final service = RiskCircuitBreakerService(
        initialConfig: RiskCircuitBreakerConfig(
          enabled: true,
          maxDailyLossAmount: 500.0,
          maxDailyLossPercent: 3.0,
          maxDrawdownPercent: 10.0,
          maxConsecutiveLosses: 3,
          minMarginBufferPercent: 15.0,
          coolingOffDurationMinutes: 60,
        ),
      );

      await tester.pumpWidget(createWidgetUnderTest(service: service));
      await tester.pumpAndSettle();

      expect(find.text('Risk Circuit Breakers'), findsOneWidget);
      expect(find.text('Guarded & Active'), findsOneWidget);
      expect(find.text('Enable Risk Circuit Breakers'), findsOneWidget);
      expect(find.text('Daily Loss Limit'), findsOneWidget);
      expect(find.text('Max Peak Drawdown Limit'), findsOneWidget);
      expect(find.text('Consecutive Loss Lockout'), findsOneWidget);
      expect(find.text('Minimum Margin Buffer'), findsOneWidget);
      expect(find.text('Cooling-Off Period Duration'), findsOneWidget);
      expect(find.text('Guardrail Test Mode'), findsOneWidget);
      expect(find.text('About Institutional Risk Guardrails'), findsOneWidget);
    });

    testWidgets('Toggling master switch updates enabled state', (tester) async {
      final service = RiskCircuitBreakerService(
        initialConfig: RiskCircuitBreakerConfig(enabled: false),
      );

      await tester.pumpWidget(createWidgetUnderTest(service: service));
      await tester.pumpAndSettle();

      expect(find.text('Guardrails Inactive'), findsOneWidget);

      // Find and tap the switch tile
      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(service.config.enabled, true);
      expect(find.text('Guarded & Active'), findsOneWidget);
    });

    testWidgets('Displays active cooling-off status and trips correctly', (tester) async {
      final service = RiskCircuitBreakerService(
        initialConfig: RiskCircuitBreakerConfig(
          enabled: true,
          isTripped: true,
          tripReason: 'Test trip reason',
          coolingOffUntil: DateTime.now().add(const Duration(minutes: 30)),
        ),
      );

      await tester.pumpWidget(createWidgetUnderTest(service: service));
      await tester.pumpAndSettle();

      expect(find.textContaining('Cooling Off Active'), findsOneWidget);
      expect(find.text('Test trip reason'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);
    });

    testWidgets('Simulate trip button activates 2-min cooling off', (tester) async {
      setLargeTestWindow(tester);
      final service = RiskCircuitBreakerService(
        initialConfig: RiskCircuitBreakerConfig(enabled: true),
      );

      await tester.pumpWidget(createWidgetUnderTest(service: service));
      await tester.pumpAndSettle();

      final simulateBtn = find.text('Simulate 2-Min Circuit Breaker Trip');
      await tester.ensureVisible(simulateBtn);
      await tester.tap(simulateBtn);
      await tester.pumpAndSettle();

      expect(service.config.isTripped, true);
      expect(service.config.isInCoolingOff, true);
      expect(find.textContaining('Cooling Off Active'), findsOneWidget);
    });

    testWidgets('Reset button opens confirmation dialog and clears tripped state', (tester) async {
      final service = RiskCircuitBreakerService(
        initialConfig: RiskCircuitBreakerConfig(
          enabled: true,
          isTripped: true,
          tripReason: 'Emergency trip',
          coolingOffUntil: DateTime.now().add(const Duration(minutes: 10)),
        ),
      );

      await tester.pumpWidget(createWidgetUnderTest(service: service));
      await tester.pumpAndSettle();

      final resetBtn = find.text('Reset');
      await tester.tap(resetBtn);
      await tester.pumpAndSettle();

      expect(find.text('Reset Circuit Breaker?'), findsOneWidget);
      final confirmBtn = find.text('Confirm Reset');
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      expect(service.config.isTripped, false);
      expect(service.config.isInCoolingOff, false);
      expect(find.text('Guarded & Active'), findsOneWidget);
    });

    testWidgets('Selecting daily loss chip updates dollar amount', (tester) async {
      setLargeTestWindow(tester);
      final service = RiskCircuitBreakerService(
        initialConfig: RiskCircuitBreakerConfig(enabled: true),
      );

      await tester.pumpWidget(createWidgetUnderTest(service: service));
      await tester.pumpAndSettle();

      final chip1000 = find.text('\$1000');
      await tester.ensureVisible(chip1000);
      await tester.tap(chip1000);
      await tester.pumpAndSettle();

      expect(service.config.maxDailyLossAmount, 1000.0);
    });
  });
}
