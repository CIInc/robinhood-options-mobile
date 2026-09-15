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
    'MarginHealthWidget renders hero buffer, buying powers, and collateral',
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
            home: MarginHealthWidget(
              brokerageUser: brokerageUser,
              service: DemoService(),
              account: account,
            ),
          ),
        ),
      );

      // Pump to settle the FutureBuilder
      await tester.pumpAndSettle();

      // Verify AppBar
      expect(find.text('Margin Health & Collateral'), findsOneWidget);

      // Verify Margin Health Hero
      expect(find.text('Margin Health'), findsOneWidget);
      expect(find.text('Healthy'), findsOneWidget);
      expect(find.text('buffer distance'), findsOneWidget);

      // Verify Buying Power Breakdown
      expect(find.text('True Buying Power Breakdown'), findsOneWidget);
      expect(find.text('Total Buying Power'), findsOneWidget);
      expect(find.text('Options Buying Power'), findsOneWidget);
      expect(find.text('Crypto Buying Power'), findsOneWidget);
      expect(find.text('Withdrawable Cash'), findsOneWidget);

      // Verify Collateral & Order Holds
      expect(find.text('Collateral & Order Holds'), findsOneWidget);
      expect(find.text('Cash Held for Options'), findsOneWidget);
      expect(find.text('Equity Held for Options'), findsOneWidget);

      // Verify Margin Leverage & Requirements
      expect(find.text('Margin Leverage & Requirements'), findsOneWidget);
      expect(find.text('Settled Amount Borrowed'), findsOneWidget);
      expect(find.text('Maintenance Requirement'), findsOneWidget);
      expect(find.text('Account Leverage Ratio'), findsOneWidget);

      // Verify Educational Tile
      expect(
        find.text('Understanding Margin Health & FINRA Rules'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'MarginHealthWidget renders real Robinhood phoenix accounts unified payload',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final account = Account(
        'https://api.robinhood.com/accounts/101241412/',
        50945.02,
        '101241412',
        'margin',
        53408.51,
        'level_3',
        5336.71,
        0.0,
        0.0,
      );

      final brokerageUser = BrokerageUser(
        BrokerageSource.robinhood,
        'robinhood_user',
        null,
        null,
        accounts: [account],
      );

      final mockService = _MockRealPhoenixService();

      await tester.pumpWidget(
        MaterialApp(
          home: MarginHealthWidget(
            brokerageUser: brokerageUser,
            service: mockService,
            account: account,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify status and buffer distance from margin_buffer_amount ($51,915.16)
      expect(find.text('Healthy'), findsOneWidget);
      expect(find.text('\$51,915.16'), findsOneWidget);
      expect(find.text('buffer distance'), findsOneWidget);

      // Verify Buying Powers
      expect(find.text('\$53,408.51'), findsOneWidget); // Total buying power
      expect(find.text('\$26,704.26'), findsNWidgets(2)); // Options & Crypto BP
      expect(find.text('\$5,336.71'), findsOneWidget); // Withdrawable cash

      // Verify Margin requirements
      expect(
        find.text('\$17,617.02'),
        findsOneWidget,
      ); // Maintenance requirement
      expect(find.text('\$55,684.81'), findsOneWidget); // Portfolio equity
      expect(
        find.text('\$49,807.62'),
        findsOneWidget,
      ); // Borrowing limit (total_margin)
    },
  );
}

class _MockRealPhoenixService extends DemoService {
  @override
  Future<dynamic> getUnifiedAccount(BrokerageUser user) async {
    return {
      "account_buying_power": {
        "amount": "53408.5104",
        "currency_code": "USD",
        "currency_id": "1072fc76-1862-41ab-82c2-485837590762",
      },
      "cash_available_from_instant_deposits": {
        "amount": "0",
        "currency_code": "USD",
        "currency_id": "1072fc76-1862-41ab-82c2-485837590762",
      },
      "cash_held_for_currency_orders": {
        "amount": "0",
        "currency_code": "USD",
        "currency_id": "1072fc76-1862-41ab-82c2-485837590762",
      },
      "cash_held_for_dividends": {
        "amount": "0",
        "currency_code": "USD",
        "currency_id": "1072fc76-1862-41ab-82c2-485837590762",
      },
      "cash_held_for_equity_orders": {
        "amount": "0",
        "currency_code": "USD",
        "currency_id": "1072fc76-1862-41ab-82c2-485837590762",
      },
      "cash_held_for_options_collateral": {
        "amount": "0",
        "currency_code": "USD",
        "currency_id": "1072fc76-1862-41ab-82c2-485837590762",
      },
      "cash_held_for_orders": {
        "amount": "0",
        "currency_code": "USD",
        "currency_id": "1072fc76-1862-41ab-82c2-485837590762",
      },
      "cash_held_for_restrictions": {
        "amount": "0",
        "currency_code": "USD",
        "currency_id": "1072fc76-1862-41ab-82c2-485837590762",
      },
      "crypto": {
        "equity": {
          "amount": "4739.78",
          "currency_code": "USD",
          "currency_id": "1072fc76-1862-41ab-82c2-485837590762",
        },
        "market_value": {
          "amount": "4739.78",
          "currency_code": "USD",
          "currency_id": "1072fc76-1862-41ab-82c2-485837590762",
        },
        "opened_at": "2018-12-07T01:25:13.512301Z",
      },
      "crypto_buying_power": {
        "amount": "26704.2552",
        "currency_code": "USD",
        "currency_id": "1072fc76-1862-41ab-82c2-485837590762",
      },
      "equities": {
        "active_subscription_id": "ed9af327-ff97-56af-8172-0731f1afc505",
        "apex_account_number": "5QR24141",
        "available_margin": null,
        "equity": {
          "amount": "50945.027189",
          "currency_code": "USD",
          "currency_id": "1072fc76-1862-41ab-82c2-485837590762",
        },
        "margin_maintenance": {
          "amount": "17617.024289",
          "currency_code": "USD",
          "currency_id": "1072fc76-1862-41ab-82c2-485837590762",
        },
        "market_value": {
          "amount": "43870.977189",
          "currency_code": "USD",
          "currency_id": "1072fc76-1862-41ab-82c2-485837590762",
        },
        "opened_at": "2015-02-12T22:41:50.744964Z",
        "rhs_account_number": "101241412",
        "total_margin": {
          "amount": "49807.6204",
          "currency_code": "USD",
          "currency_id": "1072fc76-1862-41ab-82c2-485837590762",
        },
      },
      "extended_hours_portfolio_equity": {
        "amount": "55684.807189",
        "currency_code": "USD",
        "currency_id": "1072fc76-1862-41ab-82c2-485837590762",
      },
      "instant_allocated": {
        "amount": "0",
        "currency_code": "USD",
        "currency_id": "1072fc76-1862-41ab-82c2-485837590762",
      },
      "levered_amount": {
        "amount": "0",
        "currency_code": "USD",
        "currency_id": "1072fc76-1862-41ab-82c2-485837590762",
      },
      "near_margin_call": false,
      "options_buying_power": {
        "amount": "26704.2552",
        "currency_code": "USD",
        "currency_id": "1072fc76-1862-41ab-82c2-485837590762",
      },
      "portfolio_equity": {
        "amount": "55684.807189",
        "currency_code": "USD",
        "currency_id": "1072fc76-1862-41ab-82c2-485837590762",
      },
      "portfolio_previous_close": {
        "amount": "55151.864035",
        "currency_code": "USD",
        "currency_id": "1072fc76-1862-41ab-82c2-485837590762",
      },
      "previous_close": {
        "amount": "55151.864035",
        "currency_code": "USD",
        "currency_id": "1072fc76-1862-41ab-82c2-485837590762",
      },
      "regular_hours_portfolio_equity": {
        "amount": "55570.113449",
        "currency_code": "USD",
        "currency_id": "1072fc76-1862-41ab-82c2-485837590762",
      },
      "total_equity": {
        "amount": "55684.807189",
        "currency_code": "USD",
        "currency_id": "1072fc76-1862-41ab-82c2-485837590762",
      },
      "total_extended_hours_equity": {
        "amount": "55684.807189",
        "currency_code": "USD",
        "currency_id": "1072fc76-1862-41ab-82c2-485837590762",
      },
      "total_extended_hours_market_value": {
        "amount": "48610.757189",
        "currency_code": "USD",
        "currency_id": "1072fc76-1862-41ab-82c2-485837590762",
      },
      "total_market_value": {
        "amount": "48610.757189",
        "currency_code": "USD",
        "currency_id": "1072fc76-1862-41ab-82c2-485837590762",
      },
      "total_regular_hours_equity": {
        "amount": "55570.113449",
        "currency_code": "USD",
        "currency_id": "1072fc76-1862-41ab-82c2-485837590762",
      },
      "total_regular_hours_market_value": {
        "amount": "48638.313449",
        "currency_code": "USD",
        "currency_id": "1072fc76-1862-41ab-82c2-485837590762",
      },
      "uninvested_cash": {
        "amount": "7074.05",
        "currency_code": "USD",
        "currency_id": "1072fc76-1862-41ab-82c2-485837590762",
      },
      "withdrawable_cash": {
        "amount": "5336.7128",
        "currency_code": "USD",
        "currency_id": "1072fc76-1862-41ab-82c2-485837590762",
      },
      "margin_health": {
        "margin_health_state": "healthy",
        "margin_buffer": "1.0000",
        "margin_buffer_amount": {
          "amount": "51915.157189",
          "currency_code": "USD",
          "currency_id": "1072fc76-1862-41ab-82c2-485837590762",
        },
      },
      "buying_power_display_currency": null,
    };
  }
}
