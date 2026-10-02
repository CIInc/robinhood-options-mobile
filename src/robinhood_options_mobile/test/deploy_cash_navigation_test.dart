import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/portfolio_alert.dart';
import 'package:robinhood_options_mobile/model/portfolio_analytics_controller.dart';
import 'package:robinhood_options_mobile/services/portfolio_alert_service.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/portfolio_navigator.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/portfolio_section_context.dart';
import 'package:robinhood_options_mobile/widgets/tab_navigation.dart';

import 'firebase_mocks.dart';
import 'portfolio_alert_service_test.dart' show buildAccount;
import 'portfolio_browse_paper_trading_test.dart'
    show FakeBrokerageService, FakeGenerativeService, FakeObserver;

void main() {
  setUpAll(() async {
    await setupFirebaseMocks();
  });

  group('Deploy Cash Navigation', () {
    test('PortfolioAlertService generates search target for high cash alert', () {
      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: const [],
        optionPositions: const [],
        account: buildAccount(cash: 8000, buyingPower: 8000),
        totalEquity: 10000,
      );

      final cashAlert = alerts.firstWhere((a) => a.id == 'high-cash');
      expect(cashAlert.actionLabel, 'Deploy Cash');
      expect(cashAlert.target, PortfolioAlertTarget.search);
    });

    testWidgets('PortfolioNavigator.openAlert with onTabChanged switches to Search tab (index 2)', (tester) async {
      int? switchedTabIndex;

      final sectionContext = PortfolioSectionContext(
        brokerageUser: BrokerageUser(
          BrokerageSource.demo,
          'demo_user',
          null,
          null,
        ),
        service: FakeBrokerageService(),
        analytics: FakeFirebaseAnalytics(),
        observer: FakeObserver(),
        generativeService: FakeGenerativeService(),
        appUser: null,
        userDocRef: null,
        analyticsController: PortfolioAnalyticsController(),
        onTabChanged: (index) {
          switchedTabIndex = index;
        },
      );

      final alert = PortfolioAlert(
        id: 'high-cash',
        severity: PortfolioAlertSeverity.info,
        icon: Icons.account_balance_wallet_outlined,
        title: '80% of assets in cash',
        detail: 'Uninvested cash is not tracking the market.',
        target: PortfolioAlertTarget.search,
        actionLabel: 'Deploy Cash',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => PortfolioNavigator.openAlert(
                  context,
                  alert,
                  sectionContext,
                ),
                child: const Text('Deploy Cash'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Deploy Cash'));
      await tester.pumpAndSettle();

      expect(switchedTabIndex, 2);
    });

    testWidgets('PortfolioNavigator.openAlert with TabNavigation switches to Search tab (index 2)', (tester) async {
      int? switchedTabIndex;

      final sectionContext = PortfolioSectionContext(
        brokerageUser: BrokerageUser(
          BrokerageSource.demo,
          'demo_user',
          null,
          null,
        ),
        service: FakeBrokerageService(),
        analytics: FakeFirebaseAnalytics(),
        observer: FakeObserver(),
        generativeService: FakeGenerativeService(),
        appUser: null,
        userDocRef: null,
        analyticsController: PortfolioAnalyticsController(),
      );

      final alert = PortfolioAlert(
        id: 'high-cash',
        severity: PortfolioAlertSeverity.info,
        icon: Icons.account_balance_wallet_outlined,
        title: '80% of assets in cash',
        detail: 'Uninvested cash is not tracking the market.',
        target: PortfolioAlertTarget.search,
        actionLabel: 'Deploy Cash',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: TabNavigation(
            onPageChanged: (index) {
              switchedTabIndex = index;
            },
            child: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => PortfolioNavigator.openAlert(
                    context,
                    alert,
                    sectionContext,
                  ),
                  child: const Text('Deploy Cash'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Deploy Cash'));
      await tester.pumpAndSettle();

      expect(switchedTabIndex, 2);
    });
  });
}
