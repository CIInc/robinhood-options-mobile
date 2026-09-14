import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';
import 'package:robinhood_options_mobile/widgets/banking_widget.dart';

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

  testWidgets('BankingWidget renders Transfers tab with hero metrics, banner, and transfers list',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final demoService = DemoService();

    await tester.pumpWidget(
      MaterialApp(
        home: BankingWidget(
          brokerageUser: testUser,
          service: demoService,
          account: testAccount,
          initialTabIndex: 0,
        ),
      ),
    );

    // Pump futures
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify AppBar
    expect(find.text('Banking & Transfers'), findsOneWidget);

    // Verify Tabs
    expect(find.text('Transfers'), findsOneWidget);
    expect(find.text('Linked Accounts'), findsOneWidget);

    // Verify Hero card
    expect(find.text('NET CASH MOVEMENT'), findsOneWidget);
    expect(find.text('Total Deposited'), findsOneWidget);
    expect(find.text('Total Withdrawn'), findsOneWidget);

    // Verify pending banner
    expect(find.textContaining('Pending Transfer'), findsOneWidget);

    // Verify search bar and filter chips
    expect(find.byType(TextField), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'All'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Deposits'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Withdrawals'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Pending'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Completed'), findsOneWidget);

    // Verify transfer cards
    expect(find.text('+\$1,000.00'), findsOneWidget);
    expect(find.text('+\$2,500.00'), findsOneWidget);
    expect(find.text('-\$750.00'), findsOneWidget);
    expect(find.text('+\$5,000.00'), findsOneWidget);

    // Tap on filter chip 'Pending'
    await tester.tap(find.widgetWithText(FilterChip, 'Pending'));
    await tester.pumpAndSettle();

    // Now only pending transfer should be displayed
    expect(find.text('+\$1,000.00'), findsOneWidget);
    expect(find.text('+\$2,500.00'), findsNothing);

    // Reset filter
    await tester.tap(find.widgetWithText(FilterChip, 'All'));
    await tester.pumpAndSettle();
    expect(find.text('+\$2,500.00'), findsOneWidget);

    // Tap on transfer card to open bottom sheet
    await tester.tap(find.text('+\$1,000.00'));
    await tester.pumpAndSettle();

    // Bottom sheet details
    expect(find.text('Deposit Details'), findsOneWidget);
    expect(find.text('Cancel Transfer'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);

    // Close bottom sheet
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
  });

  testWidgets('BankingWidget renders Linked Accounts tab with connected banks and guidelines',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final demoService = DemoService();

    await tester.pumpWidget(
      MaterialApp(
        home: BankingWidget(
          brokerageUser: testUser,
          service: demoService,
          account: testAccount,
          initialTabIndex: 1,
        ),
      ),
    );

    // Pump futures
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify Linked Accounts tab content
    expect(find.text('Linked Bank Accounts'), findsOneWidget);
    expect(find.text('YOUR CONNECTED BANKS'), findsOneWidget);

    // Verify Chase Bank card with PRIMARY badge
    expect(find.text('JPMorgan Chase Checking'), findsOneWidget);
    expect(find.text('PRIMARY'), findsOneWidget);
    expect(find.text('Verified'), findsWidgets);

    // Verify Ally Online Savings
    expect(find.text('Ally Online Savings'), findsOneWidget);

    // Verify Wells Fargo Premier Checking
    expect(find.text('Wells Fargo Premier Checking'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);

    // Verify ACH guidelines card
    expect(find.text('ACH Transfer Guidelines'), findsOneWidget);
    expect(find.textContaining('3-5 business days'), findsOneWidget);
  });
}
