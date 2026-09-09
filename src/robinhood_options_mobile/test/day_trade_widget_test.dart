import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';
import 'package:robinhood_options_mobile/widgets/day_trade_monitor_widget.dart';

void main() {
  testWidgets(
      'DayTradeMonitorWidget renders PDT counter, threshold, and trades',
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
      18000.0,
      'level_3',
      0.0,
      0.0,
      0.0,
      dayTradesProtection: true,
      dayTradeBuyingPower: 41505.26,
      dayTradeRatio: 0.25,
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

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AccountStore>.value(value: accountStore),
        ],
        child: MaterialApp(
          home: DayTradeMonitorWidget(
            brokerageUser: brokerageUser,
            service: DemoService(),
            account: account,
          ),
        ),
      ),
    );

    // Initial loading indicator
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Wait for future to complete
    await tester.pumpAndSettle();

    // Verify Title and app bar
    expect(find.text('Day Trade & PDT Monitor'), findsOneWidget);

    // Verify account and header details
    expect(find.text('Account DEMO1234'), findsOneWidget);
    expect(find.text('MARGIN ACCOUNT'), findsOneWidget);
    expect(find.text('Rolling 5-Day Trades Counter'), findsOneWidget);
    expect(find.text('2 of 3 Allowed Day Trades Used'), findsOneWidget);
    expect(find.text('1 Trade Left'), findsOneWidget);

    // Verify FINRA $25,000 threshold section
    expect(find.text('FINRA \$25,000 Equity Threshold'), findsOneWidget);
    expect(find.text('Threshold: \$25,000.00'), findsOneWidget);
    expect(find.textContaining('Deficit: \$7,000.00'), findsOneWidget);

    // Verify Protection & Buying Power section
    expect(find.text('Protection & Buying Power'), findsOneWidget);
    expect(find.text('Robinhood Day Trade Protection'), findsOneWidget);
    expect(find.text('Protected'), findsOneWidget);
    expect(find.text('\$41,505.26'), findsOneWidget);

    // Verify Trades section
    expect(find.text('Recent Day Trades (2)'), findsOneWidget);
    expect(find.text('AAPL'), findsOneWidget);
    expect(find.text('EQUITY'), findsOneWidget);
    expect(find.text('TSLA 260327C00220000'), findsOneWidget);
    expect(find.text('OPTION'), findsOneWidget);

    // Verify FAQ accordion
    expect(find.text('FINRA Rule 4210 & PDT Guide'), findsOneWidget);

    // Filter by Options
    await tester.tap(find.text('Options'));
    await tester.pumpAndSettle();

    expect(find.text('TSLA 260327C00220000'), findsOneWidget);
    expect(find.text('AAPL'), findsNothing);

    // Filter by Stocks
    await tester.tap(find.text('Stocks'));
    await tester.pumpAndSettle();

    expect(find.text('AAPL'), findsOneWidget);
    expect(find.text('TSLA 260327C00220000'), findsNothing);
  });
}
