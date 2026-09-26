import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/widgets/futures_positions_widget.dart';

class FakeFirebaseAnalytics extends Fake implements FirebaseAnalytics {}

class FakeFirebaseAnalyticsObserver extends Fake
    implements FirebaseAnalyticsObserver {}

class FakeGenerativeService extends Fake implements GenerativeService {}

void main() {
  testWidgets('renders futures contracts, P&L summaries, and capped chart rows',
      (tester) async {
    _setViewport(tester);
    final positions = [
      _position('ESZ26', 'ES', 'E-mini S&P 500', 2, 5100, 20, 5, 10),
      _position('NQZ26', 'NQ', 'E-mini Nasdaq 100', -3, 18000, 25, 5, 15),
    ];

    await tester.pumpWidget(_app(positions, chartRowLimit: 1));
    await tester.pumpAndSettle();

    expect(find.text('Futures'), findsOneWidget);
    expect(
        find.text('2 positions, 5 contracts, charting top 1'), findsOneWidget);
    expect(find.text('E-mini S&P 500'), findsOneWidget);
    expect(find.text('ESZ26 +2'), findsOneWidget);
    expect(find.text('E-mini Nasdaq 100'), findsOneWidget);
    expect(find.text('NQZ26 -3'), findsOneWidget);
    expect(find.text('Open P&L'), findsWidgets);
    expect(find.text('Day P&L'), findsWidgets);
    expect(find.text('Realized'), findsWidgets);
    expect(find.text('\$45.00'), findsWidgets);
    expect(find.text('\$10.00'), findsWidgets);
    expect(find.text('\$25.00'), findsWidgets);
  });

  testWidgets('disables position navigation in aggregate view', (tester) async {
    _setViewport(tester);

    await tester.pumpWidget(
      _app([_position('ESZ26', 'ES', 'E-mini S&P 500', 2, 5100, 20, 5, 10)],
          disableNavigation: true),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('E-mini S&P 500'));
    await tester.pump();

    expect(
      find.text(
        'Trading actions are disabled in Aggregate View. Switch to a single account to trade.',
      ),
      findsOneWidget,
    );
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

Widget _app(
  List<dynamic> positions, {
  int? chartRowLimit,
  bool disableNavigation = false,
}) {
  final brokerageUser =
      BrokerageUser(BrokerageSource.demo, 'test-user', null, null)
        ..showPositionDetails = false;
  return MaterialApp(
    home: Scaffold(
      body: CustomScrollView(
        slivers: [
          FuturesPositionsWidget(
            brokerageUser,
            DemoService(),
            positions,
            showList: true,
            chartRowLimit: chartRowLimit,
            disableNavigation: disableNavigation,
            analytics: FakeFirebaseAnalytics(),
            observer: FakeFirebaseAnalyticsObserver(),
            generativeService: FakeGenerativeService(),
            user: null,
            userDocRef: null,
          ),
        ],
      ),
    ),
  );
}

Map<String, dynamic> _position(
  String contractSymbol,
  String rootSymbol,
  String description,
  int quantity,
  double averagePrice,
  double openPnl,
  double dayPnl,
  double realizedPnl,
) {
  return {
    'contractId': contractSymbol,
    'quantity': quantity,
    'avgTradePrice': averagePrice,
    'lastTradePrice': averagePrice + 10,
    'notionalValue': averagePrice * quantity.abs() * 50,
    'openPnlCalc': openPnl,
    'dayPnlCalc': dayPnl,
    'realizedPnl': realizedPnl,
    'marginRequirement': 500,
    'product': {
      'symbol': rootSymbol,
      'displaySymbol': rootSymbol,
      'description': description,
    },
    'contract': {
      'rootSymbol': rootSymbol,
      'displaySymbol': contractSymbol,
      'multiplier': 50,
    },
  };
}
