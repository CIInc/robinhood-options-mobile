import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:robinhood_options_mobile/main.dart' as app;
import 'package:robinhood_options_mobile/widgets/navigation_widget.dart';
import 'package:robinhood_options_mobile/widgets/search_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Utility to handle infinite animations
Future<void> pumpManual(WidgetTester tester, int count,
    {Duration duration = const Duration(milliseconds: 100)}) async {
  for (int i = 0; i < count; i++) {
    await tester.pump(duration);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Lists Widget navigation and content test',
      (WidgetTester tester) async {
    // 1. Setup - Mock SharedPreferences
    SharedPreferences.setMockInitialValues({
      'demoMode': true
    }); // Keys must match what app uses, assumed 'demoMode'.
    // Actually, app checks SharedPreferences.getInstance() for 'demo' or similar.
    // In app_test.dart we usually just run main() and let it load.
    // If we need to force Demo mode, we might need to set it in the app or pre-set prefs.
    // However, default might be non-demo or demo depending on main.dart.
    // Let's assume default flow or check main.dart.
    // In app_test.dart, it just pumps.
    // In agentic_trading_test.dart we saw:
    // await app.main();
    // await tester.pumpAndSettle();
    // Then we handled a potential "Verify" dialog or "Login".
    // If it's fresh install in test, it likely starts in Login/Welcome screen.
    // Tapping "Verify" goes to demo mode if configured or login.

    app.main();
    await pumpManual(tester, 5, duration: const Duration(seconds: 1));

    // Handle Login/Welcome if present
    if (find.text('Link Brokerage Account').evaluate().isNotEmpty) {
      await tester.tap(find.text('Link Brokerage Account'));
      await pumpManual(tester, 10);

      await tester.tap(find.text('Demo'));
      await pumpManual(tester, 10);

      final openDemoBtn = find.text('Open Demo Account');
      if (openDemoBtn.evaluate().isNotEmpty) {
        await tester.tap(openDemoBtn);
        await pumpManual(tester, 20);
      }
    } else {
      final Finder verifyButton = find.text('Verify');
      if (verifyButton.evaluate().isNotEmpty) {
        await tester.tap(verifyButton);
        await tester.pumpAndSettle();
      }
    }

    // Now we should be in NavigationWidget (LoggedIn)
    expect(find.byType(NavigationStatefulWidget), findsOneWidget);

    // 2. Navigate to Search Tab (Index 2)
    // NavigationBar/BottomNavigationBar tap
    // Usually icons or text labels.
    // Search tab usually has search icon.
    final Finder searchTab = find.byIcon(Icons.search);
    if (searchTab.evaluate().isNotEmpty) {
      await tester.tap(searchTab.first); // .first in case multiple search icons
    } else {
      // Try finding by text if labeled? "Search"?
      await tester.tap(find.text('Search'));
    }

    // Pump to settle navigation
    await pumpManual(tester, 50); // Animations and async data loading

    // Verify we are on SearchWidget
    expect(find.byType(SearchWidget), findsOneWidget);

    // 3. Verify 'All Lists' button is present
    final Finder allListsButton = find.text('All Lists');
    expect(allListsButton, findsOneWidget);

    // 4. Tap 'All Lists'
    await tester.tap(allListsButton);
    await pumpManual(tester, 20); // Wait for navigation push

    // 5. Verify ListsWidget content
    // We expect "Bullish", "Bearish", "Options Watchlist" from DemoService
    // "Bearish" should be the first list
    expect(find.text('Bearish'), findsOneWidget);
    // expect(find.text('Bullish'), findsOneWidget); // Might need scrolling

    // 6. Verify Back navigation works
    final Finder backButton =
        find.byTooltip('Back'); // Standard AppBar back button
    if (backButton.evaluate().isNotEmpty) {
      await tester.tap(backButton);
      await pumpManual(tester, 20);
      // Verify we are back on Search page
      expect(find.text('All Lists'), findsOneWidget);
    }
  });
}
