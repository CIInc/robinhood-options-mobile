import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';
import 'package:robinhood_options_mobile/widgets/shareholder_qa_widget.dart';

void main() {
  final testUser = BrokerageUser(
    BrokerageSource.demo,
    'trader_alex',
    null,
    null,
  );

  final testInstrument = Instrument(
    id: 'aapl_inst',
    url: 'https://api.robinhood.com/instruments/aapl_inst/',
    quote: 'https://api.robinhood.com/quotes/AAPL/',
    fundamentals: 'https://api.robinhood.com/fundamentals/AAPL/',
    splits: 'https://api.robinhood.com/instruments/aapl_inst/splits/',
    state: 'active',
    market: 'https://api.robinhood.com/markets/XNAS/',
    name: 'Apple Inc.',
    simpleName: 'Apple',
    symbol: 'AAPL',
    country: 'US',
    type: 'stock',
    bloombergUnique: 'EQ0001',
    tradeable: true,
    tradability: 'tradable',
    rhsTradability: 'tradable',
    fractionalTradability: 'tradable',
    isSpac: false,
    isTest: false,
    ipoAccessSupportsDsp: false,
    dateCreated: DateTime(1980, 12, 12),
  );

  testWidgets(
      'ShareholderQaWidget renders header, status chip, shareholder banner, filter chips, and questions',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final demoService = DemoService();

    await tester.pumpWidget(
      MaterialApp(
        home: ShareholderQaWidget(
          brokerageUser: testUser,
          service: demoService,
          instrument: testInstrument,
          symbol: 'AAPL',
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    // Verify AppBar title
    expect(find.text('Shareholder Q&A'), findsOneWidget);

    // Verify status chip
    expect(find.text('VOTING OPEN'), findsOneWidget);

    // Verify verified shareholder banner
    expect(find.text('Verified Shareholder Status'), findsOneWidget);
    expect(find.text('Say Technologies'), findsWidgets);

    // Verify filter chips
    expect(find.text('Top (Shares)'), findsOneWidget);
    expect(find.text('Most Votes'), findsOneWidget);
    expect(find.textContaining('Answered'), findsOneWidget);
    expect(find.text('My Votes'), findsOneWidget);

    // Verify question content
    expect(
        find.text(
            'How is Apple Intelligence driving upgrade supercycles and expanding high-margin Services revenue globally?'),
        findsOneWidget);
    expect(find.textContaining('Chief Executive Officer'), findsOneWidget);

    // Verify Ask Question button / FAB
    expect(find.text('Ask Question'), findsOneWidget);
  });

  testWidgets('ShareholderQaWidget filters by Answered only',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final demoService = DemoService();

    await tester.pumpWidget(
      MaterialApp(
        home: ShareholderQaWidget(
          brokerageUser: testUser,
          service: demoService,
          symbol: 'AAPL',
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    // Filter to Answered
    await tester.tap(find.textContaining('Answered'));
    await tester.pumpAndSettle();

    // Answered question from Tim Cook should still be visible
    expect(
        find.text(
            'How is Apple Intelligence driving upgrade supercycles and expanding high-margin Services revenue globally?'),
        findsOneWidget);

    // Unanswered question should not be visible
    expect(
        find.text(
            'Are there any updates on Apple Silicon roadmaps for data center / cloud inference?'),
        findsNothing);
  });

  testWidgets('ShareholderQaWidget toggles upvote on a question',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final demoService = DemoService();

    await tester.pumpWidget(
      MaterialApp(
        home: ShareholderQaWidget(
          brokerageUser: testUser,
          service: demoService,
          symbol: 'AAPL',
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    // Find upvote button by tooltip or icon
    final upvoteButton = find.byTooltip('Remove Vote');
    expect(upvoteButton, findsWidgets);

    // Tap the first upvote button
    await tester.tap(upvoteButton.first);
    await tester.pump();
    await tester.pumpAndSettle();

    // Widget remains mounted and responsive
    expect(find.byType(ShareholderQaWidget), findsOneWidget);
  });

  testWidgets('ShareholderQaWidget opens submit question bottom sheet',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final demoService = DemoService();

    await tester.pumpWidget(
      MaterialApp(
        home: ShareholderQaWidget(
          brokerageUser: testUser,
          service: demoService,
          symbol: 'AAPL',
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    // Tap 'Ask Question' FAB
    await tester.tap(find.text('Ask Question'));
    await tester.pumpAndSettle();

    // Verify modal bottom sheet is open
    expect(find.text('Ask Management'), findsOneWidget);
    expect(find.text('Submit Question'), findsOneWidget);
    expect(
        find.textContaining(
            'Focus on long-term strategy'),
        findsOneWidget);

    // Tap Close icon to dismiss
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('Ask Management'), findsNothing);
  });

  testWidgets('ShareholderQaCard renders compact preview and responds to taps',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final demoService = DemoService();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShareholderQaCard(
            brokerageUser: testUser,
            service: demoService,
            instrument: testInstrument,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    // Verify card contents
    expect(find.text('Shareholder Q&A (Say)'), findsOneWidget);
    expect(find.text('ACTIVE'), findsOneWidget);
    expect(find.textContaining('Q3 2026 Earnings Call'), findsOneWidget);
    expect(find.text('TOP QUESTION'), findsOneWidget);

    // Tap card
    await tester.tap(find.byType(Card));
    await tester.pump();
    await tester.pumpAndSettle();

    // ShareholderQaWidget should be pushed onto Navigator
    expect(find.byType(ShareholderQaWidget), findsOneWidget);
  });
}
