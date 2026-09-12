import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/widgets/presets_widget.dart';

class FakeFirebaseAnalytics extends Fake implements FirebaseAnalytics {
  @override
  Future<void> logScreenView({
    String? screenClass,
    String? screenName,
    Map<String, Object>? parameters,
    AnalyticsCallOptions? callOptions,
  }) async {}
}

class FakeFirebaseAnalyticsObserver extends Fake
    implements FirebaseAnalyticsObserver {}

class FakeGenerativeService extends Fake implements GenerativeService {}

void main() {
  testWidgets('PresetsWidget renders curated presets tab and displays presets',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final brokerageUser =
        BrokerageUser(BrokerageSource.demo, 'demo_user', null, null);
    final service = DemoService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<InstrumentStore>(
            create: (_) => InstrumentStore(),
          ),
        ],
        child: MaterialApp(
          home: PresetsWidget(
            brokerageUser,
            service,
            analytics: FakeFirebaseAnalytics(),
            observer: FakeFirebaseAnalyticsObserver(),
            generativeService: FakeGenerativeService(),
            user: null,
            userDocRef: null,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Tab headers
    expect(find.text('Screener Presets'), findsOneWidget);
    expect(find.text('Curated Presets'), findsOneWidget);
    expect(find.text('Yahoo Presets'), findsOneWidget);

    // Verify Curated Presets content
    expect(find.text('Robinhood Curated Presets'), findsOneWidget);
    expect(find.text('Daily price jumps'), findsOneWidget);
    expect(find.text('Highest dividend yield'), findsOneWidget);
    expect(find.text('Highest implied volatility'), findsOneWidget);
    expect(find.text('Highest options volume'), findsOneWidget);

    // Verify category chips
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Dividends'), findsWidgets);
    expect(find.text('Movers'), findsWidgets);

    // Verify sample symbol chip
    expect(find.text('NVDA'), findsWidgets);
    expect(find.text('JNJ'), findsWidgets);
  });

  testWidgets('PresetsWidget filters presets by search query',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final brokerageUser =
        BrokerageUser(BrokerageSource.demo, 'demo_user', null, null);
    final service = DemoService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<InstrumentStore>(
            create: (_) => InstrumentStore(),
          ),
        ],
        child: MaterialApp(
          home: PresetsWidget(
            brokerageUser,
            service,
            analytics: FakeFirebaseAnalytics(),
            observer: FakeFirebaseAnalyticsObserver(),
            generativeService: FakeGenerativeService(),
            user: null,
            userDocRef: null,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Daily price jumps'), findsOneWidget);
    expect(find.text('Highest dividend yield'), findsOneWidget);

    // Search for "dividend"
    await tester.enterText(find.byType(TextField).first, 'dividend');
    await tester.pumpAndSettle();

    expect(find.text('Highest dividend yield'), findsOneWidget);
    expect(find.text('Daily price jumps'), findsNothing);
  });

  testWidgets('PresetsWidget renders cleanly on compact 320px viewport',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final brokerageUser =
        BrokerageUser(BrokerageSource.demo, 'demo_user', null, null);
    final service = DemoService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<InstrumentStore>(
            create: (_) => InstrumentStore(),
          ),
        ],
        child: MaterialApp(
          home: PresetsWidget(
            brokerageUser,
            service,
            analytics: FakeFirebaseAnalytics(),
            observer: FakeFirebaseAnalyticsObserver(),
            generativeService: FakeGenerativeService(),
            user: null,
            userDocRef: null,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Screener Presets'), findsOneWidget);
    expect(find.text('Robinhood Curated Presets'), findsOneWidget);
  });
}
