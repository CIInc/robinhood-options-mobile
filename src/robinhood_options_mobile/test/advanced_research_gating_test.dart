import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/main.dart' as app_main;
import 'package:robinhood_options_mobile/services/feature_access_service.dart';
import 'package:robinhood_options_mobile/services/remote_config_service.dart';
import 'package:robinhood_options_mobile/widgets/home/options_flow_card_widget.dart';
import 'package:robinhood_options_mobile/widgets/portfolio_gex_dashboard_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_mocks.dart';

void main() {
  setupFirebaseMocks();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    FeatureAccessService.mockInstance = FeatureAccessService(
      prefs: prefs,
      remoteConfig: RemoteConfigService.instance,
    );
    app_main.userRole = UserRole.user;
  });

  tearDown(() {
    app_main.userRole = UserRole.user;
  });

  group('Advanced Research & Flow Gating Tests', () {
    testWidgets(
        'OptionsFlowCardWidget is hidden when user has not opted into beta',
        (WidgetTester tester) async {
      await FeatureAccessService.instance.setUserOptIn(
        FeatureBundle.advancedResearch,
        false,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OptionsFlowCardWidget(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Options Flow Analysis'), findsNothing);
      expect(find.byType(Card), findsNothing);
    });

    testWidgets('OptionsFlowCardWidget renders when user opts into beta',
        (WidgetTester tester) async {
      await FeatureAccessService.instance.setUserOptIn(
        FeatureBundle.advancedResearch,
        true,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OptionsFlowCardWidget(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Options Flow Analysis'), findsOneWidget);
      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets(
        'Admin user sees OptionsFlowCardWidget when opted in, hidden when not opted in',
        (WidgetTester tester) async {
      app_main.userRole = UserRole.admin;
      await FeatureAccessService.instance.setUserOptIn(
        FeatureBundle.advancedResearch,
        false,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OptionsFlowCardWidget(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Options Flow Analysis'), findsNothing);

      // When admin opts in, it appears
      await FeatureAccessService.instance.setUserOptIn(
        FeatureBundle.advancedResearch,
        true,
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OptionsFlowCardWidget(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Options Flow Analysis'), findsOneWidget);
      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets(
        'Remote kill switch (disabled) hides OptionsFlowCardWidget even if opted in',
        (WidgetTester tester) async {
      await FeatureAccessService.instance.setUserOptIn(
        FeatureBundle.advancedResearch,
        true,
      );

      // Simulate remote kill switch
      FeatureAccessService.instance.overrideRolloutForTesting(
        FeatureBundle.advancedResearch,
        FeatureRolloutMode.disabled,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OptionsFlowCardWidget(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Options Flow Analysis'), findsNothing);
      expect(find.byType(Card), findsNothing);
    });

    testWidgets(
        'PortfolioGexDashboardWidget displays lock screen when user has not opted into beta',
        (WidgetTester tester) async {
      await FeatureAccessService.instance.setUserOptIn(
        FeatureBundle.advancedResearch,
        false,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: PortfolioGexDashboardWidget(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Advanced Research Feature'), findsOneWidget);
      expect(
        find.textContaining(
            'requires the Advanced Research & Flow beta feature'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.refresh), findsNothing);
    });

    testWidgets(
        'PortfolioGexDashboardWidget unlocks when user has opted into beta',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await FeatureAccessService.instance.setUserOptIn(
        FeatureBundle.advancedResearch,
        true,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: PortfolioGexDashboardWidget(),
        ),
      );
      await tester.pump();

      expect(find.text('Advanced Research Feature'), findsNothing);
      expect(find.byTooltip('Refresh portfolio GEX'), findsOneWidget);
    });
  });
}
