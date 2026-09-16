import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/widgets/welcome_widget.dart';

void main() {
  Widget createTestableWidget(Widget child) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF002147),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF002147),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: Scaffold(
        body: child,
      ),
    );
  }

  group('WelcomeWidget Tests', () {
    testWidgets('renders default brand title, badge, and features',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          const WelcomeWidget(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Welcome to ${Constants.appTitle}'), findsOneWidget);
      expect(find.text('AI & Quantitative Trading Platform'), findsOneWidget);
      expect(find.text('Quantitative Auto-Trading'), findsOneWidget);
      expect(find.text('Real-Time Options Flow'), findsOneWidget);
      expect(find.text('Gamma Exposure (GEX) & Walls'), findsOneWidget);
      expect(find.text('Investor Groups & Copy Trading'), findsOneWidget);
      expect(find.text('Paper Trading & Backtesting'), findsOneWidget);
      expect(find.text('Multi-Brokerage Ecosystem'), findsOneWidget);
      expect(find.text('Robinhood'), findsOneWidget);
      expect(find.text('Schwab'), findsOneWidget);
      expect(find.text('Fidelity'), findsOneWidget);
    });

    testWidgets('renders contextual message banner when provided',
        (WidgetTester tester) async {
      const testMessage = 'Session expired. Please log in again.';
      await tester.pumpWidget(
        createTestableWidget(
          const WelcomeWidget(message: testMessage),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(testMessage), findsOneWidget);
    });

    testWidgets('handles onLogin callback and custom actionLabel',
        (WidgetTester tester) async {
      bool loginCalled = false;
      await tester.pumpWidget(
        createTestableWidget(
          WelcomeWidget(
            onLogin: () {
              loginCalled = true;
            },
            actionLabel: 'Connect Brokerage',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final buttonFinder =
          find.widgetWithText(FilledButton, 'Connect Brokerage');
      expect(buttonFinder, findsOneWidget);

      await tester.ensureVisible(buttonFinder);
      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      expect(loginCalled, isTrue);
    });

    testWidgets('handles onExploreDemo callback when provided',
        (WidgetTester tester) async {
      bool demoCalled = false;
      await tester.pumpWidget(
        createTestableWidget(
          WelcomeWidget(
            onExploreDemo: () {
              demoCalled = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final demoButtonFinder =
          find.widgetWithText(OutlinedButton, 'Explore Demo / Paper Mode');
      expect(demoButtonFinder, findsOneWidget);

      await tester.ensureVisible(demoButtonFinder);
      await tester.tap(demoButtonFinder);
      await tester.pumpAndSettle();

      expect(demoCalled, isTrue);
    });

    testWidgets('respects custom title and showFeatures=false',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          const WelcomeWidget(
            title: 'Custom Splash Header',
            showFeatures: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Custom Splash Header'), findsOneWidget);
      expect(find.text('Key Capabilities'), findsNothing);
      expect(find.text('Quantitative Auto-Trading'), findsNothing);
    });
  });
}
