import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_provider.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/futures_auto_trading_provider.dart';
import 'package:robinhood_options_mobile/model/portfolio_alert.dart';
import 'package:robinhood_options_mobile/model/portfolio_analytics_controller.dart';
import 'package:robinhood_options_mobile/model/wash_sale_record.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/services/portfolio_alert_service.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/portfolio_navigator.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/portfolio_section.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/portfolio_section_context.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/portfolio_section_grid_widget.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/strategies_section_page.dart';

import 'firebase_mocks.dart';
import 'portfolio_alert_service_test.dart' show buildPosition;

class FakeBrokerageService extends Fake implements IBrokerageService {}

class FakeGenerativeService extends Fake implements GenerativeService {}

class FakeObserver extends Fake implements FirebaseAnalyticsObserver {}

void main() {
  setUpAll(() async {
    await setupFirebaseMocks();
  });
  group('Browse Features for Paper Trading', () {
    testWidgets('PortfolioSectionGridWidget disables Taxes for paper trading',
        (tester) async {
      PortfolioSection? tapped;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PortfolioSectionGridWidget(
                onSectionTap: (section) => tapped = section,
                disabled: const {PortfolioSection.taxes},
                disabledReasons: const {
                  PortfolioSection.taxes: 'Not applicable to paper trading',
                },
              ),
            ),
          ),
        ),
      );

      // Verify Taxes tile has disabled label and block icon
      expect(find.text('Taxes'), findsOneWidget);
      expect(find.text('Not applicable to paper trading'), findsOneWidget);
      expect(find.byIcon(Icons.block), findsOneWidget);

      // Tapping Taxes should NOT trigger onSectionTap and should show SnackBar
      await tester.tap(find.text('Taxes'));
      await tester.pump();

      expect(tapped, isNull);
      expect(find.text('Not applicable to paper trading'), findsWidgets);
    });

    testWidgets('PortfolioNavigator guards Taxes for paper trading user',
        (tester) async {
      final paperUser = BrokerageUser(
        BrokerageSource.paper,
        'paper_user',
        null,
        null,
      );
      final paperAccount = Account(
        'paper_account',
        100000,
        'paper_account',
        'Paper Account',
        100000,
        '3',
        0,
        0,
        0,
      );

      final controller = PortfolioAnalyticsController();
      final sectionContext = PortfolioSectionContext(
        brokerageUser: paperUser,
        service: FakeBrokerageService(),
        analytics: FakeFirebaseAnalytics(),
        observer: FakeObserver(),
        generativeService: FakeGenerativeService(),
        appUser: null,
        userDocRef: null,
        analyticsController: controller,
        account: paperAccount,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => PortfolioNavigator.openSection(
                  context,
                  PortfolioSection.taxes,
                  sectionContext,
                ),
                child: const Text('Open Taxes'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Taxes'));
      await tester.pump();

      // Should show SnackBar and NOT open TaxOptimizationWidget
      expect(
        find.text('Tax optimization does not apply to paper trading accounts.'),
        findsOneWidget,
      );
    });

    testWidgets(
        'StrategiesSectionPage disables Paper Trading Simulator and Auto-Trading cards in paper mode',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final paperUser = BrokerageUser(
        BrokerageSource.paper,
        'paper_user',
        null,
        null,
      );
      final paperAccount = Account(
        'paper_account',
        100000,
        'paper_account',
        'Paper Account',
        100000,
        '3',
        0,
        0,
        0,
      );

      final controller = PortfolioAnalyticsController();
      final sectionContext = PortfolioSectionContext(
        brokerageUser: paperUser,
        service: FakeBrokerageService(),
        analytics: FakeFirebaseAnalytics(),
        observer: FakeObserver(),
        generativeService: FakeGenerativeService(),
        appUser: null,
        userDocRef: null,
        analyticsController: controller,
        account: paperAccount,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
                create: (_) => AgenticTradingProvider(
                    analytics: FakeFirebaseAnalytics())),
            ChangeNotifierProvider(
                create: (_) => FuturesAutoTradingProvider(
                    analytics: FakeFirebaseAnalytics())),
          ],
          child: MaterialApp(
            home: StrategiesSectionPage(
              sectionContext: sectionContext,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check Paper Trading Simulator
      expect(find.text('Paper Trading Simulator'), findsOneWidget);
      expect(
        find.text('Already active (currently in paper trading mode)'),
        findsOneWidget,
      );

      // Check Stocks Auto-Trading
      expect(find.text('Stocks Auto-Trading'), findsOneWidget);
      // Check Futures Auto-Trading
      expect(find.text('Futures Auto-Trading'), findsOneWidget);
      // Both auto trading cards show 'Not applicable to paper trading'
      expect(find.text('Not applicable to paper trading'), findsNWidgets(2));

      // 3 block icons (Stocks Auto-Trading, Futures Auto-Trading, Paper Trading Simulator)
      // Note: Stocks Auto-Trading also has Backtesting button with Icons.block when disabled
      expect(find.byIcon(Icons.block), findsWidgets);

      // Tap Stocks Auto-Trading and verify SnackBar
      await tester.tap(find.text('Stocks Auto-Trading'));
      await tester.pump();
      expect(find.text('Not applicable to paper trading'), findsWidgets);

      // Dismiss SnackBar
      ScaffoldMessenger.of(tester.element(find.text('Stocks Auto-Trading')))
          .hideCurrentSnackBar();
      await tester.pump();

      // Tap Futures Auto-Trading and verify SnackBar
      await tester.tap(find.text('Futures Auto-Trading'));
      await tester.pump();
      expect(find.text('Not applicable to paper trading'), findsWidgets);

      // Dismiss SnackBar
      ScaffoldMessenger.of(tester.element(find.text('Futures Auto-Trading')))
          .hideCurrentSnackBar();
      await tester.pump();

      // Tap Paper Trading Simulator and verify SnackBar
      await tester.tap(find.text('Paper Trading Simulator'));
      await tester.pump();

      expect(
        find.text('Paper trading simulator is already active'),
        findsOneWidget,
      );
    });

    test('PortfolioAlertService skips tax alerts for paper accounts', () {
      final paperAccount = Account(
        'paper_account',
        100000,
        'paper_account',
        'Paper Account',
        100000,
        '3',
        0,
        0,
        0,
      );

      final lossPosition = buildPosition(
        symbol: 'TSLA',
        price: 150,
        costBasis: 250,
        quantity: 100,
      );

      final washSale = WashSaleRecord(
        id: 'wash_1',
        symbol: 'TSLA',
        name: 'Tesla, Inc.',
        assetType: 'stock',
        saleDate: DateTime.now().subtract(const Duration(days: 5)),
        salePrice: 150.0,
        quantitySold: 10.0,
        realizedLoss: -500.0,
        disallowedLoss: 500.0,
        windowStartDate: DateTime.now().subtract(const Duration(days: 35)),
        windowEndDate: DateTime.now().add(const Duration(days: 25)),
        status: WashSaleStatus.disallowed,
      );

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: [lossPosition],
        optionPositions: const [],
        account: paperAccount,
        totalEquity: 15000,
        washSales: [washSale],
      );

      // Verify no tax alerts were produced
      expect(
        alerts.where((a) => a.target == PortfolioAlertTarget.taxes),
        isEmpty,
      );
    });
  });
}
