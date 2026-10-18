import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';
import 'package:robinhood_options_mobile/widgets/corporate_actions_widget.dart';

void main() {
  final testUser = BrokerageUser(
    BrokerageSource.demo,
    'trader_alex',
    null,
    null,
  );

  final testAccount = Account(
    'https://api.robinhood.com/accounts/DEMO12345/',
    15000.0,
    'DEMO12345',
    'margin',
    30000.0,
    'option_level_3',
    0.0,
    0.0,
    0.0,
  );

  testWidgets(
      'CorporateActionsWidget renders hero metrics, filter chips, and split cards',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final demoService = DemoService();

    await tester.pumpWidget(
      MaterialApp(
        home: CorporateActionsWidget(
          brokerageUser: testUser,
          service: demoService,
          account: testAccount,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify AppBar title
    expect(find.text('Corporate Actions & Splits'), findsOneWidget);

    // Verify Hero Metrics
    expect(find.text('Stock Split Adjustments'), findsOneWidget);
    expect(find.text('Total Splits'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('Cash-in-Lieu'), findsWidgets);
    expect(find.text('\$32.65'), findsOneWidget);
    expect(find.text('Fwd / Rev'), findsOneWidget);
    expect(find.text('4 / 1'), findsOneWidget);

    // Verify Filter Chips
    expect(find.text('All (5)'), findsOneWidget);
    expect(find.text('Forward (4)'), findsOneWidget);
    expect(find.text('Reverse (1)'), findsOneWidget);
    expect(find.text('With Cash-in-Lieu'), findsOneWidget);

    // Verify split cards
    expect(find.text('NVDA'), findsOneWidget);
    expect(find.text('10:1 Split'), findsOneWidget);
    expect(find.text('TSLA'), findsOneWidget);
    expect(find.text('3:1 Split'), findsOneWidget);
    expect(find.text('AAPL'), findsOneWidget);
    expect(find.text('4:1 Split'), findsOneWidget);
    expect(find.text('BIOR'), findsOneWidget);
    expect(find.text('1:25 Rev Split'), findsOneWidget);
    expect(find.text('AMZN'), findsOneWidget);
    expect(find.text('20:1 Split'), findsOneWidget);
  });

  testWidgets(
      'CorporateActionsWidget filters by Reverse Splits and Cash-in-Lieu',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final demoService = DemoService();

    await tester.pumpWidget(
      MaterialApp(
        home: CorporateActionsWidget(
          brokerageUser: testUser,
          service: demoService,
          account: testAccount,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Filter to Reverse only
    await tester.tap(find.text('Reverse (1)'));
    await tester.pumpAndSettle();

    expect(find.text('BIOR'), findsOneWidget);
    expect(find.text('NVDA'), findsNothing);
    expect(find.text('TSLA'), findsNothing);

    // Filter to With Cash-in-Lieu
    await tester.tap(find.text('With Cash-in-Lieu'));
    await tester.pumpAndSettle();

    expect(find.text('NVDA'), findsOneWidget);
    expect(find.text('BIOR'), findsOneWidget);
    expect(find.text('TSLA'), findsNothing);
    expect(find.text('AAPL'), findsNothing);
  });

  testWidgets('CorporateActionsWidget searches by symbol',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final demoService = DemoService();

    await tester.pumpWidget(
      MaterialApp(
        home: CorporateActionsWidget(
          brokerageUser: testUser,
          service: demoService,
          account: testAccount,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Enter search query
    await tester.enterText(find.byType(TextField), 'TSLA');
    await tester.pumpAndSettle();

    // Verify card for TSLA is displayed, others are filtered out
    expect(find.widgetWithText(Card, '3:1 Split'), findsOneWidget);
    expect(find.widgetWithText(Card, 'NVDA'), findsNothing);
    expect(find.widgetWithText(Card, 'BIOR'), findsNothing);
  });

  testWidgets('CorporateActionsWidget opens details bottom sheet on card tap',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final demoService = DemoService();

    await tester.pumpWidget(
      MaterialApp(
        home: CorporateActionsWidget(
          brokerageUser: testUser,
          service: demoService,
          account: testAccount,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Tap on NVDA card
    await tester.tap(find.text('NVDA'));
    await tester.pumpAndSettle();

    // Verify bottom sheet contents
    expect(find.text('Conversion Mechanics'), findsOneWidget);
    expect(find.text('Stock / Asset'), findsOneWidget);
    expect(find.text('Company / Asset Name'), findsOneWidget);
    expect(find.text('Pre-Split Shares Held'), findsOneWidget);
    expect(find.text('15.5 sh'), findsWidgets);
    expect(find.text('Post-Split Shares Credited'), findsOneWidget);
    expect(find.text('155 sh'), findsWidgets);
    expect(find.text('Cash-in-Lieu (CIL) Paid'), findsOneWidget);
    expect(find.text('\$14.25'), findsWidgets);
    expect(find.text('Audit Record ID'), findsOneWidget);
    expect(find.text('Tax & Basis Reporting'), findsOneWidget);
  });

  testWidgets('CorporateActionsWidget opens info dialog from AppBar',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final demoService = DemoService();

    await tester.pumpWidget(
      MaterialApp(
        home: CorporateActionsWidget(
          brokerageUser: testUser,
          service: demoService,
          account: testAccount,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Tap info icon in AppBar
    await tester.tap(find.byIcon(Icons.info_outline));
    await tester.pumpAndSettle();

    expect(find.text('Corporate Actions FAQ'), findsOneWidget);
    expect(find.text('What is a Forward Stock Split?'), findsOneWidget);
    expect(find.text('What is Cash-in-Lieu (CIL)?'), findsOneWidget);

    // Dismiss
    await tester.tap(find.text('Got It'));
    await tester.pumpAndSettle();
    expect(find.text('Corporate Actions FAQ'), findsNothing);
  });

  testWidgets(
      'CorporateActionsWidget bottom sheet renders without overflow on narrow screens',
      (WidgetTester tester) async {
    // Set a compact mobile screen width (320px) to verify no RenderFlex overflow
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final demoService = DemoService();

    await tester.pumpWidget(
      MaterialApp(
        home: CorporateActionsWidget(
          brokerageUser: testUser,
          service: demoService,
          account: testAccount,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Tap on card to open bottom sheet
    await tester.tap(find.text('NVDA'));
    await tester.pumpAndSettle();

    // Verify Audit Record ID is shown without throwing layout overflow exception
    expect(find.text('Audit Record ID'), findsOneWidget);
    expect(find.text('split_pay_nvda_2024'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
