// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility that Flutter provides. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:robinhood_options_mobile/main.dart';

void main() {
  testWidgets('Application opens', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());
    expect(find.text('Investiomanus'), findsOneWidget);
  });

  testWidgets('Home Menu opens Drawer', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pump();
    expect(find.text('Login'), findsOneWidget);
  });

  testWidgets('Login opens Login Page', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pump();
    expect(find.text('Login'), findsOneWidget);

    //await tester.tap(find.byIcon(Icons.verified_user));
    await tester.tap(find.text('Login'));
    await tester.pump();

    /*

    expect(find.byType(TextField), findsWidgets);
    expect(find.byIcon(Icons.login_outlined), findsOneWidget);
    expect(find.text('Robinhood password'), findsOneWidget);
    */
  });

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
    expect(find.text('Investiomanus'), findsOneWidget);
  });
  */
}
