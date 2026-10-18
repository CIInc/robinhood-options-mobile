import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/portfolio_store.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';
import 'package:robinhood_options_mobile/widgets/margin_financing_widget.dart';

class MockActiveMarginCallService extends DemoService {
  @override
  Future<List<dynamic>> getMarginCalls(BrokerageUser user) async {
    final now = DateTime.now();
    return [
      {
        'id': 'mc_active_test',
        'account': 'https://api.robinhood.com/accounts/DEMO1234/',
        'account_number': 'DEMO1234',
        'type': 'maintenance',
        'state': 'open',
        'amount': 1200.00,
        'cash_deficit': 1200.00,
        'equity_deficit': 2400.00,
        'created_at': now.toIso8601String(),
        'due_date': now.add(const Duration(days: 2)).toIso8601String(),
        'reason': 'Maintenance margin deficit.',
      },
      {
        'id': 'mc_sat_test',
        'account': 'https://api.robinhood.com/accounts/DEMO1234/',
        'account_number': 'DEMO1234',
        'type': 'federal',
        'state': 'satisfied',
        'amount': 500.00,
        'created_at': now.subtract(const Duration(days: 10)).toIso8601String(),
      }
    ];
  }
}

void main() {
  testWidgets(
      'MarginFinancingWidget renders status hero, metrics, and financing costs tab',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final account = Account(
      'https://api.robinhood.com/accounts/DEMO1234/',
      18000.0,
      'DEMO1234',
      'margin',
      25000.0,
      'level_3',
      2500.0,
      0.0,
      5000.0,
    );

    final brokerageUser = BrokerageUser(
      BrokerageSource.demo,
      'demo_user',
      null,
      null,
      accounts: [account],
    );

    final accountStore = AccountStore();
    accountStore.add(account);
    accountStore.setSelectedAccountNumber('DEMO1234');
    final portfolioStore = PortfolioStore();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AccountStore>.value(value: accountStore),
          ChangeNotifierProvider<PortfolioStore>.value(value: portfolioStore),
        ],
        child: MaterialApp(
          home: MarginFinancingWidget(
            brokerageUser: brokerageUser,
            service: DemoService(),
            account: account,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify AppBar
    expect(find.text('Margin Calls & Financing'), findsOneWidget);

    // Verify Hero card in good standing
    expect(find.text('Good Standing - No Active Margin Calls'), findsOneWidget);

    // Verify Metrics
    expect(find.text('Active Calls'), findsOneWidget);
    expect(find.text('Total Deficit'), findsOneWidget);
    expect(find.text('2026 Interest'), findsOneWidget);

    // Verify Tab switching to Financing Costs
    await tester.tap(find.text('Financing Costs'));
    await tester.pumpAndSettle();

    expect(find.text('Financing Overview'), findsOneWidget);
    expect(find.text('Monthly Interest Debits'), findsOneWidget);
    expect(find.text('How Margin Interest is Calculated'), findsOneWidget);
    expect(find.text('Total Interest YTD'), findsOneWidget);

    // Verify Monthly Interest Debits row shows full subtitle and details
    expect(find.text('Margin Interest Charge - Prior Month'), findsOneWidget);
    expect(find.textContaining('6.5%'), findsWidgets);
    expect(find.textContaining('Avg Borrowed:'), findsWidgets);
  });

  testWidgets('MarginFinancingWidget renders active deficit demand call',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final account = Account(
      'https://api.robinhood.com/accounts/DEMO1234/',
      18000.0,
      'DEMO1234',
      'margin',
      25000.0,
      'level_3',
      2500.0,
      0.0,
      5000.0,
    );

    final brokerageUser = BrokerageUser(
      BrokerageSource.demo,
      'demo_user',
      null,
      null,
      accounts: [account],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MarginFinancingWidget(
          brokerageUser: brokerageUser,
          service: MockActiveMarginCallService(),
          account: account,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify active call hero title
    expect(find.textContaining('Active Margin Deficit:'), findsOneWidget);
    expect(find.textContaining('1,200.00'), findsWidgets);

    // Verify call card details
    expect(find.text('Maintenance Call'), findsOneWidget);
    expect(find.text('Active Deficit'), findsOneWidget);
    expect(find.text('Deficit Demand'), findsWidgets);
    expect(find.text('How to Resolve Margin Calls'), findsOneWidget);

    // Filter by resolved calls
    await tester.tap(find.text('Resolved'));
    await tester.pumpAndSettle();

    expect(find.text('Regulation T Call'), findsOneWidget);
    expect(find.text('Satisfied'), findsOneWidget);
  });

  testWidgets(
      'MarginFinancingWidget renders on narrow 320px viewport without overflow',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final account = Account(
      'https://api.robinhood.com/accounts/DEMO1234/',
      18000.0,
      'DEMO1234',
      'margin',
      25000.0,
      'level_3',
      2500.0,
      0.0,
      5000.0,
    );

    final brokerageUser = BrokerageUser(
      BrokerageSource.demo,
      'demo_user',
      null,
      null,
      accounts: [account],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MarginFinancingWidget(
          brokerageUser: brokerageUser,
          service: MockActiveMarginCallService(),
          account: account,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Deficit Demands and SegmentedButton rendered without exceptions or overflows
    expect(find.text('Deficit Demands'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Resolved'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Switch to Financing Costs tab on 320px viewport
    await tester.tap(find.text('Financing Costs'));
    await tester.pumpAndSettle();

    expect(find.text('Monthly Interest Debits'), findsOneWidget);
    expect(find.text('Margin Interest Charge - Prior Month'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
