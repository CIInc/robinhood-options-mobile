import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/services/feature_access_service.dart';
import 'package:robinhood_options_mobile/services/remote_config_service.dart';
import 'package:robinhood_options_mobile/widgets/beta_labs_widget.dart';

import 'firebase_mocks.dart';

void main() {
  setUpAll(() async {
    await setupFirebaseMocks();
  });

  group('BetaLabsWidget Tests', () {
    late SharedPreferences prefs;
    late FeatureAccessService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      service = FeatureAccessService(
        prefs: prefs,
        remoteConfig: RemoteConfigService.instance,
        overrideModes: {
          FeatureBundle.advancedTrading: FeatureRolloutMode.betaOptIn,
          FeatureBundle.extendedBrokerages: FeatureRolloutMode.public,
          FeatureBundle.automatedTrading: FeatureRolloutMode.disabled,
          FeatureBundle.accountTools: FeatureRolloutMode.adminOnly,
        },
        overrideSelfOptIn: true,
      );
    });

    Widget createTestApp({UserRole? role}) {
      return MaterialApp(
        home: BetaLabsWidget(
          userRole: role,
          featureAccessService: service,
        ),
      );
    }

    testWidgets('Renders all feature bundles with their status badges',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Beta Labs'), findsOneWidget);
      expect(find.text('Experimental Features'), findsOneWidget);

      // Verify status labels
      expect(find.text('Beta'), findsWidgets);
      expect(find.text('Public'), findsWidgets);
      expect(find.text('Disabled'), findsWidgets);
      expect(find.text('Admin Only'), findsWidgets);

      // Verify titles
      expect(find.text('Advanced Trading (Multi-Leg Spreads)'), findsOneWidget);
      expect(find.text('Strategy Backtesting'), findsOneWidget);
      expect(find.text('Risk Circuit Breakers & Tilt Guardrails'), findsOneWidget);
      expect(find.text('Investor Groups & Channels'), findsOneWidget);
      expect(find.text('Automated & Algorithmic Orders'), findsOneWidget);
    });

    testWidgets('Defaults to Public for Investor Groups & Channels and allows user opt-out',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final defaultService = FeatureAccessService(
        prefs: prefs,
        remoteConfig: RemoteConfigService.instance,
        overrideSelfOptIn: true,
      );

      expect(defaultService.getRolloutMode(FeatureBundle.investorGroups),
          equals(FeatureRolloutMode.public));

      await tester.pumpWidget(MaterialApp(
        home: BetaLabsWidget(
          userRole: UserRole.user,
          featureAccessService: defaultService,
        ),
      ));
      await tester.pumpAndSettle();

      final investorTileFinder = find.widgetWithText(
          SwitchListTile, 'Investor Groups & Channels');
      expect(investorTileFinder, findsOneWidget);
      // Under this tile, status chip should say "Public"
      expect(
        find.descendant(
          of: investorTileFinder,
          matching: find.text('Public'),
        ),
        findsOneWidget,
      );

      // Verify that public switch is enabled and can be toggled to opt out
      final switchTile = tester.widget<SwitchListTile>(investorTileFinder);
      expect(switchTile.onChanged, isNotNull);
      expect(switchTile.value, isTrue);

      // Tap to opt out
      await tester.tap(investorTileFinder);
      await tester.pumpAndSettle();

      expect(defaultService.isUserOptedOut(FeatureBundle.investorGroups), isTrue);
      expect(defaultService.isFeatureEnabled(FeatureBundle.investorGroups, userRole: UserRole.user), isFalse);
    });

    testWidgets(
        'Toggling Advanced Trading prompts disclaimer dialog with cancel and enable options',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(role: UserRole.user));
      await tester.pumpAndSettle();

      // Find switch for Advanced Trading
      final switchFinder = find.widgetWithText(
          SwitchListTile, 'Advanced Trading (Multi-Leg Spreads)');
      expect(switchFinder, findsOneWidget);

      // Tap to enable
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // Expect disclaimer dialog
      expect(find.text('Beta Feature Disclaimer'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Enable Feature'), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Dialog dismissed, feature still not opted in
      expect(find.text('Beta Feature Disclaimer'), findsNothing);
      expect(service.isUserOptedIn(FeatureBundle.advancedTrading), isFalse);

      // Tap switch again and confirm Enable Feature
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enable Feature'));
      await tester.pumpAndSettle();

      // State is now persisted and enabled
      expect(service.isUserOptedIn(FeatureBundle.advancedTrading), isTrue);
    });

    testWidgets('Reset opt-ins button resets choices',
        (WidgetTester tester) async {
      await service.setUserOptIn(FeatureBundle.advancedTrading, true);
      expect(service.isUserOptedIn(FeatureBundle.advancedTrading), isTrue);

      await tester.pumpWidget(createTestApp(role: UserRole.user));
      await tester.pumpAndSettle();

      // Tap reset action button in AppBar
      final resetBtn = find.byTooltip('Reset Opt-Ins');
      expect(resetBtn, findsOneWidget);
      await tester.tap(resetBtn);
      await tester.pumpAndSettle();

      expect(service.isUserOptedIn(FeatureBundle.advancedTrading), isFalse);
      expect(find.text('All beta opt-ins reset to default'), findsOneWidget);
    });
  });
}
