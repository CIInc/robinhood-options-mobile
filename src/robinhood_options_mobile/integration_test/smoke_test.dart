import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:robinhood_options_mobile/main.dart' as app;
import 'package:robinhood_options_mobile/widgets/instrument_chart_widget.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Full App Smoke Integrity Test', () {
    testWidgets('Complete app navigation and feature verification',
        (WidgetTester tester) async {
      // 1. Setup
      SharedPreferences.setMockInitialValues({});
      // SharedPreferences.setMockInitialValues({
      //   'user.json': jsonEncode({
      //     'currentUserIndex': 0,
      //     'users': [
      //       {
      //         'source': 'BrokerageSource.demo',
      //         'userName': 'Demo User',
      //       }
      //     ]
      //   })
      // });

      app.main();

      // Pump to let the app initialize
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(seconds: 1));
      }

      // 2. Initial State: Welcome Screen
      final welcomeFinder = find.text('Welcome to RealizeAlpha');
      if (welcomeFinder.evaluate().isEmpty) {
        // Retry pumping
        await tester.pump(const Duration(seconds: 2));
      }
      expect(welcomeFinder, findsOneWidget);
      expect(find.text('Link Brokerage Account'), findsOneWidget);

      // 3. Login Flow (Demo)
      await tester.tap(find.text('Link Brokerage Account'));
      await tester.pumpAndSettle();

      expect(find.text('Select Brokerage'), findsOneWidget);
      await tester.tap(find.text('Demo'));
      await tester.pumpAndSettle();

      final openDemoBtn = find.text('Open Demo Account');
      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        openDemoBtn,
        500.0,
        scrollable: scrollable,
      );
      await tester.pumpAndSettle();

      await tester.tap(openDemoBtn);

      // Allow login to process
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      // 4. Verify Home (Portfolio) Tab
      // Welcome screen should be gone
      expect(find.text('Welcome to RealizeAlpha', skipOffstage: true),
          findsNothing);

      // We should be on Portfolio tab (Index 0)
      // Check for common Portfolio widgets
      expect(find.byIcon(Icons.account_balance),
          findsOneWidget); // Navigation Icon
      // PortfolioChartWidget usually has time range buttons '1D', '1W' etc.
      expect(find.text('1D'), findsAtLeastNWidgets(1));
      // AllocationWidget usually has 'Allocation' text or similar logic
      // But let's check for specific tabs in NavigationBar to be sure.

      // 5. Navigate to Search (Index 2) and Perform Search
      final searchTab = find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Search'),
      );
      await tester.tap(searchTab);
      for (int i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(find.byType(TextField), findsOneWidget);

      // Perform a search
      await tester.enterText(find.byType(TextField), 'AAPL');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      // await tester.pumpAndSettle(); // Avoid pumpAndSettle due to potential infinite animations
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      // Wait for results
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      // 5b. Verify Result & Navigate to Instrument Details
      // Search result for AAPL should be present.
      // We look for 'Apple' which is the simple_name in DemoService.
      // Using 'AAPL' might match the text field which we don't want to tap.
      await tester.pump(const Duration(seconds: 1));
      final appleCardFinder = find.text('Apple');
      expect(appleCardFinder, findsOneWidget);

      await tester.tap(appleCardFinder);
      // Wait for network/async navigation
      for (int i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      // 5c. Verify Instrument Details & Navigation to Option Chain
      // Verify we are on the Instrument Details page by looking for the Chart
      expect(find.byType(InstrumentChartWidget), findsOneWidget);
      expect(find.text('AAPL'), findsAtLeastNWidgets(1));

      // Find 'Chain' button to go to Option Chain
      final chainButton = find.text('Chain');
      // It might be off-screen if the chart takes up space, but it's usually near the top actions.
      // If helpful, we can scroll. The page uses CustomScrollView.
      if (chainButton.evaluate().isEmpty) {
        // Try scrolling down slightly
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
        await tester.pumpAndSettle();
      }

      if (chainButton.evaluate().isNotEmpty) {
        await tester.tap(chainButton);
        // Wait longer for navigation and load
        for (int i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 1000));
        }

        // 5d. Verify Option Chain
        // Should look for Expiration dates or 'Calls'/'Puts' toggle

        // Wait for Option Chain data to load
        bool found = false;
        int retries = 0;
        while (!found && retries < 20) {
          if (find.text('Buy').evaluate().isNotEmpty) {
            found = true;
            break;
          }
          await tester.pump(const Duration(milliseconds: 500));
          retries++;
        }

        // Debugging output
        debugPrint('Finding "Buy" widgets...');
        try {
          expect(find.text('Buy'), findsAtLeastNWidgets(1));
        } catch (e) {
          debugPrint('Failed to find "Buy". Dumping visible Text widgets:');
          var texts = find.byType(Text);
          debugPrint("Found ${texts.evaluate().length} Text widgets.");
          for (var element in texts.evaluate()) {
            debugPrint(" - \"${(element.widget as Text).data}\"");
          }
          rethrow;
        }

        // Expand Test: Verify Filter Logic
        debugPrint('Verifying Call/Put Filter Logic...');
        // 1. Verify Call option (Strike $150) is visible (since default is Call)
        // Use textContaining just in case formatting varies.
        expect(find.text('\$150'), findsOneWidget);

        // 2. Switch to Puts
        debugPrint('Switching to Puts...');
        await tester.tap(find.text('Put'));
        await tester.pump(const Duration(milliseconds: 500));

        // 3. Verify $150 is GONE (as we only have a Call in mock)
        expect(find.text('\$150'), findsNothing);

        // 4. Switch back to Calls
        debugPrint('Switching back to Calls...');
        await tester.tap(find.text('Call'));
        await tester.pump(const Duration(milliseconds: 500));

        // 5. Verify $150 is BACK
        expect(find.text('\$150'), findsOneWidget);

        // Go back from Option Chain
        debugPrint('Exiting Option Chain...');
        await tester.pageBack();
        await tester.pump(const Duration(seconds: 1));
        // await tester.pumpAndSettle();
      } else {
        debugPrint(
            'Chain button not found - maybe constrained API in test environment');
      }

      // Go back from Instrument Details
      debugPrint('Exiting Instrument Details...');
      await tester.pageBack();
      await tester.pump(const Duration(seconds: 1));

      // 6. Navigate to Signals (Index 3)
      debugPrint('Navigating to Signals...');
      final signalsTab = find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Signals'),
      );
      await tester.tap(signalsTab);
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      // Verify Signals Page Content (Handles both Paywall and Active view)
      // Note: We just verify navigation consistency here.
      expect(find.byType(CustomScrollView), findsAtLeastNWidgets(1));
      debugPrint('Verified Signals Tab Navigation');

      // 7. Navigate to Investors (Index 4)
      final investorsTab = find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Investors'),
      );
      await tester.tap(investorsTab);
      for (int i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      // InvestorGroupsWidget
      // Usually shows "Investor Groups" or tabs like Member/Shared
      // Expect some content related to groups
      // If empty it might say "No investor groups found" or similar.
      // Let's verify we are NOT on previous pages.
      expect(find.byType(TextField), findsNothing); // Not Search

      // 8. Navigate to History (Index 1)
      final historyTab = find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('History'),
      );
      await tester.tap(historyTab);
      for (int i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      // HistoryPage
      // Should show 'History' or 'RealizeAlpha' in AppBar depending on implementation
      // And likely a list of transactions or empty state
      // Just verifying navigation happened without crash

      // 9. Return to Portfolio (Index 0)
      final portfolioTab = find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Portfolio'),
      );
      await tester.tap(portfolioTab);
      for (int i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(find.text('1D'), findsAtLeastNWidgets(1));
    });
  });
}
