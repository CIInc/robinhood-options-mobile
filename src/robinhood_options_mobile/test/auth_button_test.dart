import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/widgets/auth_widget.dart';

void main() {
  group('Auth Button Tests', () {
    test('AuthButtonType enum contains apple and google', () {
      expect(AuthButtonType.values, contains(AuthButtonType.apple));
      expect(AuthButtonType.values, contains(AuthButtonType.google));
    });

    testWidgets('renders Sign in with Apple button in light mode',
        (WidgetTester tester) async {
      bool pressed = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.light),
          home: Scaffold(
            body: Builder(
              builder: (context) => buildAuthButton(
                context,
                AuthButtonType.apple,
                () {
                  pressed = true;
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Sign in with Apple'), findsOneWidget);
      expect(find.byIcon(Icons.apple), findsOneWidget);

      await tester.tap(find.text('Sign in with Apple'));
      await tester.pumpAndSettle();

      expect(pressed, isTrue);
    });

    testWidgets('renders Sign in with Apple button in dark mode',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: Scaffold(
            body: Builder(
              builder: (context) => buildAuthButton(
                context,
                AuthButtonType.apple,
                () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Sign in with Apple'), findsOneWidget);
      expect(find.byIcon(Icons.apple), findsOneWidget);

      final icon = tester.widget<Icon>(find.byIcon(Icons.apple));
      expect(icon.color, Colors.black);
    });

    testWidgets('renders Sign in with Google button',
        (WidgetTester tester) async {
      bool pressed = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.light),
          home: Scaffold(
            body: Builder(
              builder: (context) => buildAuthButton(
                context,
                AuthButtonType.google,
                () {
                  pressed = true;
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Sign in with Google'), findsOneWidget);

      await tester.tap(find.text('Sign in with Google'));
      await tester.pumpAndSettle();

      expect(pressed, isTrue);
    });
  });
}
