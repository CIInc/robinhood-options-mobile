import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';
import 'package:robinhood_options_mobile/widgets/stock_loan_widget.dart';

void main() {
  final testUser = BrokerageUser(
    BrokerageSource.demo,
    'trader_test',
    null,
    null,
  );

  final testAccount = Account(
    'https://api.robinhood.com/accounts/ACCT12345/',
    12500.0,
    'ACCT12345',
    'margin',
    25000.0,
    'option_level_3',
    0.0,
    0.0,
    0.0,
  );

  testWidgets('StockLoanWidget renders SLIP tab with hero metrics and positions',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final demoService = DemoService();

    await tester.pumpWidget(
      MaterialApp(
        home: StockLoanWidget(
          brokerageUser: testUser,
          service: demoService,
          account: testAccount,
          initialTabIndex: 0,
        ),
      ),
    );

    // Wait for futures
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify AppBar title and subtitles
    expect(find.text('Stock Lending & Cash Sweeps'), findsOneWidget);
    expect(find.textContaining('ACCT12345'), findsOneWidget);

    // Verify TabBar
    expect(find.text('Securities Lending (SLIP)'), findsOneWidget);
    expect(find.text('Cash Sweeps & APY'), findsOneWidget);

    // Verify SLIP Hero metrics
    expect(find.text('Stock Lending Status'), findsOneWidget);
    expect(find.text('Enrolled & Earning'), findsOneWidget);
    expect(find.text('YTD Earned'), findsOneWidget);
    expect(find.text('All-Time Earned'), findsOneWidget);
    expect(find.text('Last Payment'), findsOneWidget);

    // Verify Loaned Securities section
    expect(find.text('Securities on Loan'), findsOneWidget);
    expect(find.textContaining('102% cash collateral'), findsOneWidget);
    expect(find.text('TSLA'), findsWidgets);
    expect(find.text('GME'), findsWidgets);

    // Verify Payment Ledger
    expect(find.text('Payment Ledger'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    // Filter payments
    await tester.enterText(find.byType(TextField), 'GME');
    await tester.pump();
    expect(find.text('Payment Ledger'), findsOneWidget);
  });

  testWidgets('StockLoanWidget switches to Cash Sweeps & APY tab with rates and calculator',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final demoService = DemoService();

    await tester.pumpWidget(
      MaterialApp(
        home: StockLoanWidget(
          brokerageUser: testUser,
          service: demoService,
          account: testAccount,
          initialTabIndex: 1,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify Sweeps Hero Card
    expect(find.text('Current Cash Sweeps APY'), findsOneWidget);
    expect(find.text('5.00%'), findsWidgets);
    expect(find.textContaining('FDIC'), findsWidgets);
    expect(find.text('Swept Balance'), findsOneWidget);
    expect(find.text('Est. Monthly'), findsOneWidget);
    expect(find.text('Est. Annual'), findsOneWidget);

    // Verify Rate Tiers Comparison
    expect(find.text('Rate Tiers Comparison'), findsOneWidget);
    expect(find.text('Standard'), findsOneWidget);
    expect(find.text('1.50%'), findsOneWidget);
    expect(find.text('Robinhood Gold'), findsOneWidget);

    // Verify Yield Calculator
    expect(find.text('Cash Yield Calculator'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);

    // Verify Partner Banks
    expect(find.text('FDIC Program Banks Network'), findsOneWidget);
    expect(find.text('Citibank, N.A.'), findsOneWidget);
    expect(find.text('Goldman Sachs Bank USA'), findsOneWidget);
  });

  testWidgets(
      'StockLoanWidget renders Cash Sweeps tab on narrow viewport without overflow',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final demoService = DemoService();

    await tester.pumpWidget(
      MaterialApp(
        home: StockLoanWidget(
          brokerageUser: testUser,
          service: demoService,
          account: testAccount,
          initialTabIndex: 1,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Current Cash Sweeps APY'), findsOneWidget);
    expect(find.textContaining('FDIC'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
