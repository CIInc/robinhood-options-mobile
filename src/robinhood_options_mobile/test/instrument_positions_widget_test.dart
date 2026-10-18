import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/widgets/instrument_positions_widget.dart';

class FakeFirebaseAnalytics extends Fake implements FirebaseAnalytics {}

class FakeFirebaseAnalyticsObserver extends Fake
    implements FirebaseAnalyticsObserver {}

class FakeGenerativeService extends Fake implements GenerativeService {}

void main() {
  testWidgets('renders positions list, share counts, and total market value',
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
      _position('aapl-id', 'AAPL', 'Apple', 10.0, 150.0, 175.0),
      _position('msft-id', 'MSFT', 'Microsoft', 5.0, 300.0, 320.0),
    ];

    await tester.pumpWidget(_app(brokerageUser, positions));
    await tester.pumpAndSettle();

    // Summary headers
    expect(find.text('2 positions'), findsOneWidget);
    expect(find.text('\$3,350.00'), findsWidgets);

    // Individual position items
    expect(find.text('Apple'), findsOneWidget);
    expect(find.text('10.0 shares'), findsOneWidget);
    expect(find.text('AAPL'), findsWidgets);
    expect(find.text('\$1,750.00'), findsWidgets);

    expect(find.text('Microsoft'), findsOneWidget);
    expect(find.text('5.0 shares'), findsOneWidget);
    expect(find.text('MSFT'), findsWidgets);
    expect(find.text('\$1,600.00'), findsWidgets);
  });

  testWidgets('capped chartRowLimit displays top N count indicator',
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
      _position('aapl-id', 'AAPL', 'Apple', 10.0, 150.0, 175.0),
      _position('msft-id', 'MSFT', 'Microsoft', 5.0, 300.0, 320.0),
      _position('nvda-id', 'NVDA', 'Nvidia', 8.0, 100.0, 120.0),
    ];

    await tester.pumpWidget(_app(brokerageUser, positions, chartRowLimit: 1));
    await tester.pumpAndSettle();

    expect(find.text('3 positions, charting top 1'), findsOneWidget);
    expect(find.text('3 positions'), findsNothing);
  });

  testWidgets('handles empty positions cleanly', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final brokerageUser =
        BrokerageUser(BrokerageSource.demo, 'test-user', null, null)
          ..showPositionDetails = false;
    final positions = <InstrumentPosition>[];

    await tester.pumpWidget(_app(brokerageUser, positions));
    await tester.pumpAndSettle();

    expect(find.text('0 positions'), findsOneWidget);
    expect(find.text('\$0.00'), findsWidgets);
  });

  testWidgets('renders total return when displayValue is totalReturn',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final brokerageUser =
        BrokerageUser(BrokerageSource.demo, 'test-user', null, null)
          ..displayValue = DisplayValue.totalReturn
          ..showPositionDetails = false;
    final positions = [
      _position('aapl-id', 'AAPL', 'Apple', 10.0, 150.0, 175.0),
    ];

    await tester.pumpWidget(_app(brokerageUser, positions));
    await tester.pumpAndSettle();

    expect(find.text('Apple'), findsOneWidget);
    expect(find.text('10.0 shares'), findsOneWidget);
    // AAPL total return = 10 * (175 - 150) = $250.00
    expect(find.text('\$250.00'), findsWidgets);
  });

  testWidgets('tapping detail tile updates displayValue to total return',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final brokerageUser =
        BrokerageUser(BrokerageSource.demo, 'test-user', null, null)
          ..displayValue = DisplayValue.marketValue
          ..showPositionDetails = false;
    final positions = [
      _position('aapl-id', 'AAPL', 'Apple', 10.0, 150.0, 175.0),
    ];

    await tester.pumpWidget(_app(brokerageUser, positions));
    await tester.pumpAndSettle();

    // Initially market value is active
    expect(brokerageUser.displayValue, DisplayValue.marketValue);

    // Tap Total Return tile in detail scroll row
    final totalReturnTile = find.text('Total Return');
    expect(totalReturnTile, findsOneWidget);
    await tester.tap(totalReturnTile);
    await tester.pumpAndSettle();

    expect(brokerageUser.displayValue, DisplayValue.totalReturn);
  });

  testWidgets(
      'tapping position with disableNavigation shows aggregate snackbar',
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
      _position('aapl-id', 'AAPL', 'Apple', 10.0, 150.0, 175.0),
    ];

    await tester.pumpWidget(
      _app(brokerageUser, positions, disableNavigation: true),
    );
    await tester.pumpAndSettle();

    final positionRow = find.text('Apple');
    expect(positionRow, findsOneWidget);
    await tester.tap(positionRow);
    await tester.pump();

    expect(
      find.text(
          'Trading actions are disabled in Aggregate View. Switch to a single account to trade.'),
      findsOneWidget,
    );
  });
}

Widget _app(
  BrokerageUser brokerageUser,
  List<InstrumentPosition> positions, {
  int? chartRowLimit,
  bool disableNavigation = false,
}) {
  return MaterialApp(
    home: Scaffold(
      body: CustomScrollView(
        slivers: [
          InstrumentPositionsWidget(
            brokerageUser,
            DemoService(),
            positions,
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

InstrumentPosition _position(
  String id,
  String symbol,
  String name,
  double quantity,
  double averageBuyPrice,
  double lastTradePrice, {
  double? previousClose,
}) {
  final quote = Quote(
    symbol: symbol,
    lastTradePrice: lastTradePrice,
    previousClose: previousClose ?? averageBuyPrice,
    adjustedPreviousClose: previousClose ?? averageBuyPrice,
    tradingHalted: false,
    hasTraded: true,
    lastTradePriceSource: 'consolidated',
    instrument: 'https://api.robinhood.com/instruments/$id/',
    instrumentId: id,
    askSize: 100,
    bidSize: 100,
  );

  final instrument = Instrument(
    id: id,
    url: 'https://api.robinhood.com/instruments/$id/',
    quote: 'https://api.robinhood.com/quotes/$symbol/',
    fundamentals: '',
    splits: '',
    state: 'active',
    market: 'https://api.robinhood.com/markets/XNAS/',
    simpleName: name,
    name: '$name Inc.',
    tradeable: true,
    tradability: 'tradable',
    symbol: symbol,
    bloombergUnique: '',
    country: 'US',
    type: 'stock',
    rhsTradability: 'tradable',
    fractionalTradability: 'tradable',
    isSpac: false,
    isTest: false,
    ipoAccessSupportsDsp: false,
    dateCreated: DateTime(2020, 1, 1),
  )..quoteObj = quote;

  return InstrumentPosition(
    'https://api.robinhood.com/positions/account/$id/',
    'https://api.robinhood.com/instruments/$id/',
    'https://api.robinhood.com/accounts/account/',
    'account',
    averageBuyPrice,
    averageBuyPrice,
    quantity,
    averageBuyPrice,
    quantity,
    quantity,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    false,
    DateTime(2026, 9, 1),
    DateTime(2026, 9, 1),
  )..instrumentObj = instrument;
}
