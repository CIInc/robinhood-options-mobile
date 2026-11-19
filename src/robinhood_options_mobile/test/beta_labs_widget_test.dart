import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_provider.dart';
import 'package:robinhood_options_mobile/model/backtesting_provider.dart';
import 'package:robinhood_options_mobile/model/brokerage_user_store.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/quote_store.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/feature_access_service.dart';
import 'package:robinhood_options_mobile/services/offline_sync_service.dart';
import 'package:robinhood_options_mobile/services/remote_config_service.dart';
import 'package:robinhood_options_mobile/widgets/backtesting_widget.dart';
import 'package:robinhood_options_mobile/widgets/beta_labs_widget.dart';
import 'package:robinhood_options_mobile/widgets/search_widget.dart';

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

    Widget createTestApp({
      UserRole? role,
      User? user,
      dynamic userDocRef,
    }) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => BacktestingProvider()),
          ChangeNotifierProvider(create: (_) => AgenticTradingProvider()),
          ChangeNotifierProvider(create: (_) => InstrumentStore()),
          ChangeNotifierProvider(create: (_) => QuoteStore()),
          ChangeNotifierProvider(create: (_) => AccountStore()),
          ChangeNotifierProvider(create: (_) => OfflineSyncService()),
          ChangeNotifierProvider(create: (_) => BrokerageUserStore([], 0)),
        ],
        child: MaterialApp(
          home: BetaLabsWidget(
            userRole: role,
            user: user,
            userDocRef: userDocRef,
            featureAccessService: service,
          ),
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
      expect(find.text('Advanced Trading'), findsOneWidget);
      expect(find.text('Strategy Backtesting'), findsOneWidget);
      expect(
          find.text('Risk Circuit Breakers & Tilt Guardrails'), findsOneWidget);
      expect(find.text('Investor Groups & Channels'), findsOneWidget);
      expect(find.text('Automated Trading'), findsOneWidget);
    });

    testWidgets(
        'Defaults to Public for Investor Groups & Channels and allows user opt-out',
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

      final investorTileFinder =
          find.widgetWithText(SwitchListTile, 'Investor Groups & Channels');
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

      expect(
          defaultService.isUserOptedOut(FeatureBundle.investorGroups), isTrue);
      expect(
          defaultService.isFeatureEnabled(FeatureBundle.investorGroups,
              userRole: UserRole.user),
          isFalse);
    });

    testWidgets(
        'Toggling Advanced Trading prompts disclaimer dialog with cancel and enable options',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(role: UserRole.user));
      await tester.pumpAndSettle();

      // Find switch for Advanced Trading
      final switchFinder =
          find.widgetWithText(SwitchListTile, 'Advanced Trading');
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

    testWidgets(
        'Phone user displays phone number in synced badge and toggle works without reverting',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final firestore = FakeFirebaseFirestore();
      final usersCollection = firestore.collection('users').withConverter<User>(
            fromFirestore: (snapshot, _) => User.fromJson(snapshot.data()!),
            toFirestore: (user, _) => user.toJson(),
          );
      final docRef = usersCollection.doc('phone_user_123');

      final user = User(
        name: 'Phone User',
        phoneNumber: '+15551234567',
        providerId: 'phone',
        role: UserRole.user,
        devices: const [],
        brokerageUsers: const [],
        dateCreated: DateTime(2026, 1, 1),
        featureFlags: {
          // Explicit initial false override in user doc
          'extendedBrokerages': false,
        },
      );
      await docRef.set(user);

      await tester.pumpWidget(createTestApp(
        role: UserRole.user,
        user: user,
        userDocRef: docRef,
      ));
      await tester.pumpAndSettle();

      // Verify the badge displays the phone number
      expect(find.text('Synced with account (+15551234567)'), findsOneWidget);

      final switchFinder =
          find.widgetWithText(SwitchListTile, 'Extended Brokerages');
      expect(switchFinder, findsOneWidget);

      // Verify switch is currently false due to user.featureFlags
      SwitchListTile switchTile = tester.widget<SwitchListTile>(switchFinder);
      expect(switchTile.value, isFalse);

      // Tap switch to enable
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // Switch must NOT revert back to false!
      switchTile = tester.widget<SwitchListTile>(switchFinder);
      expect(switchTile.value, isTrue);

      // In-memory user.featureFlags must be updated
      expect(user.featureFlags!['extendedBrokerages'], isTrue);

      // Firestore document must be updated
      final updatedSnapshot = await docRef.get();
      expect(
          updatedSnapshot.data()?.featureFlags?['extendedBrokerages'], isTrue);
    });

    testWidgets(
        'Feature flag toggling works across all auth providers (Google, Apple, Email, Anonymous)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final firestore = FakeFirebaseFirestore();
      final usersCollection = firestore.collection('users').withConverter<User>(
            fromFirestore: (snapshot, _) => User.fromJson(snapshot.data()!),
            toFirestore: (user, _) => user.toJson(),
          );

      final providers = [
        {'id': 'google_1', 'provider': 'google.com', 'email': 'g@domain.com'},
        {'id': 'apple_1', 'provider': 'apple.com', 'email': 'a@domain.com'},
        {'id': 'email_1', 'provider': 'password', 'email': 'email@domain.com'},
        {'id': 'anon_1', 'provider': 'anonymous', 'name': 'Guest Trader'},
      ];

      for (final p in providers) {
        final docRef = usersCollection.doc(p['id']);
        final testUser = User(
          name: p['name'] ?? 'User ${p['provider']}',
          email: p['email'],
          providerId: p['provider'],
          role: UserRole.user,
          devices: const [],
          brokerageUsers: const [],
          dateCreated: DateTime(2026, 1, 1),
          featureFlags: {'extendedBrokerages': false},
        );
        await docRef.set(testUser);

        await tester.pumpWidget(createTestApp(
          role: UserRole.user,
          user: testUser,
          userDocRef: docRef,
        ));
        await tester.pumpAndSettle();

        final switchFinder =
            find.widgetWithText(SwitchListTile, 'Extended Brokerages');
        expect(switchFinder, findsOneWidget);

        SwitchListTile tile = tester.widget<SwitchListTile>(switchFinder);
        expect(tile.value, isFalse);

        await tester.tap(switchFinder);
        await tester.pumpAndSettle();

        tile = tester.widget<SwitchListTile>(switchFinder);
        expect(tile.value, isTrue,
            reason: 'Toggle should remain true for provider ${p['provider']}');
        expect(testUser.featureFlags!['extendedBrokerages'], isTrue);

        final doc = await docRef.get();
        expect(doc.data()?.featureFlags?['extendedBrokerages'], isTrue);
      }
    });

    testWidgets(
        'Renders location badge and demo button for all feature bundles',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Location badges
      expect(find.text('Account > Automated Trading'), findsOneWidget);
      expect(find.text('Account > Automated Trading > Strategy Style'),
          findsOneWidget);
      expect(find.text('Account > Automated Trading > Risk Management'),
          findsOneWidget);
      expect(find.text('Account > Strategy Backtesting'), findsOneWidget);
      expect(find.text('Research > Options Flow & GEX'), findsOneWidget);
      expect(find.text('Community > Investor Groups'), findsOneWidget);
      expect(find.text('Search > Macro Market State'), findsOneWidget);

      // Demo buttons
      for (final bundle in FeatureBundle.values) {
        expect(find.byKey(ValueKey('demo_${bundle.name}')), findsOneWidget);
      }
    });

    testWidgets(
        'Tapping Demo opens interactive demo sheet with preview and capabilities',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Tap demo button for automated trading
      final demoBtn = find.byKey(const ValueKey('demo_automatedTrading'));
      expect(demoBtn, findsOneWidget);
      await tester.tap(demoBtn);
      await tester.pumpAndSettle();

      // Verify bottom sheet contents
      expect(find.text('INTERACTIVE PREVIEW'), findsOneWidget);
      expect(find.text('KEY CAPABILITIES'), findsOneWidget);
      expect(find.text('RSI < 30 (Oversold)'), findsOneWidget);
      expect(find.text('MACD Bullish Cross'), findsOneWidget);
      expect(
          find.text('Located in: Account > Automated Trading'), findsOneWidget);

      // Toggle an indicator in the interactive preview
      await tester.tap(find.text('EMA 20/50 Golden Cross'));
      await tester.pumpAndSettle();

      // Close bottom sheet
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      expect(find.text('INTERACTIVE PREVIEW'), findsNothing);
    });

    testWidgets(
        'Tapping Demo for Macro Intelligence displays economic cycle phases, inflation YoY, and yield curve',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final demoBtn = find.byKey(const ValueKey('demo_macroIntelligence'));
      expect(demoBtn, findsOneWidget);
      await tester.tap(demoBtn);
      await tester.pumpAndSettle();

      expect(find.text('INTERACTIVE PREVIEW'), findsOneWidget);
      expect(find.text('Economic Cycle Phase:'), findsOneWidget);
      expect(find.text('Expansion'), findsWidgets);
      expect(find.text('Late-Cycle'), findsOneWidget);
      expect(find.text('Recession Watch'), findsOneWidget);
      expect(find.text('Inflation YoY'), findsOneWidget);
      expect(find.text('2.4%'), findsOneWidget);
      expect(find.text('Yield Curve'), findsOneWidget);
      expect(find.text('+18 bps'), findsOneWidget);
      expect(find.textContaining('Suggested Allocation:'), findsOneWidget);

      // Switch to Late-Cycle
      await tester.tap(find.text('Late-Cycle'));
      await tester.pumpAndSettle();

      expect(find.text('3.1%'), findsOneWidget);
      expect(find.text('+2 bps'), findsOneWidget);

      // Switch to Recession Watch
      await tester.tap(find.text('Recession Watch'));
      await tester.pumpAndSettle();

      expect(find.text('1.8%'), findsOneWidget);
      expect(find.text('-24 bps'), findsOneWidget);

      // Close bottom sheet
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      expect(find.text('INTERACTIVE PREVIEW'), findsNothing);
    });

    testWidgets(
        'Enabled feature displays Open Feature button and triggers navigation',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final testUser = User(
        name: 'Trader Alex',
        role: UserRole.user,
        devices: const [],
        brokerageUsers: const [],
        dateCreated: DateTime(2026, 1, 1),
        featureFlags: {
          'backtesting': true,
          'investorGroups': true,
          'macroIntelligence': true,
        },
      );

      await tester.pumpWidget(createTestApp(
        role: UserRole.user,
        user: testUser,
      ));
      await tester.pumpAndSettle();

      // Open Feature button should be visible for enabled features
      final openBacktestingBtn = find.byKey(const ValueKey('open_backtesting'));
      expect(openBacktestingBtn, findsOneWidget);

      // Tap Open Feature to navigate to BacktestingWidget
      await tester.tap(openBacktestingBtn);
      await tester.pumpAndSettle();

      // BacktestingWidget is pushed on navigation stack
      expect(find.byType(BacktestingWidget), findsOneWidget);

      // Pop BacktestingWidget
      Navigator.of(tester.element(find.byType(BacktestingWidget))).pop();
      await tester.pumpAndSettle();

      // Tap Open Feature for macroIntelligence to navigate to SearchWidget
      final openMacroBtn = find.byKey(const ValueKey('open_macroIntelligence'));
      expect(openMacroBtn, findsOneWidget);
      await tester.tap(openMacroBtn);
      await tester.pumpAndSettle();

      expect(find.byType(SearchWidget), findsOneWidget);
    });

    testWidgets(
        'Renders and opens demo sheets on narrow 320px viewport without RenderFlex overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 8000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Ensure no overflow on the main list
      expect(tester.takeException(), isNull);

      // Test opening demo sheets on narrow screens
      final demoBundles = [
        FeatureBundle.automatedTrading,
        FeatureBundle.agenticTrading,
        FeatureBundle.riskGuardrails,
        FeatureBundle.backtesting,
        FeatureBundle.advancedTrading,
      ];

      for (final bundle in demoBundles) {
        final demoBtn = find.byKey(ValueKey('demo_${bundle.name}'));
        expect(demoBtn, findsOneWidget);

        await tester.tap(demoBtn);
        await tester.pumpAndSettle();

        expect(find.text('INTERACTIVE PREVIEW'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Close sheet
        final closeBtn = find.byTooltip('Close');
        expect(closeBtn, findsOneWidget);
        await tester.tap(closeBtn);
        await tester.pumpAndSettle();
      }
    });
  });
}
