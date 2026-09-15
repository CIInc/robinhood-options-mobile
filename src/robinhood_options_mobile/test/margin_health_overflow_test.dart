import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/portfolio_store.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';
import 'package:robinhood_options_mobile/widgets/margin_health_widget.dart';

void main() {
  testWidgets(
    'Test MarginHealthWidget for layout overflows across multiple device sizes',
    (WidgetTester tester) async {
      final account = Account(
        'https://api.robinhood.com/accounts/5RA1234567890/',
        18000.0,
        '5RA1234567890',
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
      accountStore.setSelectedAccountNumber('5RA1234567890');
      final portfolioStore = PortfolioStore();

      // Test on small screen (320px, 360px, 390px)
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
              ChangeNotifierProvider<PortfolioStore>.value(
                value: portfolioStore,
              ),
            ],
            child: MaterialApp(
              home: MarginHealthWidget(
                brokerageUser: brokerageUser,
                service: DemoService(),
                account: account,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(
          tester.takeException(),
          isNull,
          reason: 'Layout overflowed on size $size',
        );
      }

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );
}
