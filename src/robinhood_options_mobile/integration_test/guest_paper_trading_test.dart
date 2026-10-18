import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:robinhood_options_mobile/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Guest Paper Trading Flow Test', () {
    testWidgets('Guest can add paper trading account and trigger session',
        (WidgetTester tester) async {
      // Clear storage
      SharedPreferences.setMockInitialValues({});

      // Start app
      app.main();

      // Wait for initialization
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      // 1. Verify Welcome Screen for Guest
      expect(find.text('Welcome to RealizeAlpha'), findsOneWidget);
      expect(find.text('Link Brokerage Account'), findsOneWidget);

      // 2. Tap Link Brokerage Account
      await tester.tap(find.text('Link Brokerage Account'));
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      // 3. Select Paper Trading
      // Based on app_test.dart, it should show 'Select Brokerage'
      expect(find.text('Select Brokerage'), findsOneWidget);

      final paperTradingChip = find.text('Paper Trading');
      await tester.tap(paperTradingChip);
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      // 4. Tap Open Paper Account
      final openPaperBtn = find.text('Open Paper Account');
      // Scroll if needed (login_widget.dart might have many options)
      try {
        final scrollable = find.byType(Scrollable).first;
        await tester.scrollUntilVisible(
          openPaperBtn,
          500.0,
          scrollable: scrollable,
        );
      } catch (e) {
        // Might already be visible or not in a scrollable
      }

      await tester.tap(openPaperBtn);

      // 5. Wait for Login completion and store initialization
      // This is where our fix in navigation_widget.dart kicks in
      // It calls setUser(auth.currentUser) which triggers Firestore loading
      for (int i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      // 6. Verify Logged In State (Paper Trading)
      // Welcome Screen should be gone
      expect(find.text('Welcome to RealizeAlpha', skipOffstage: true),
          findsNothing);

      // Verify that we are on the Home screen or Portfolio view
      // Usually after login, the Nav widget switches to the Home tab (Index 0)
      expect(find.text('Portfolio'), findsOneWidget);

      // Optionally verify Paper Trading banner or specific text
      // expect(find.text('Paper Account'), findsWidgets);
    });
  });
}
