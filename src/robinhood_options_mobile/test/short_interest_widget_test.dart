import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';
import 'package:robinhood_options_mobile/widgets/short_interest_widget.dart';

void main() {
  testWidgets(
      'ShortInterestWidget renders default equity short metrics and expands details',
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

    final instrument = Instrument(
      id: 'inst_aapl',
      url: 'https://api.robinhood.com/instruments/inst_aapl/',
      quote: 'https://api.robinhood.com/quotes/AAPL/',
      fundamentals: 'https://api.robinhood.com/fundamentals/AAPL/',
      splits: 'https://api.robinhood.com/instruments/inst_aapl/splits/',
      state: 'active',
      market: 'https://api.robinhood.com/markets/XNAS/',
      name: 'Apple Inc.',
      simpleName: 'Apple',
      symbol: 'AAPL',
      bloombergUnique: 'EQ0001',
      country: 'US',
      type: 'stock',
      tradeable: true,
      tradability: 'tradable',
      rhsTradability: 'tradable',
      fractionalTradability: 'tradable',
      isSpac: false,
      isTest: false,
      ipoAccessSupportsDsp: false,
      dateCreated: DateTime(1980, 12, 12),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ShortInterestWidget(
              brokerageUser: brokerageUser,
              service: service,
              instrument: instrument,
            ),
          ),
        ),
      ),
    );

    // Initial loading state
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Wait for futures to resolve
    await tester.pumpAndSettle();

    // Verify Title and Icons
    expect(find.text('Short Float & Borrow Rates'), findsOneWidget);
    expect(find.byIcon(Icons.trending_down), findsOneWidget);

    // Verify Header Badges
    expect(find.text('Low Squeeze Risk'), findsOneWidget);
    expect(find.text('Easy to Borrow'), findsOneWidget);

    // Verify Primary Metric Cards
    expect(find.text('Short % of Float'), findsOneWidget);
    expect(find.text('2.85%'), findsOneWidget);

    expect(find.text('Days to Cover'), findsOneWidget);
    expect(find.text('1.9 d'), findsOneWidget);

    expect(find.text('Borrow Fee Rate'), findsOneWidget);
    expect(find.text('0.35%'), findsOneWidget);

    expect(find.text('Borrow Inventory'), findsOneWidget);
    expect(find.text('HIGH'), findsOneWidget);

    // Verify Squeeze Description Banner
    expect(
        find.text(
            'Minimal short exposure. Unlikely to trigger a forced short covering squeeze.'),
        findsOneWidget);

    // Verify Expand Button
    final expandButton = find.text('View Full Short & Borrow Breakdown');
    expect(expandButton, findsOneWidget);

    // Tap to expand details
    await tester.tap(expandButton);
    await tester.pumpAndSettle();

    // Verify Expanded Detailed Rows
    expect(find.text('Current Shares Short'), findsOneWidget);
    expect(find.textContaining('shares'), findsWidgets);
    expect(find.text('Total Free Float'), findsOneWidget);
    expect(find.text('Average Daily Volume'), findsOneWidget);
    expect(find.text('FINRA Settlement Date'), findsOneWidget);
    expect(find.text('Understanding Short Squeeze & Borrow Dynamics'),
        findsOneWidget);
  });

  testWidgets(
      'ShortInterestWidget renders elevated/hard-to-borrow stock metrics for GME',
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

    final instrument = Instrument(
      id: 'inst_gme',
      url: 'https://api.robinhood.com/instruments/inst_gme/',
      quote: 'https://api.robinhood.com/quotes/GME/',
      fundamentals: 'https://api.robinhood.com/fundamentals/GME/',
      splits: 'https://api.robinhood.com/instruments/inst_gme/splits/',
      state: 'active',
      market: 'https://api.robinhood.com/markets/XNYS/',
      name: 'GameStop Corp.',
      simpleName: 'GameStop',
      symbol: 'GME',
      bloombergUnique: 'EQ0002',
      country: 'US',
      type: 'stock',
      tradeable: true,
      tradability: 'tradable',
      rhsTradability: 'tradable',
      fractionalTradability: 'tradable',
      isSpac: false,
      isTest: false,
      ipoAccessSupportsDsp: false,
      dateCreated: DateTime(2002, 2, 13),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ShortInterestWidget(
              brokerageUser: brokerageUser,
              service: service,
              instrument: instrument,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify GME short metrics
    expect(find.text('24.50%'), findsOneWidget);
    expect(find.text('6.4 d'), findsOneWidget);
    expect(find.text('18.50%'), findsOneWidget);
    expect(find.text('LOW'), findsOneWidget);
    expect(find.text('Hard to Borrow'), findsOneWidget);

    // Expand
    await tester.tap(find.text('View Full Short & Borrow Breakdown'));
    await tester.pumpAndSettle();

    // Verify Borrow Warning and Locates
    expect(find.text('Locate Required'), findsOneWidget);
    expect(find.text('Yes (Strict Borrow)'), findsOneWidget);
    expect(
        find.textContaining('High borrow demand and tight loan availability'),
        findsOneWidget);
  });

  testWidgets(
      'ShortInterestWidget handles narrow viewport (320px) without overflow',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final brokerageUser =
        BrokerageUser(BrokerageSource.demo, 'demo_user', null, null);
    final service = DemoService();

    final instrument = Instrument(
      id: 'inst_gme',
      url: 'https://api.robinhood.com/instruments/inst_gme/',
      quote: 'https://api.robinhood.com/quotes/GME/',
      fundamentals: 'https://api.robinhood.com/fundamentals/GME/',
      splits: 'https://api.robinhood.com/instruments/inst_gme/splits/',
      state: 'active',
      market: 'https://api.robinhood.com/markets/XNYS/',
      name: 'GameStop Corp.',
      simpleName: 'GameStop',
      symbol: 'GME',
      bloombergUnique: 'EQ0002',
      country: 'US',
      type: 'stock',
      tradeable: true,
      tradability: 'tradable',
      rhsTradability: 'tradable',
      fractionalTradability: 'tradable',
      isSpac: false,
      isTest: false,
      ipoAccessSupportsDsp: false,
      dateCreated: DateTime(2002, 2, 13),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ShortInterestWidget(
              brokerageUser: brokerageUser,
              service: service,
              instrument: instrument,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title and elements rendered
    expect(find.text('Short Float & Borrow Rates'), findsOneWidget);

    final expandFinder = find.text('View Full Short & Borrow Breakdown');
    await tester.scrollUntilVisible(expandFinder, 100);
    await tester.pumpAndSettle();

    // Expand to check detailed content on narrow screen
    await tester.tap(expandFinder);
    await tester.pumpAndSettle();

    // Expect no layout errors
    expect(tester.takeException(), isNull);
  });
}
