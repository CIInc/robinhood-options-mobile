import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';
import 'package:robinhood_options_mobile/widgets/option_collateral_widget.dart';

void main() {
  final testUser = BrokerageUser(
    BrokerageSource.demo,
    'test_trader',
    null,
    null,
  );

  final testAccountL2 = Account(
    'https://api.robinhood.com/accounts/ACCT123/',
    15420.50,
    'ACCT123',
    'margin',
    25000.0,
    'option_level_2',
    3250.0,
    0.0,
    0.0,
  );

  final testAccountL3 = Account(
    'https://api.robinhood.com/accounts/ACCT789/',
    54200.00,
    'ACCT789',
    'margin',
    85000.0,
    'option_level_3',
    0.0,
    0.0,
    0.0,
  );

  testWidgets('OptionCollateralWidget renders collateral tab with metrics',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final demoService = DemoService();

    await tester.pumpWidget(
      MaterialApp(
        home: OptionCollateralWidget(
          brokerageUser: testUser,
          service: demoService,
          account: testAccountL2,
          chainId: 'chain_goog',
          symbol: 'GOOG',
        ),
      ),
    );

    // Initial loading indicator
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Pump until async data completes
    await tester.pumpAndSettle();

    // Verify AppBar header
    expect(find.text('Options Collateral & Tiers'), findsOneWidget);
    expect(find.textContaining('GOOG Options Chain'), findsOneWidget);

    // Verify TabBar
    expect(find.text('Chain Collateral'), findsOneWidget);
    expect(find.text('Tier Upgrades'), findsOneWidget);

    // Verify Collateral Summary Card
    expect(find.text('Total Locked Collateral'), findsOneWidget);
    expect(find.textContaining('\$3,900.00'), findsOneWidget);
    expect(find.text('100 shares'), findsWidgets);

    // Verify Breakdown Sections
    expect(find.text('Active Positions Collateral'), findsOneWidget);
    expect(find.text('Pending Orders Collateral'), findsOneWidget);
    expect(find.text('Equities Collateral (Covered Contracts)'), findsWidgets);

    // Verify Collateral Rules Reference Card
    expect(find.text('Collateral Rules Reference'), findsOneWidget);
    expect(find.text('Cash-Secured Puts'), findsOneWidget);
    expect(find.text('Covered Calls'), findsOneWidget);
    expect(find.text('Credit Spreads (Level 3)'), findsOneWidget);
  });

  testWidgets('OptionCollateralWidget switches to Tier Upgrades tab',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final demoService = DemoService();

    await tester.pumpWidget(
      MaterialApp(
        home: OptionCollateralWidget(
          brokerageUser: testUser,
          service: demoService,
          account: testAccountL2,
          chainId: 'chain_goog',
          symbol: 'GOOG',
          initialTabIndex: 1, // Start on Upgrades tab
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Upgrade tab content
    expect(find.text('Current Tier: Level 2'), findsOneWidget);
    expect(find.text('Upgrade to Options Level 3'), findsOneWidget);
    expect(find.text('Options Trading Capabilities'), findsOneWidget);
    expect(find.text('Level 2: Basic Options'), findsOneWidget);
    expect(find.text('Level 3: Multi-Leg & Spreads'), findsOneWidget);
    expect(find.text('Eligibility & Requirements'), findsOneWidget);

    // Verify Action button exists and is tappable
    final buttonFinder = find.text('Apply for Level 3 Upgrade');
    expect(buttonFinder, findsOneWidget);
    await tester.tap(buttonFinder);
    await tester.pumpAndSettle();
  });

  testWidgets('OptionCollateralWidget renders approved state for Level 3 account',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final demoService = DemoService();

    await tester.pumpWidget(
      MaterialApp(
        home: OptionCollateralWidget(
          brokerageUser: testUser,
          service: demoService,
          account: testAccountL3,
          chainId: 'chain_spy',
          symbol: 'SPY',
          initialTabIndex: 1,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify L3 badge and approval banner
    expect(find.text('Account Approved for Level 3 Options'), findsOneWidget);
  });

  testWidgets(
      'OptionCollateralWidget handles Robinhood zero collateral response with 0E-8 gracefully',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final service = _ZeroCollateralMockService();

    await tester.pumpWidget(
      MaterialApp(
        home: OptionCollateralWidget(
          brokerageUser: testUser,
          service: service,
          account: testAccountL2,
          chainId: 'chain_amzn',
          symbol: 'AMZN',
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify header account number from payload
    expect(find.textContaining('5QR24141'), findsOneWidget);

    // Verify $0.00 total locked and category cash metrics
    expect(find.text('\$0.00'), findsWidgets);

    // Verify that empty 0E-8 AMZN equities are filtered out and not rendered as active tiles
    expect(find.text('Equities Collateral (Covered Contracts)'), findsNothing);
    expect(find.text('0 shares'), findsNothing);

    // Both active positions and pending orders should display no collateral held
    expect(find.text('No collateral currently held in this category.'),
        findsNWidgets(2));
  });
}

class _ZeroCollateralMockService extends DemoService {
  @override
  Future<dynamic> getOptionChainCollateral(
      BrokerageUser user, String chainId, String accountNumber) async {
    return {
      "account_number": "5QR24141",
      "collateral": {
        "cash": {"amount": "0.0000", "direction": "debit", "infinite": false},
        "equities": [
          {
            "quantity": "0E-8",
            "direction": "debit",
            "uncovered_shares": "0E-8",
            "instrument":
                "https://api.robinhood.com/instruments/c0bb3aec-bd1e-471e-a4f0-ca011cbec711/",
            "symbol": "AMZN"
          }
        ]
      },
      "collateral_held_for_orders": {
        "cash": {"amount": "0.0000", "direction": "debit", "infinite": false},
        "equities": [
          {
            "quantity": "0E-8",
            "direction": "debit",
            "uncovered_shares": "0E-8",
            "instrument":
                "https://api.robinhood.com/instruments/c0bb3aec-bd1e-471e-a4f0-ca011cbec711/",
            "symbol": "AMZN"
          }
        ]
      }
    };
  }
}
