import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:robinhood_options_mobile/main.dart';
import 'package:robinhood_options_mobile/services/remote_config_service.dart';
import 'firebase_mocks.dart';

void main() {
  setUpAll(() async {
    await setupFirebaseMocks();
  });

  testWidgets('Application opens', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    // Verify Welcome message is present (empty state)
    expect(find.text('Welcome to RealizeAlpha'), findsOneWidget);
  });

  testWidgets('Initial state shows Welcome screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Welcome to RealizeAlpha'), findsOneWidget);
    expect(find.text('Link Brokerage Account'), findsOneWidget);

    // Verify NOT seeing drawer as no user is logged in
    expect(find.byIcon(Icons.menu), findsNothing);
  });

  /*
  testWidgets('Login opens Login Page', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Link Brokerage Account'));
    await tester.pumpAndSettle();
    
    // Should navigate to Login/webview
    expect(find.text('Login'), findsOneWidget);
  });
  */

  /*
  testWidgets('Home Menu opens ModalBottomSheet smoke test',
      (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    /*
    // Verify that our counter starts at 0.
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // Tap the '+' icon and trigger a frame.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // Verify that our counter has incremented.
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
    */
    //expect(find.text('Home'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pump();
    expect(find.text('Menu'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pump();
    expect(find.text('RealizeAlpha'), findsOneWidget);
  });
  */
}
