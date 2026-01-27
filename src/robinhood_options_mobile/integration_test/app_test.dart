import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:robinhood_options_mobile/widgets/instrument_chart_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:robinhood_options_mobile/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App Integration Tests', () {
    testWidgets('App launch, search navigation, login and instrument detail',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});

      app.main();

      // Use pump loop instead of pumpAndSettle generally to avoid infinite timer timeouts
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(seconds: 1));
      }

      // 1. Verify Welcome Screen
      if (find.text('Welcome to RealizeAlpha').evaluate().isEmpty) {
        debugPrint(
            "Widgets found: ${find.byType(Text).evaluate().map((e) => (e.widget as Text).data).toList()}");
        // Pump more if needed
        await tester.pump(const Duration(seconds: 2));
      }
      expect(find.text('Welcome to RealizeAlpha'), findsOneWidget);
      expect(find.text('Link Brokerage Account'), findsOneWidget);

      // 2. Perform Login (Demo)
      await tester.tap(find.text('Link Brokerage Account'));
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      // Should be on Login Screen
      expect(find.text('Select Brokerage'), findsOneWidget);

      final demoChip = find.text('Demo');
      await tester.tap(demoChip);
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      final scrollable = find.byType(Scrollable).first;
      final openDemoBtn = find.text('Open Demo Account');

      await tester.scrollUntilVisible(
        openDemoBtn,
        500.0,
        scrollable: scrollable,
      );
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      await tester.tap(openDemoBtn);

      // Wait for Login completion - Use manual pumping to handle periodic timers starting after login
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      // 5. Verify Logged In State
      // Welcome Screen should be gone
      expect(find.text('Welcome to RealizeAlpha', skipOffstage: true),
          findsNothing);

      // "Link Brokerage Account" should be gone
      expect(find.text('Link Brokerage Account', skipOffstage: true),
          findsNothing);

      // 6. Navigate to Search Tab (Index 2) again as Logged In User
      final searchTab = find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Search'),
      );
      await tester.tap(searchTab);
      // Use pump loop instead of pumpAndSettle generally to avoid infinite timer timeouts
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      // Verify Search Page
      expect(find.byType(TextField), findsOneWidget);

      // Perform search for 'SPY'
      await tester.enterText(find.byType(TextField), 'SPY');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      // await tester.pumpAndSettle(); // Avoid pumpAndSettle due to potential infinite animations
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      // Verify Results
      await tester.pump(const Duration(seconds: 1));
      final cardFinder = find.text('SPDR S&P 500');
      expect(cardFinder, findsOneWidget);

      await tester.tap(cardFinder);
      // Wait for network/async navigation
      for (int i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      // 5c. Verify Instrument Details & Navigation to Option Chain
      // Verify we are on the Instrument Details page by looking for the Chart
      expect(find.byType(InstrumentChartWidget), findsOneWidget);
      expect(find.text('SPY'), findsAtLeastNWidgets(1));
      // Detail page usually has the name too
      expect(find.text('SPDR S&P 500'), findsAtLeastNWidgets(1));

      // Navigate back to Search
      await tester.pageBack();
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      // Verify back on Search Page
      expect(find.byType(TextField), findsOneWidget);

      // 7. Navigate to History Tab (Index 1)
      final historyTab = find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('History'),
      );
      await tester.tap(historyTab);
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      // Verify History Page
      // Demo mode might show empty history or mock history.
      // Verify the AppBar title or content.
      // HistoryWidget typically shows a list of orders.
      // Since we just logged in with Demo, it might be empty or loading.
      // Just verifying we navigated away from Search is good.
      expect(find.byType(TextField), findsNothing);
      // History Widget has title 'History' but ExpandedSliverAppBar might hide it or show empty text if Welcome widget was showing (which we fixed).
      // But we are logged in now, so title should be 'History'?
      // Actually HistoryWidget uses Constants.appTitle in AppBar in source code (which I edited to be '' when Welcome is shown).
      // When logged in, Welcome is NOT shown. So title should be Constants.appTitle.
      // But HistoryWidget code I saw:
      // title: const Text(Constants.appTitle), // History
      // So checking for Constants.appTitle ('RealizeAlpha') is valid.
      expect(find.text('RealizeAlpha'), findsOneWidget);

      // Success!
    });
  });
}
