import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/option_leg.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/widgets/option_positions_widget.dart';

class FakeFirebaseAnalytics extends Fake implements FirebaseAnalytics {}

class FakeFirebaseAnalyticsObserver extends Fake
    implements FirebaseAnalyticsObserver {}

class FakeGenerativeService extends Fake implements GenerativeService {}

void main() {
  testWidgets('grouped view shows underlying position and contract counts',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final brokerageUser =
        BrokerageUser(BrokerageSource.demo, 'test-user', null, null)
          ..showPositionDetails = false;
    final positions = [
      _position('aapl-call-150', 'AAPL', 150, 1),
      _position('aapl-call-155', 'AAPL', 155, 2),
      _position('msft-call-400', 'MSFT', 400, 1),
    ];

    await tester.pumpWidget(_app(brokerageUser, positions));
    await tester.pumpAndSettle();

    expect(find.textContaining('3 positions, 4 contracts, 2 underlying'),
        findsOneWidget);
    expect(find.text('2 positions, 3 contracts'), findsOneWidget);
    expect(find.text('1 positions, 1 contracts'), findsOneWidget);
    expect(find.textContaining('150 Call +1'), findsOneWidget);
    expect(find.textContaining('155 Call +2'), findsOneWidget);
    expect(find.textContaining('400 Call +1'), findsOneWidget);
  });

  testWidgets('list view shows individual contracts without group headers',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final brokerageUser =
        BrokerageUser(BrokerageSource.demo, 'test-user', null, null)
          ..optionsView = OptionsView.list
          ..showPositionDetails = false;
    final positions = [
      _position('aapl-call-150', 'AAPL', 150, 1),
      _position('aapl-call-155', 'AAPL', 155, 2),
    ];

    await tester.pumpWidget(_app(brokerageUser, positions));
    await tester.pumpAndSettle();

    expect(find.textContaining('2 positions, 3 contracts, charting top 0'),
        findsOneWidget);
    expect(find.text('2 positions, 3 contracts'), findsNothing);
    expect(_richTextContaining('AAPL \$150 call x 1'), findsOneWidget);
    expect(_richTextContaining('AAPL \$155 call x 2'), findsOneWidget);
  });
}

Widget _app(
  BrokerageUser brokerageUser,
  List<OptionAggregatePosition> positions,
) {
  return MaterialApp(
    home: Scaffold(
      body: CustomScrollView(
        slivers: [
          OptionPositionsWidget(
            brokerageUser,
            DemoService(),
            positions,
            chartRowLimit: 0,
            showFooter: false,
            analytics: FakeFirebaseAnalytics(),
            observer: FakeFirebaseAnalyticsObserver(),
            generativeService: FakeGenerativeService(),
            user: null,
          ),
        ],
      ),
    ),
  );
}

OptionAggregatePosition _position(
  String id,
  String symbol,
  double strike,
  double quantity,
) {
  return OptionAggregatePosition(
    id,
    '',
    '',
    symbol,
    'call',
    1,
    [
      OptionLeg(
        '$id-leg',
        null,
        'long',
        '',
        null,
        1,
        'buy',
        DateTime(2027, 1, 15),
        strike,
        'call',
        [],
      ),
    ],
    quantity,
    null,
    null,
    'debit',
    'debit',
    100,
    DateTime(2026, 9, 1),
    DateTime(2026, 9, 1),
    'long_call',
  );
}

Finder _richTextContaining(String text) => find.byWidgetPredicate(
      (widget) =>
          widget is RichText && widget.text.toPlainText().contains(text),
    );
