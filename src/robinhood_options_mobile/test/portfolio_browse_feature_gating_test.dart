import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/main.dart' as app_main;
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/portfolio_analytics_controller.dart';
import 'package:robinhood_options_mobile/services/feature_access_service.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/services/remote_config_service.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/portfolio_navigator.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/portfolio_section.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/portfolio_section_context.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/portfolio_section_grid_widget.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/chart_selection_store.dart';
import 'package:robinhood_options_mobile/model/dividend_store.dart';
import 'package:robinhood_options_mobile/model/forex_holding_store.dart';
import 'package:robinhood_options_mobile/model/futures_position_store.dart';
import 'package:robinhood_options_mobile/model/instrument_order_store.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/interest_store.dart';
import 'package:robinhood_options_mobile/model/option_position_store.dart';
import 'package:robinhood_options_mobile/model/portfolio_alert.dart';
import 'package:robinhood_options_mobile/services/portfolio_alert_service.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/agentic_risk_copilot_card.dart';
import 'package:robinhood_options_mobile/widgets/income_transactions_widget.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/performance_section_page.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/risk_section_page.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/portfolio_store.dart';
import 'package:robinhood_options_mobile/widgets/correlation_matrix_widget.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/analytics/risk_analytics_card.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/analytics/rolling_statistics_dashboard.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/portfolio_greeks_card.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/portfolio_risk_summary_widget.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/portfolio_stress_test_card.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/tail_risk_card.dart';
import 'package:robinhood_options_mobile/widgets/risk_heatmap_widget.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/portfolio_movers_widget.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/action_center_widget.dart';
import 'portfolio_alert_service_test.dart'
    show buildPosition, buildOptionPosition;

import 'firebase_mocks.dart';

class FakeBrokerageService extends Fake implements IBrokerageService {}

class FakeGenerativeService extends Fake implements GenerativeService {}

class FakeObserver extends Fake implements FirebaseAnalyticsObserver {}

void main() {
  setUpAll(() async {
    await setupFirebaseMocks();
  });

  group('Portfolio Browse Feature Gating Tests', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      FeatureAccessService.mockInstance = FeatureAccessService(
        prefs: prefs,
        remoteConfig: RemoteConfigService.instance,
      );
      app_main.userRole = UserRole.user;
    });

    testWidgets('PortfolioSectionGridWidget renders only provided sections',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PortfolioSectionGridWidget(
                onSectionTap: (_) {},
                sections: const [
                  PortfolioSection.performance,
                  PortfolioSection.risk,
                ],
              ),
            ),
          ),
        ),
      );

      // Core sections are visible
      expect(find.text('Performance'), findsOneWidget);
      expect(find.text('Risk'), findsOneWidget);

      // Disabled/removed sections (including Positions) are completely absent from the card grid
      expect(find.text('Positions'), findsNothing);
      expect(find.text('Strategies'), findsNothing);
      expect(find.text('Insights'), findsNothing);
      expect(find.text('Taxes'), findsNothing);
    });

    testWidgets(
        'PortfolioNavigator blocks Strategies when disabled and shows snackbar',
        (WidgetTester tester) async {
      // Ensure automated trading and advanced research are disabled
      FeatureAccessService.instance.overrideRolloutForTesting(
        FeatureBundle.automatedTrading,
        FeatureRolloutMode.disabled,
      );
      FeatureAccessService.instance.overrideRolloutForTesting(
        FeatureBundle.advancedResearch,
        FeatureRolloutMode.disabled,
      );

      final dummyUser = BrokerageUser(
        BrokerageSource.robinhood,
        'test_user',
        null,
        null,
      );
      final sectionContext = PortfolioSectionContext(
        brokerageUser: dummyUser,
        service: FakeBrokerageService(),
        analytics: FakeFirebaseAnalytics(),
        observer: FakeObserver(),
        generativeService: FakeGenerativeService(),
        appUser: null,
        userDocRef: null,
        analyticsController: PortfolioAnalyticsController(),
        account: Account('123', 1000, '123', 'Account', 1000, '3', 0, 0, 0),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => PortfolioNavigator.openSection(
                  context,
                  PortfolioSection.strategies,
                  sectionContext,
                ),
                child: const Text('Open Strategies'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Strategies'));
      await tester.pump();

      expect(find.text('Strategy features are not currently enabled.'),
          findsOneWidget);
    });

    testWidgets(
        'PortfolioNavigator blocks Insights when disabled and shows snackbar',
        (WidgetTester tester) async {
      FeatureAccessService.instance.overrideRolloutForTesting(
        FeatureBundle.aiResearch,
        FeatureRolloutMode.disabled,
      );

      final dummyUser = BrokerageUser(
        BrokerageSource.robinhood,
        'test_user',
        null,
        null,
      );
      final sectionContext = PortfolioSectionContext(
        brokerageUser: dummyUser,
        service: FakeBrokerageService(),
        analytics: FakeFirebaseAnalytics(),
        observer: FakeObserver(),
        generativeService: FakeGenerativeService(),
        appUser: null,
        userDocRef: null,
        analyticsController: PortfolioAnalyticsController(),
        account: Account('123', 1000, '123', 'Account', 1000, '3', 0, 0, 0),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => PortfolioNavigator.openSection(
                  context,
                  PortfolioSection.insights,
                  sectionContext,
                ),
                child: const Text('Open Insights'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Insights'));
      await tester.pump();

      expect(find.text('AI Insights features are not currently enabled.'),
          findsOneWidget);
    });

    testWidgets('PortfolioNavigator blocks Taxes when accountTools is disabled',
        (WidgetTester tester) async {
      FeatureAccessService.instance.overrideRolloutForTesting(
        FeatureBundle.accountTools,
        FeatureRolloutMode.disabled,
      );

      final dummyUser = BrokerageUser(
        BrokerageSource.robinhood,
        'test_user',
        null,
        null,
      );
      final sectionContext = PortfolioSectionContext(
        brokerageUser: dummyUser,
        service: FakeBrokerageService(),
        analytics: FakeFirebaseAnalytics(),
        observer: FakeObserver(),
        generativeService: FakeGenerativeService(),
        appUser: null,
        userDocRef: null,
        analyticsController: PortfolioAnalyticsController(),
        account: Account('123', 1000, '123', 'Account', 1000, '3', 0, 0, 0),
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

      expect(find.text('Tax optimization tools are not currently enabled.'),
          findsOneWidget);
    });

    group('Action Center Alert Feature Gating', () {
      PortfolioAlert makeAlert({
        required String id,
        required PortfolioAlertTarget target,
        String category = 'Test',
        String actionLabel = 'Action',
      }) {
        return PortfolioAlert(
          id: id,
          severity: PortfolioAlertSeverity.warning,
          icon: Icons.info,
          title: 'Alert $id',
          detail: 'Detail for $id',
          metric: '10%',
          target: target,
          category: category,
          actionLabel: actionLabel,
        );
      }

      test(
          'filters taxes and rebalance alerts based on accountTools and paper status',
          () {
        final taxAlert =
            makeAlert(id: 'tax-loss', target: PortfolioAlertTarget.taxes);
        final rebalanceAlert = makeAlert(
            id: 'rebalance-needed', target: PortfolioAlertTarget.rebalance);

        // When accountTools is disabled
        FeatureAccessService.instance.overrideRolloutForTesting(
          FeatureBundle.accountTools,
          FeatureRolloutMode.disabled,
        );
        var filtered = PortfolioAlertService.filterAlertsByFeatureAccess(
          [taxAlert, rebalanceAlert],
          userRole: UserRole.user,
          isPaper: false,
        );
        expect(filtered, isEmpty);

        // When accountTools is enabled but isPaper is true
        FeatureAccessService.instance.overrideRolloutForTesting(
          FeatureBundle.accountTools,
          FeatureRolloutMode.public,
        );
        filtered = PortfolioAlertService.filterAlertsByFeatureAccess(
          [taxAlert, rebalanceAlert],
          userRole: UserRole.user,
          isPaper: true,
        );
        // Taxes excluded for paper, rebalance kept
        expect(filtered.map((a) => a.id), contains('rebalance-needed'));
        expect(filtered.map((a) => a.id), isNot(contains('tax-loss')));

        // When accountTools is enabled and not paper
        filtered = PortfolioAlertService.filterAlertsByFeatureAccess(
          [taxAlert, rebalanceAlert],
          userRole: UserRole.user,
          isPaper: false,
        );
        expect(filtered.length, 2);
      });

      test(
          'filters research alerts based on advancedResearch and advancedTrading',
          () {
        final zeroDteAlert = makeAlert(
            id: '0dte-radar', target: PortfolioAlertTarget.zeroDteRadar);
        final ivCrushAlert = makeAlert(
            id: 'earnings-crush', target: PortfolioAlertTarget.earningsIvCrush);
        final coneAlert = makeAlert(
            id: 'vol-cone', target: PortfolioAlertTarget.volatilityCone);
        final surfaceAlert =
            makeAlert(id: 'iv-surface', target: PortfolioAlertTarget.ivSurface);
        final congressAlert = makeAlert(
            id: 'congress-trade',
            target: PortfolioAlertTarget.congressionalTrading);
        final deltaAlert = makeAlert(
            id: 'delta-neutral', target: PortfolioAlertTarget.deltaNeutral);

        // All research & trading disabled
        FeatureAccessService.instance.overrideRolloutForTesting(
          FeatureBundle.advancedResearch,
          FeatureRolloutMode.disabled,
        );
        FeatureAccessService.instance.overrideRolloutForTesting(
          FeatureBundle.advancedTrading,
          FeatureRolloutMode.disabled,
        );

        var filtered = PortfolioAlertService.filterAlertsByFeatureAccess(
          [
            zeroDteAlert,
            ivCrushAlert,
            coneAlert,
            surfaceAlert,
            congressAlert,
            deltaAlert
          ],
          userRole: UserRole.user,
        );
        expect(filtered, isEmpty);

        // Enable advancedTrading only
        FeatureAccessService.instance.overrideRolloutForTesting(
          FeatureBundle.advancedTrading,
          FeatureRolloutMode.public,
        );
        filtered = PortfolioAlertService.filterAlertsByFeatureAccess(
          [zeroDteAlert, deltaAlert],
          userRole: UserRole.user,
        );
        expect(filtered.map((a) => a.id), ['delta-neutral']);

        // Enable advancedResearch
        FeatureAccessService.instance.overrideRolloutForTesting(
          FeatureBundle.advancedResearch,
          FeatureRolloutMode.public,
        );
        filtered = PortfolioAlertService.filterAlertsByFeatureAccess(
          [zeroDteAlert, ivCrushAlert, coneAlert, surfaceAlert, congressAlert],
          userRole: UserRole.user,
        );
        expect(filtered.length, 5);
      });

      test('filters risk guardrails alerts and copilot based on feature flags',
          () {
        final breakerAlert = makeAlert(
            id: 'risk-circuit-breaker-drawdown',
            target: PortfolioAlertTarget.risk);
        final tiltAlert = makeAlert(
            id: 'risk-tilt-warning', target: PortfolioAlertTarget.risk);
        final copilotAlert = makeAlert(
            id: 'copilot-warning', target: PortfolioAlertTarget.riskCopilot);
        final newsAlert = makeAlert(
            id: 'news-intel', target: PortfolioAlertTarget.newsIntelligence);

        FeatureAccessService.instance.overrideRolloutForTesting(
          FeatureBundle.riskGuardrails,
          FeatureRolloutMode.disabled,
        );
        FeatureAccessService.instance.overrideRolloutForTesting(
          FeatureBundle.aiResearch,
          FeatureRolloutMode.disabled,
        );

        var filtered = PortfolioAlertService.filterAlertsByFeatureAccess(
          [breakerAlert, tiltAlert, copilotAlert, newsAlert],
          userRole: UserRole.user,
        );
        expect(filtered, isEmpty);

        // Enable riskGuardrails
        FeatureAccessService.instance.overrideRolloutForTesting(
          FeatureBundle.riskGuardrails,
          FeatureRolloutMode.public,
        );
        filtered = PortfolioAlertService.filterAlertsByFeatureAccess(
          [breakerAlert, tiltAlert, copilotAlert],
          userRole: UserRole.user,
        );
        // copilot still disabled because aiResearch is disabled
        expect(filtered.map((a) => a.id),
            ['risk-circuit-breaker-drawdown', 'risk-tilt-warning']);

        // Enable aiResearch
        FeatureAccessService.instance.overrideRolloutForTesting(
          FeatureBundle.aiResearch,
          FeatureRolloutMode.public,
        );
        filtered = PortfolioAlertService.filterAlertsByFeatureAccess(
          [copilotAlert, newsAlert],
          userRole: UserRole.user,
        );
        expect(filtered.length, 2);
      });

      test(
          'falls back short expiration alert from strategies to optionPositions when strategies disabled',
          () {
        final expAlert = makeAlert(
          id: 'short-option-expiring-spy',
          target: PortfolioAlertTarget.strategies,
          actionLabel: 'Adjust Strategy',
        );

        // Strategies disabled
        FeatureAccessService.instance.overrideRolloutForTesting(
          FeatureBundle.automatedTrading,
          FeatureRolloutMode.disabled,
        );
        FeatureAccessService.instance.overrideRolloutForTesting(
          FeatureBundle.advancedResearch,
          FeatureRolloutMode.disabled,
        );

        final filtered = PortfolioAlertService.filterAlertsByFeatureAccess(
          [expAlert],
          userRole: UserRole.user,
        );
        expect(filtered.length, 1);
        expect(filtered.first.target, PortfolioAlertTarget.optionPositions);
        expect(filtered.first.actionLabel, 'View Options');
      });
    });

    group('Sub-page Browse Feature Gating Tests', () {
      PortfolioSectionContext createTestContext() {
        return PortfolioSectionContext(
          brokerageUser:
              BrokerageUser(BrokerageSource.robinhood, 'test_user', null, null),
          service: FakeBrokerageService(),
          analytics: FakeFirebaseAnalytics(),
          observer: FakeObserver(),
          generativeService: FakeGenerativeService(),
          appUser: null,
          userDocRef: null,
          analyticsController: PortfolioAnalyticsController(),
          account: Account('123', 1000, '123', 'Account', 1000, '3', 0, 0, 0),
        );
      }

      testWidgets(
          'PerformanceSectionPage conditionally renders Fidelity CSV import',
          (WidgetTester tester) async {
        // Disabled
        FeatureAccessService.instance.overrideRolloutForTesting(
          FeatureBundle.extendedBrokerages,
          FeatureRolloutMode.disabled,
        );

        final ctx = createTestContext();
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => DividendStore()),
              ChangeNotifierProvider(create: (_) => InterestStore()),
              ChangeNotifierProvider(create: (_) => InstrumentPositionStore()),
              ChangeNotifierProvider(create: (_) => InstrumentOrderStore()),
              ChangeNotifierProvider(create: (_) => ChartSelectionStore()),
            ],
            child: MaterialApp(
              home: PerformanceSectionPage(sectionContext: ctx),
            ),
          ),
        );
        await tester.pump();

        expect(find.byTooltip('Import from Fidelity CSV'), findsNothing);

        // Enabled
        FeatureAccessService.instance.overrideRolloutForTesting(
          FeatureBundle.extendedBrokerages,
          FeatureRolloutMode.public,
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => DividendStore()),
              ChangeNotifierProvider(create: (_) => InterestStore()),
              ChangeNotifierProvider(create: (_) => InstrumentPositionStore()),
              ChangeNotifierProvider(create: (_) => InstrumentOrderStore()),
              ChangeNotifierProvider(create: (_) => ChartSelectionStore()),
            ],
            child: MaterialApp(
              home: PerformanceSectionPage(sectionContext: ctx),
            ),
          ),
        );
        await tester.pump();

        expect(find.byTooltip('Import from Fidelity CSV'), findsOneWidget);
      });

      testWidgets(
          'PerformanceSectionPage suppresses IncomeTransactionsWidget for paper accounts',
          (WidgetTester tester) async {
        final paperContext = PortfolioSectionContext(
          brokerageUser:
              BrokerageUser(BrokerageSource.paper, 'paper_user', null, null),
          service: FakeBrokerageService(),
          analytics: FakeFirebaseAnalytics(),
          observer: FakeObserver(),
          generativeService: FakeGenerativeService(),
          appUser: null,
          userDocRef: null,
          analyticsController: PortfolioAnalyticsController(),
          account:
              Account('123', 1000, '123', 'Paper Account', 1000, '3', 0, 0, 0),
        );

        final realContext = createTestContext();

        Widget buildPage(PortfolioSectionContext ctx) => MultiProvider(
              providers: [
                ChangeNotifierProvider(create: (_) => DividendStore()),
                ChangeNotifierProvider(create: (_) => InterestStore()),
                ChangeNotifierProvider(
                    create: (_) => InstrumentPositionStore()),
                ChangeNotifierProvider(create: (_) => InstrumentOrderStore()),
                ChangeNotifierProvider(create: (_) => ChartSelectionStore()),
              ],
              child: MaterialApp(
                home: PerformanceSectionPage(sectionContext: ctx),
              ),
            );

        // Real account shows IncomeTransactionsWidget
        await tester.pumpWidget(buildPage(realContext));
        await tester.pump();
        expect(find.byType(IncomeTransactionsWidget), findsOneWidget);

        // Paper account suppresses IncomeTransactionsWidget
        await tester.pumpWidget(buildPage(paperContext));
        await tester.pump();
        expect(find.byType(IncomeTransactionsWidget), findsNothing);
      });

      testWidgets(
          'RiskSectionPage conditionally renders features based on flags and tiers',
          (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1200, 3600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final ctx = createTestContext();
        final portfolioStore = PortfolioStore();
        final instrumentStore = InstrumentStore();
        final instrumentPositionStore = InstrumentPositionStore();
        final optionPositionStore = OptionPositionStore();
        final futuresStore = FuturesPositionStore();
        final forexStore = ForexHoldingStore();

        Widget createRiskPage() {
          return MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: portfolioStore),
              ChangeNotifierProvider.value(value: instrumentStore),
              ChangeNotifierProvider.value(value: instrumentPositionStore),
              ChangeNotifierProvider.value(value: optionPositionStore),
              ChangeNotifierProvider.value(value: futuresStore),
              ChangeNotifierProvider.value(value: forexStore),
            ],
            child: MaterialApp(
              home: RiskSectionPage(sectionContext: ctx),
            ),
          );
        }

        // 1. All optional flags disabled
        FeatureAccessService.instance.overrideRolloutForTesting(
          FeatureBundle.riskGuardrails,
          FeatureRolloutMode.disabled,
        );
        FeatureAccessService.instance.overrideRolloutForTesting(
          FeatureBundle.aiResearch,
          FeatureRolloutMode.disabled,
        );
        FeatureAccessService.instance.overrideRolloutForTesting(
          FeatureBundle.advancedResearch,
          FeatureRolloutMode.disabled,
        );
        FeatureAccessService.instance.overrideRolloutForTesting(
          FeatureBundle.advancedTrading,
          FeatureRolloutMode.disabled,
        );

        await tester.pumpWidget(createRiskPage());
        await tester.pump();

        // Baseline cards are rendered (Tiers 1, 3, 4)
        expect(find.byType(RiskHeatmapWidget), findsOneWidget);
        expect(find.byType(PortfolioRiskSummaryWidget), findsOneWidget);
        expect(find.byType(RiskAnalyticsCard), findsOneWidget);
        expect(find.byType(RollingStatisticsDashboard), findsOneWidget);

        // Gated cards are NOT rendered (Tiers 2, 3 advanced, 5)
        expect(find.byType(AgenticRiskCopilotCard), findsNothing);
        expect(find.byType(CorrelationMatrixWidget), findsNothing);
        expect(find.byType(PortfolioGreeksCard), findsNothing);
        expect(find.byType(PortfolioStressTestCard), findsNothing);
        expect(find.byType(TailRiskCard), findsNothing);

        // 2. Enable riskGuardrails & aiResearch -> AgenticRiskCopilotCard is rendered
        FeatureAccessService.instance.overrideRolloutForTesting(
          FeatureBundle.riskGuardrails,
          FeatureRolloutMode.public,
        );
        FeatureAccessService.instance.overrideRolloutForTesting(
          FeatureBundle.aiResearch,
          FeatureRolloutMode.public,
        );

        await tester.pumpWidget(createRiskPage());
        await tester.pump();

        expect(find.byType(AgenticRiskCopilotCard), findsOneWidget);

        // 3. Enable advancedResearch -> Stress test and Tail risk cards rendered
        FeatureAccessService.instance.overrideRolloutForTesting(
          FeatureBundle.advancedResearch,
          FeatureRolloutMode.public,
        );

        await tester.pumpWidget(createRiskPage());
        await tester.pump();

        expect(find.byType(PortfolioStressTestCard), findsOneWidget);
        expect(find.byType(TailRiskCard), findsOneWidget);

        // If symbols are present, CorrelationMatrixWidget is also rendered
        instrumentPositionStore.add(
          buildPosition(symbol: 'AAPL', price: 150, quantity: 10),
        );
        await tester.pumpWidget(createRiskPage());
        await tester.pump();
        expect(find.byType(CorrelationMatrixWidget), findsOneWidget);

        // 4. Enable advancedTrading and add option positions -> PortfolioGreeksCard rendered
        FeatureAccessService.instance.overrideRolloutForTesting(
          FeatureBundle.advancedTrading,
          FeatureRolloutMode.public,
        );
        optionPositionStore.add(
          buildOptionPosition(
            symbol: 'AAPL',
            strikePrice: 150,
            optionType: 'call',
            expirationDate: DateTime.now().add(const Duration(days: 30)),
          ),
        );

        await tester.pumpWidget(createRiskPage());
        await tester.pump();
        expect(find.byType(PortfolioGreeksCard), findsOneWidget);
      });
    });

    group('PortfolioMoversWidget Inline Expansion Tests', () {
      testWidgets(
          'initially shows 3 items and expands to reveal more on toggle tap',
          (WidgetTester tester) async {
        final positions = [
          buildPosition(
              symbol: 'WIN1', price: 150, previousClose: 100, quantity: 1),
          buildPosition(
              symbol: 'WIN2', price: 140, previousClose: 100, quantity: 1),
          buildPosition(
              symbol: 'WIN3', price: 130, previousClose: 100, quantity: 1),
          buildPosition(
              symbol: 'WIN4', price: 120, previousClose: 100, quantity: 1),
          buildPosition(
              symbol: 'WIN5', price: 110, previousClose: 100, quantity: 1),
          buildPosition(
              symbol: 'LOS1', price: 50, previousClose: 100, quantity: 1),
          buildPosition(
              symbol: 'LOS2', price: 60, previousClose: 100, quantity: 1),
          buildPosition(
              symbol: 'LOS3', price: 70, previousClose: 100, quantity: 1),
          buildPosition(
              symbol: 'LOS4', price: 80, previousClose: 100, quantity: 1),
          buildPosition(
              symbol: 'LOS5', price: 90, previousClose: 100, quantity: 1),
        ];

        PortfolioMover? tappedMover;
        final accountStore = AccountStore();

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: accountStore,
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: PortfolioMoversWidget(
                    positions: positions,
                    rowCount: 3,
                    expandedRowCount: 10,
                    onMoverTap: (mover) {
                      tappedMover = mover;
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Top 3 winners & losers visible
        expect(find.text('WIN1'), findsOneWidget);
        expect(find.text('WIN2'), findsOneWidget);
        expect(find.text('WIN3'), findsOneWidget);
        expect(find.text('WIN4'), findsNothing);
        expect(find.text('WIN5'), findsNothing);

        expect(find.text('LOS1'), findsOneWidget);
        expect(find.text('LOS2'), findsOneWidget);
        expect(find.text('LOS3'), findsOneWidget);
        expect(find.text('LOS4'), findsNothing);
        expect(find.text('LOS5'), findsNothing);

        // Shows expansion button
        expect(find.text('Show more (10 total)'), findsOneWidget);

        // Tap to expand
        await tester.tap(find.text('Show more (10 total)'));
        await tester.pumpAndSettle();

        // Now WIN4, WIN5, LOS4, LOS5 are visible
        expect(find.text('WIN4'), findsOneWidget);
        expect(find.text('WIN5'), findsOneWidget);
        expect(find.text('LOS4'), findsOneWidget);
        expect(find.text('LOS5'), findsOneWidget);

        // Shows collapse button
        expect(find.text('Show fewer movers'), findsOneWidget);

        // Tap mover row calls onMoverTap
        await tester.tap(find.text('WIN1'));
        expect(tappedMover?.symbol, 'WIN1');

        // Tap to collapse
        await tester.tap(find.text('Show fewer movers'));
        await tester.pumpAndSettle();

        expect(find.text('WIN4'), findsNothing);
        expect(find.text('LOS4'), findsNothing);
        expect(find.text('Show more (10 total)'), findsOneWidget);
      });
    });

    group('Concentration Risk Alert and Navigation Tests', () {
      test(
          'concentration alert targets instrument with View symbol when accountTools is disabled',
          () {
        FeatureAccessService.instance.overrideRolloutForTesting(
          FeatureBundle.accountTools,
          FeatureRolloutMode.disabled,
        );

        final alerts = PortfolioAlertService.buildAlerts(
          instrumentPositions: [
            buildPosition(symbol: 'NVDA', price: 100, quantity: 40),
            buildPosition(symbol: 'AAPL', price: 100, quantity: 10),
          ],
          optionPositions: const [],
        );

        final concentration =
            alerts.firstWhere((a) => a.id == 'concentration-NVDA');
        expect(concentration.target, PortfolioAlertTarget.instrument);
        expect(concentration.actionLabel, 'View NVDA');
        expect(concentration.symbol, 'NVDA');

        // And filterAlertsByFeatureAccess preserves instrument target
        final filtered = PortfolioAlertService.filterAlertsByFeatureAccess(
          [concentration],
          userRole: UserRole.user,
        );
        expect(filtered.length, 1);
        expect(filtered.first.target, PortfolioAlertTarget.instrument);
        expect(filtered.first.actionLabel, 'View NVDA');
      });

      test('concentration alert targets rebalance when accountTools is enabled',
          () {
        FeatureAccessService.instance.overrideRolloutForTesting(
          FeatureBundle.accountTools,
          FeatureRolloutMode.public,
        );

        final alerts = PortfolioAlertService.buildAlerts(
          instrumentPositions: [
            buildPosition(symbol: 'NVDA', price: 100, quantity: 40),
            buildPosition(symbol: 'AAPL', price: 100, quantity: 10),
          ],
          optionPositions: const [],
        );

        final concentration =
            alerts.firstWhere((a) => a.id == 'concentration-NVDA');
        expect(concentration.target, PortfolioAlertTarget.rebalance);
        expect(concentration.actionLabel, 'Rebalance');
        expect(concentration.symbol, 'NVDA');
      });

      testWidgets(
          'ActionCenterWidget symbol badge tap fires onSymbolTap to link directly to instrument',
          (WidgetTester tester) async {
        String? tappedSymbol;
        final concentrationAlert = PortfolioAlert(
          id: 'concentration-NVDA',
          severity: PortfolioAlertSeverity.critical,
          icon: Icons.pie_chart_outline,
          title: 'Concentration risk in NVDA',
          detail: 'A single holding drives an outsized share of your returns.',
          metric: '80%',
          target: PortfolioAlertTarget.instrument,
          category: 'Allocation',
          actionLabel: 'View NVDA',
          symbol: 'NVDA',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ActionCenterWidget(
                alerts: [concentrationAlert],
                onAlertTap: (_) {},
                onSymbolTap: (symbol) {
                  tappedSymbol = symbol;
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('NVDA'), findsOneWidget);
        await tester.tap(find.text('NVDA'));
        expect(tappedSymbol, 'NVDA');
      });
    });
  });
}
