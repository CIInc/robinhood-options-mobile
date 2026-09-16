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
      'Test DayTradeMonitorWidget for layout overflows across multiple device sizes',
      (WidgetTester tester) async {
    final account = Account(
      'https://api.robinhood.com/accounts/5RA1234567890/',
      18000.0,
      '5RA1234567890',
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
    accountStore.setSelectedAccountNumber('5RA1234567890');

    // Test on small screen (iPhone SE width: 320 or 375, fontScale 1.0 and 1.3)
    final testSizes = [
      const Size(320, 600),
      const Size(360, 640),
      const Size(390, 844),
    ];

    for (var size in testSizes) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;

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

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull,
          reason: 'Failed on screen size: $size');
    }

    // Now test with PDT Exempt account ($35k equity)
    final exemptAccount = Account(
      'https://api.robinhood.com/accounts/5RA1234567890/',
      35000.0,
      '5RA1234567890',
      'margin',
      35000.0,
      'level_3',
      0.0,
      0.0,
      0.0,
      dayTradesProtection: true,
      dayTradeBuyingPower: 70000.0,
      dayTradeRatio: 0.25,
    );

    for (var size in testSizes) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AccountStore>.value(value: accountStore),
          ],
          child: MaterialApp(
            home: DayTradeMonitorWidget(
              brokerageUser: brokerageUser,
              service: DemoService(),
              account: exemptAccount,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      final err = tester.takeException();
      if (err is FlutterError) {
        for (final node in err.diagnostics) {
          debugPrint('Node: ${node.toStringDeep()}');
        }
      }
      expect(err, isNull, reason: 'Failed for exempt on screen size: $size');
    }

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
