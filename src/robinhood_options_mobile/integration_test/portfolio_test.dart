import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:robinhood_options_mobile/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Portfolio Integration Tests', () {
    testWidgets('Login and verify Portfolio Widgets',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      app.main();

      // Pump initialization
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(seconds: 1));
      }

      // Login (Demo)
      if (find.text('Link Brokerage Account').evaluate().isNotEmpty) {
        await tester.tap(find.text('Link Brokerage Account'));
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 500));
        }
        await tester.tap(find.text('Demo'));
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 500));
        }

        final openDemoBtn = find.text('Open Demo Account');
        // Find scrollable
        final scrollable = find.byType(Scrollable).first;
        try {
          // ensureVisible requires skipOffstage: false if it's offstage
          await tester.scrollUntilVisible(openDemoBtn, 500.0,
              scrollable: scrollable);
        } catch (e) {
          debugPrint("Scroll failed: $e, trying ensureVisible");
          await tester.ensureVisible(
              find.text('Open Demo Account', skipOffstage: false));
        }
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 500));
        }
        await tester.tap(openDemoBtn);

        // Wait for Login
        for (int i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 500));
        }
      }

      // Verify Portfolio View
      expect(find.text('Welcome to RealizeAlpha', skipOffstage: true),
          findsNothing);

      // Refresh triggers
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      // Scroll down to build and show the cards
      final verticalScrollable = find.byType(Scrollable).first;
      await tester.drag(verticalScrollable, const Offset(0, -1000));
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }

      // Verify AI Trading Coach Card
      final aiCoach = find.text('AI Trading Coach');
      expect(aiCoach, findsOneWidget);

      // Verify Automated Trading Card
      final autoTrade = find.text('Stocks Agentic Trading');
      expect(autoTrade, findsOneWidget);
    });
  });
}
