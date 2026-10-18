import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/forex_holding.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/widgets/forex_positions_widget.dart';

class FakeFirebaseAnalytics extends Fake implements FirebaseAnalytics {}

class FakeFirebaseAnalyticsObserver extends Fake
    implements FirebaseAnalyticsObserver {}

class FakeGenerativeService extends Fake implements GenerativeService {}

void main() {
  testWidgets('renders forex holdings with currency units', (tester) async {
    _setViewport(tester);
    final holdings = [
      _holding('EUR', 'Euro', 10000),
      _holding('GBP', 'British Pound', 5000),
    ];

    await tester.pumpWidget(_app(holdings));
    await tester.pumpAndSettle();

    expect(find.text('Forex'), findsOneWidget);
    expect(find.text('2 forex positions'), findsOneWidget);
    expect(find.text('Euro'), findsOneWidget);
    expect(find.text('10000.0 units'), findsOneWidget);
    expect(find.text('British Pound'), findsOneWidget);
    expect(find.text('5000.0 units'), findsOneWidget);
    expect(find.text('Crypto'), findsNothing);
  });

  testWidgets('labels crypto-only holdings as crypto', (tester) async {
    _setViewport(tester);

    await tester.pumpWidget(_app([_holding('BTC', 'Bitcoin', 0.5)]));
    await tester.pumpAndSettle();

    expect(find.text('Crypto'), findsOneWidget);
    expect(find.text('1 crypto position'), findsOneWidget);
    expect(find.text('0.5 units'), findsOneWidget);
  });

  testWidgets('uses a generic label for mixed currency holdings',
      (tester) async {
    _setViewport(tester);

    await tester.pumpWidget(
      _app([
        _holding('EUR', 'Euro', 10000),
        _holding('BTC', 'Bitcoin', 0.5),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Currencies'), findsOneWidget);
    expect(find.text('2 positions'), findsOneWidget);
    expect(find.text('Euro'), findsOneWidget);
    expect(find.text('Bitcoin'), findsOneWidget);
  });

  testWidgets('renders an empty holdings list', (tester) async {
    _setViewport(tester);

    await tester.pumpWidget(_app([]));
    await tester.pumpAndSettle();

    expect(find.text('Currencies'), findsOneWidget);
    expect(find.text('0 positions'), findsOneWidget);
  });
}

void _setViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Widget _app(List<ForexHolding> holdings) {
  final brokerageUser =
      BrokerageUser(BrokerageSource.demo, 'test-user', null, null)
        ..showPositionDetails = false;
  return MaterialApp(
    home: Scaffold(
      body: CustomScrollView(
        slivers: [
          ForexPositionsWidget(
            brokerageUser,
            DemoService(),
            holdings,
            analytics: FakeFirebaseAnalytics(),
            observer: FakeFirebaseAnalyticsObserver(),
            generativeService: FakeGenerativeService(),
          ),
        ],
      ),
    ),
  );
}

ForexHolding _holding(
    String currencyCode, String currencyName, double quantity) {
  return ForexHolding(
    currencyCode,
    'currency-$currencyCode',
    currencyCode,
    currencyName,
    quantity,
    0,
    DateTime(2026, 9, 1),
    DateTime(2026, 9, 1),
  );
}
